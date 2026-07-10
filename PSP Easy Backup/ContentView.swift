//
//  ContentView.swift
//  PSP Easy Backup
//
import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var model = BackupViewModel()
    private let relativeTimeTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            appHeader

            HStack(spacing: 0) {
                sidebar

                Divider()

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            backupFooter
        }
        .frame(minWidth: 1040, idealWidth: 1180, minHeight: 720, idealHeight: 780)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .alert(item: $model.destinationMovePrompt) { prompt in
            Alert(
                title: Text("Move Existing Backups?"),
                message: Text("Move backup folders from \(prompt.oldURL.path) to \(prompt.newURL.path)?"),
                primaryButton: .default(Text("Move Backups")) {
                    model.confirmDestinationChange(prompt, moveBackups: true)
                },
                secondaryButton: .cancel(Text("Keep In Place")) {
                    model.confirmDestinationChange(prompt, moveBackups: false)
                }
            )
        }
        .sheet(item: $model.setupContext) { context in
            DeviceSetupSheet(context: context) { name, color, note in
                model.completeSetup(context: context, name: name, color: color, note: note)
            }
        }
        .sheet(item: $model.destinationSetupContext) { context in
            BackupDestinationSetupSheet(context: context) { destination in
                model.saveBackupDestination(destination)
            }
            .interactiveDismissDisabled(context.isRequired)
        }
        .sheet(item: $model.backupCompletion) { summary in
            BackupSuccessSheet(summary: summary)
        }
        .sheet(item: $model.settingsContext) { _ in
            SettingsSheet(model: model)
        }
        .onAppear {
            model.start()
        }
        .onReceive(relativeTimeTimer) { date in
            model.updateRelativeTime(date)
        }
    }

    private var appHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("PSP Easy Backup")
                    .font(.system(size: 26, weight: .bold))
                Text(model.statusLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                model.showSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .disabled(model.isRunning)

            Button {
                model.refreshVolumes()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRunning)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Button {
                            model.choosePSPFolder()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(model.isRunning)

                        SidebarSectionHeader(title: "Connected", count: model.volumes.count)
                    }

                    if model.volumes.isEmpty {
                        EmptySidebarCard(
                            symbol: "cable.connector",
                            title: "Connect a PSP or Memory Stick",
                            subtitle: "Use Add for a mounted external Memory Stick."
                        )
                    } else {
                        VStack(spacing: 8) {
                            ForEach(model.volumes) { volume in
                                ConnectedVolumeRow(
                                    volume: volume,
                                    profile: model.profile(for: volume),
                                    isSelected: model.isSelected(volume),
                                    isRunning: model.isRunning,
                                    onSelect: { model.select(volume) }
                                )
                            }
                        }
                    }

                    SidebarSectionHeader(title: "Linked PSPs", count: model.profiles.count)

                    if model.profiles.isEmpty {
                        EmptySidebarCard(
                            symbol: "square.grid.2x2",
                            title: "No linked PSPs",
                            subtitle: "Set up a connected device to add it here."
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(model.profiles) { profile in
                                LinkedDeviceCard(
                                    profile: profile,
                                    timeReference: model.relativeTimeNow,
                                    isOnline: model.isOnline(profile),
                                    isSelected: model.isSelected(profile),
                                    onSelect: { model.select(profile) }
                                )
                                .disabled(model.isRunning)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 330)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        if let volume = model.selectedVolume {
            DeviceDetailView(model: model, volume: volume, profile: model.profile(for: volume))
        } else if let profile = model.selectedProfile {
            OfflineProfileView(model: model, profile: profile)
        } else {
            WelcomeView(onRescan: model.refreshVolumes)
        }
    }

    private var backupFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(model.progressTitle)
                        .font(.headline)
                    Text(model.progressSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(model.progressMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            ProgressView(value: model.progressFraction)
                .frame(width: 230)

            StorageFooterMeter(usage: model.displayedStorageUsage, isLastKnown: model.isShowingLastKnownStorage)
                .frame(width: 300)

            Spacer()

            if model.isRunning {
                Button(role: .cancel) {
                    model.cancelBackup()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
            }

            Button {
                model.startBackup()
            } label: {
                Label(model.backupButtonTitle, systemImage: "play.fill")
                    .frame(minWidth: 124)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canStartBackup)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }
}

private struct DeviceDetailView: View {
    @ObservedObject var model: BackupViewModel
    let volume: PSPVolume
    let profile: PSPDeviceProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                deviceHeader

                if profile == nil {
                    UnconfiguredDevicePanel(volume: volume, onSetup: { model.showSetup(for: volume) })
                } else {
                    backupControls
                    contentBrowser
                }
            }
            .padding(22)
        }
    }

    private var deviceHeader: some View {
        HStack(spacing: 16) {
            DeviceAvatar(color: profile?.color ?? volume.marker?.color ?? .indigo, symbol: "gamecontroller")
                .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(profile?.name ?? volume.displayName)
                        .font(.system(size: 28, weight: .bold))
                        .lineLimit(1)

                    OnlineBadge(title: profile == nil ? "New" : "Mounted")
                }

                Text(volume.rootURL.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if let profile {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(profile.shortID)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button {
                            model.openDestination(for: profile)
                        } label: {
                            Label("Open", systemImage: "folder")
                        }

                        Button {
                            model.showSetup(for: volume)
                        } label: {
                            Label("Edit", systemImage: "slider.horizontal.3")
                        }

                        Button {
                            model.eject(volume)
                        } label: {
                            Label("Eject", systemImage: "eject")
                        }
                    }
                    .disabled(model.isRunning)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6))
        )
    }

    private var backupControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                StatTile(title: "Items", value: "\(model.contentItems.count)", symbol: "list.bullet.rectangle")
                StatTile(title: "Saves", value: "\(model.contentItems.filter { $0.kind == .save }.count)", symbol: "memorychip")
                StatTile(title: "Backup", value: model.backupPercentText, symbol: "checkmark.seal")
                StatTile(title: "Needed", value: model.backupNeedsText, symbol: "arrow.triangle.2.circlepath")
                StatTile(title: "Last Backup", value: model.lastBackupText(for: profile), symbol: "externaldrive.badge.checkmark")
            }

            HStack(spacing: 12) {
                Picker("Mode", selection: $model.backupMode) {
                    ForEach(BackupMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Picker("Filter", selection: $model.contentFilter) {
                    ForEach(ContentFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 400)

                Spacer()
            }

            HStack(spacing: 12) {
                Picker("Sort", selection: $model.contentSort) {
                    ForEach(ContentSortMode.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                TextField("Search saves, games, themes, plugins", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    model.selectAllVisibleItems()
                } label: {
                    Label("All", systemImage: "checklist.checked")
                }
                .disabled(model.backupMode == .fullDisk || model.visibleContentItems.isEmpty)

                Button {
                    model.clearVisibleItems()
                } label: {
                    Label("None", systemImage: "checklist.unchecked")
                }
                .disabled(model.backupMode == .fullDisk || model.visibleContentItems.isEmpty)
            }
        }
        .disabled(model.isRunning)
    }

    private var contentBrowser: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Backup Contents", systemImage: "tray.full")
                    .font(.headline)
            }

            if model.isScanningContent || model.isAnalyzingBackup {
                LoadingPanel(title: "Scanning memory stick", symbol: "magnifyingglass")
            } else if model.visibleContentItems.isEmpty {
                LoadingPanel(title: "No matching items", symbol: "tray")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(model.visibleContentRows) { row in
                        switch row {
                        case .item(let item):
                            ContentItemRow(
                                item: item,
                                isSelected: model.selectedItemIDs.contains(item.id),
                                isForcedOn: model.backupMode == .fullDisk,
                                isDisabled: model.isRunning || model.backupMode == .fullDisk,
                                accentColor: profile?.color.color ?? Color.accentColor,
                                onToggle: { selected in
                                    model.setItem(item, selected: selected)
                                }
                            )
                        case .gameGroup(let game, let saves):
                            VStack(alignment: .leading, spacing: 6) {
                                ContentItemRow(
                                    item: game,
                                    isSelected: model.selectedItemIDs.contains(game.id),
                                    isForcedOn: model.backupMode == .fullDisk,
                                    isDisabled: model.isRunning || model.backupMode == .fullDisk,
                                    accentColor: profile?.color.color ?? Color.accentColor,
                                    onToggle: { selected in
                                        model.setItem(game, selected: selected)
                                    }
                                )

                                VStack(spacing: 6) {
                                    ForEach(saves) { save in
                                        NestedContentItemRow(
                                            item: save,
                                            isSelected: model.selectedItemIDs.contains(save.id),
                                            isForcedOn: model.backupMode == .fullDisk,
                                            isDisabled: model.isRunning || model.backupMode == .fullDisk,
                                            accentColor: profile?.color.color ?? Color.accentColor,
                                            onToggle: { selected in
                                                model.setItem(save, selected: selected)
                                            }
                                        )
                                    }
                                }
                            }
                        case .expandableGroup(let parent, let children):
                            VStack(alignment: .leading, spacing: 6) {
                                ContentItemRow(
                                    item: parent,
                                    isSelected: model.selectedItemIDs.contains(parent.id),
                                    isForcedOn: model.backupMode == .fullDisk,
                                    isDisabled: model.isRunning || model.backupMode == .fullDisk,
                                    accentColor: profile?.color.color ?? Color.accentColor,
                                    isExpandable: true,
                                    isExpanded: model.isExpanded(parent),
                                    onToggle: { selected in
                                        model.setItem(parent, selected: selected)
                                    },
                                    onDisclosureToggle: {
                                        model.toggleExpanded(parent)
                                    }
                                )

                                if model.isExpanded(parent) {
                                    NestedContentTreeRows(
                                        model: model,
                                        items: children,
                                        parentSelected: model.selectedItemIDs.contains(parent.id),
                                        accentColor: profile?.color.color ?? Color.accentColor
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct OfflineProfileView: View {
    @ObservedObject var model: BackupViewModel
    let profile: PSPDeviceProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                offlineHeader

                HStack(alignment: .top, spacing: 14) {
                    StatTile(title: "Items", value: "\(model.contentItems.count)", symbol: "list.bullet.rectangle")
                    StatTile(title: "Saves", value: "\(model.contentItems.filter { $0.kind == .save }.count)", symbol: "memorychip")
                    StatTile(title: "Last Seen", value: model.lastSeenText(for: profile), symbol: "eye")
                    StatTile(title: "Last Backup", value: model.lastBackupText(for: profile), symbol: "externaldrive.badge.checkmark")
                    StatTile(title: "Storage", value: model.storageText(for: profile), symbol: "externaldrive")
                }

                InfoPanel(
                    symbol: "cable.connector",
                    title: "Waiting for this PSP",
                    subtitle: "Connect \(profile.name) with USB Connection enabled or insert its Memory Stick."
                )

                OfflineBackupContentsView(model: model, profile: profile)
            }
            .padding(22)
        }
    }

    private var offlineHeader: some View {
        HStack(spacing: 16) {
            DeviceAvatar(color: profile.color, symbol: "gamecontroller")
                .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(profile.name)
                        .font(.system(size: 28, weight: .bold))
                        .lineLimit(1)

                    OnlineBadge(title: "Offline", isOnline: false)
                }

                Text(profile.lastVolumePath ?? profile.shortID)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(profile.shortID)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    model.openDestination(for: profile)
                } label: {
                    Label("Open Backups", systemImage: "folder")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6))
        )
    }
}

private struct OfflineBackupContentsView: View {
    @ObservedObject var model: BackupViewModel
    let profile: PSPDeviceProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Picker("Filter", selection: $model.contentFilter) {
                    ForEach(ContentFilter.offlineCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 400)

                Spacer()
            }

            HStack(spacing: 12) {
                Picker("Sort", selection: $model.contentSort) {
                    ForEach(ContentSortMode.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                TextField("Search backup contents", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
            }

            backupContentList
        }
    }

    private var backupContentList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Backup Contents", systemImage: "tray.full")
                    .font(.headline)
            }

            if model.isScanningContent {
                LoadingPanel(title: "Loading backup contents", symbol: "externaldrive.badge.timemachine")
            } else if model.visibleContentItems.isEmpty {
                InfoPanel(
                    symbol: "tray",
                    title: "No backup contents found",
                    subtitle: "\(profile.name) has no readable backup content in the current destination."
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(model.visibleContentRows) { row in
                        switch row {
                        case .item(let item):
                            BackupSummaryItemRow(item: item)
                        case .gameGroup(let parent, let saves):
                            VStack(alignment: .leading, spacing: 6) {
                                BackupSummaryItemRow(item: parent)

                                VStack(spacing: 6) {
                                    ForEach(saves) { save in
                                        HStack(spacing: 9) {
                                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                                .fill(Color.accentColor.opacity(0.32))
                                                .frame(width: 2)
                                            BackupSummaryItemRow(item: save)
                                        }
                                        .padding(.leading, 44)
                                    }
                                }
                            }
                        case .expandableGroup(let parent, let children):
                            VStack(alignment: .leading, spacing: 6) {
                                BackupSummaryItemRow(
                                    item: parent,
                                    isExpandable: true,
                                    isExpanded: model.isExpanded(parent),
                                    onDisclosureToggle: {
                                        model.toggleExpanded(parent)
                                    }
                                )

                                if model.isExpanded(parent) {
                                    BackupSummaryTreeRows(model: model, items: children)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct WelcomeView: View {
    let onRescan: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 92, height: 92)

            VStack(spacing: 6) {
                Text("Connect a PSP or Memory Stick")
                    .font(.system(size: 30, weight: .bold))
                Text("A device is detected when it contains PSP files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(action: onRescan) {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct SettingsSheet: View {
    @ObservedObject var model: BackupViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                    Image(systemName: "gearshape")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.title2.bold())
                    Text("PSP Easy Backup")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Backup Destination")
                    .font(.headline)

                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(Color.accentColor)
                    Text(model.backupDestinationURL?.path ?? "No destination selected")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        chooseDestination()
                    } label: {
                        Label("Change Destination", systemImage: "folder")
                    }
                    .disabled(model.isRunning)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("App Data")
                    .font(.headline)

                InfoPanel(
                    symbol: "exclamationmark.arrow.triangle.2.circlepath",
                    title: "Reset local app data",
                    subtitle: "Clears linked PSPs, settings, and cached artwork on this Mac. Backups are left alone."
                )

                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Reset App Data", systemImage: "trash")
                }
                .disabled(model.isRunning)
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 580)
        .alert("Reset App Data?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                model.resetAppData()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes PSP Easy Backup settings, linked PSP records, and cached artwork from this Mac. Your backup folders will not be deleted.")
        }
    }

    private func chooseDestination() {
        FolderPanel.chooseFolder(
            title: "Backup Destination",
            message: "Choose where PSP backups should be stored.",
            canCreateDirectories: true,
            directoryURL: model.backupDestinationURL,
            prompt: "Change"
        ) { url in
            model.saveBackupDestination(url)
        }
    }
}

private struct DeviceSetupSheet: View {
    let context: DeviceSetupContext
    let onSave: (String, DeviceColor, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: DeviceColor
    @State private var customColor: Color
    @State private var note: String

    init(context: DeviceSetupContext, onSave: @escaping (String, DeviceColor, String) -> Void) {
        self.context = context
        self.onSave = onSave
        _name = State(initialValue: context.name)
        _selectedColor = State(initialValue: context.color)
        _customColor = State(initialValue: context.color.color)
        _note = State(initialValue: context.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                DeviceAvatar(color: selectedColor, symbol: "gamecontroller")
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.isEditing ? "Edit PSP" : "Setup PSP")
                        .font(.title2.bold())
                    Text(context.volume.rootURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.headline)
                TextField("PSP name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 12), spacing: 8) {
                    ForEach(DeviceColor.palette, id: \.self) { color in
                        Button {
                            selectedColor = color
                            customColor = color.color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.color)
                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ColorPicker("Custom color", selection: $customColor)
                    .onChange(of: customColor) { _, newValue in
                        selectedColor = DeviceColor(color: newValue)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Note")
                    .font(.headline)
                TextField("Main PSP, travel stick, modded setup", text: $note)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button {
                    onSave(cleanName, selectedColor, note.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                } label: {
                    Label(context.isEditing ? "Save" : "Link PSP", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(cleanName.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 500)
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct BackupDestinationSetupSheet: View {
    let context: BackupDestinationSetupContext
    let onSave: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var destinationURL: URL

    init(context: BackupDestinationSetupContext, onSave: @escaping (URL) -> Void) {
        self.context = context
        self.onSave = onSave
        _destinationURL = State(initialValue: context.currentURL ?? context.defaultURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            destinationCard

            VStack(alignment: .leading, spacing: 10) {
                DestinationSetupPoint(
                    symbol: "square.grid.2x2",
                    title: "One library, separate PSP folders",
                    subtitle: "Each linked PSP gets its own folder inside the selected location."
                )
                DestinationSetupPoint(
                    symbol: "externaldrive.badge.checkmark",
                    title: "Source and backup stay apart",
                    subtitle: "Keep this folder on your Mac or an external drive, not on the Memory Stick you back up."
                )
                DestinationSetupPoint(
                    symbol: "lock.open",
                    title: "Folder permission is remembered",
                    subtitle: "macOS will let PSP Easy Backup reuse this folder for future backups."
                )
            }

            footer
        }
        .padding(24)
        .frame(width: 660)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                Image(systemName: "externaldrive")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 5) {
                Text(context.isRequired ? "Set Up Backup Library" : "Change Backup Library")
                    .font(.title2.bold())
                Text(context.isRequired ? "Choose the folder that will hold PSP backups." : "Pick the folder linked PSP should use from now on.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(context.isRequired ? "Welcome" : "Storage")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
        }
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(destinationName)
                            .font(.headline)
                            .lineLimit(1)
                        DestinationStatusBadge(title: isRecommendedDestination ? "Recommended" : "Custom")
                    }

                    Text(destinationURL.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    chooseDestination()
                } label: {
                    Label("Choose", systemImage: "folder")
                }
            }

            HStack(spacing: 10) {
                Label(destinationHint, systemImage: isRecommendedDestination ? "checkmark.seal" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if !isRecommendedDestination {
                    Button {
                        destinationURL = context.defaultURL
                    } label: {
                        Label("Use Recommended", systemImage: "arrow.uturn.backward.circle")
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("You can change this later in Settings. If old backups exist, PSP Easy Backup will ask before moving them.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if !context.isRequired {
                Button("Cancel") {
                    dismiss()
                }
            }

            Button {
                onSave(destinationURL)
                dismiss()
            } label: {
                Label(context.isRequired ? "Save Destination" : "Change Destination", systemImage: "checkmark.circle")
                    .frame(minWidth: 144)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var destinationName: String {
        let name = destinationURL.lastPathComponent
        return name.isEmpty ? destinationURL.path : name
    }

    private var destinationHint: String {
        if isRecommendedDestination {
            return "This keeps PSP backups in your Documents folder."
        }

        return "Custom destinations work well on a reliable local or external drive."
    }

    private var isRecommendedDestination: Bool {
        destinationURL.standardizedFileURL.path == context.defaultURL.standardizedFileURL.path
    }

    private func chooseDestination() {
        FolderPanel.chooseFolder(
            title: "Backup Destination",
            message: "Choose where PSP backup folder should be stored.",
            canCreateDirectories: true,
            directoryURL: destinationURL
        ) { url in
            destinationURL = url
        }
    }
}

private struct DestinationSetupPoint: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct DestinationStatusBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.accentColor.opacity(0.14)))
    }
}

private struct ConnectedVolumeRow: View {
    let volume: PSPVolume
    let profile: PSPDeviceProfile?
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                DeviceAvatar(color: profile?.color ?? volume.marker?.color ?? .teal, symbol: profile == nil ? "plus" : "gamecontroller")
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile?.name ?? volume.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if profile == nil {
                            Text("New")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.16)))
                        }
                    }

                    Text(volume.rootURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if profile != nil, isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : Color(nsColor: .separatorColor).opacity(0.55))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LinkedDeviceCard: View {
    let profile: PSPDeviceProfile
    let timeReference: Date
    let isOnline: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DeviceAvatar(color: profile.color, symbol: "gamecontroller")
                        .frame(width: 38, height: 38)
                    Spacer()
                    Circle()
                        .fill(isOnline ? Color.green : Color.secondary.opacity(0.45))
                        .frame(width: 9, height: 9)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(profile.shortID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(profile.lastBackupText(relativeTo: timeReference))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? profile.color.color.opacity(0.14) : Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? profile.color.color.opacity(0.55) : Color(nsColor: .separatorColor).opacity(0.55))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ContentItemRow: View {
    let item: PSPContentItem
    let isSelected: Bool
    let isForcedOn: Bool
    let isDisabled: Bool
    let accentColor: Color
    var isNested = false
    var isExpandable = false
    var isExpanded = false
    let onToggle: (Bool) -> Void
    var onDisclosureToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if isExpandable {
                Button {
                    onDisclosureToggle?()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
            }

            Toggle("", isOn: Binding(get: { isForcedOn || isSelected }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(isDisabled)

            ItemArtwork(item: item, accentColor: accentColor)
                .frame(width: isNested ? 62 : 88, height: isNested ? 40 : 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(isNested ? .callout.weight(.semibold) : .headline)
                    .lineLimit(1)
                Text(item.subtitle.isEmpty ? item.relativePath : item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.relativePath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let backupTimelineText = item.backupTimelineText {
                    Text(backupTimelineText)
                        .font(.caption2)
                        .foregroundStyle(item.backupNeedsFileCount > 0 ? Color.orange : Color.secondary.opacity(0.72))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label(item.kind.title, systemImage: item.kind.symbolName)
                    .font(.caption)
                    .foregroundStyle(accentColor)
                    .labelStyle(.titleAndIcon)

                Text("\(item.fileCount) files - \(item.byteCountText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(item.backupStatusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(item.backupNeedsFileCount > 0 ? Color.orange : Color.secondary)

                if let total = item.backupTotalFileCount, total > 1 {
                    Text("\(item.backupNeedsFileCount) / \(total) need backup")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(isNested ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isNested ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5))
        )
    }
}

private struct NestedContentItemRow: View {
    let item: PSPContentItem
    let isSelected: Bool
    let isForcedOn: Bool
    let isDisabled: Bool
    let accentColor: Color
    var isExpandable = false
    var isExpanded = false
    var indentLevel = 1
    let onToggle: (Bool) -> Void
    var onDisclosureToggle: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(accentColor.opacity(0.32))
                .frame(width: 2)

            ContentItemRow(
                item: item,
                isSelected: isSelected,
                isForcedOn: isForcedOn,
                isDisabled: isDisabled,
                accentColor: accentColor,
                isNested: true,
                isExpandable: isExpandable,
                isExpanded: isExpanded,
                onToggle: onToggle,
                onDisclosureToggle: onDisclosureToggle
            )
        }
        .padding(.leading, CGFloat(44 + max(indentLevel - 1, 0) * 24))
    }
}

private struct NestedContentTreeRows: View {
    @ObservedObject var model: BackupViewModel
    let items: [PSPContentItem]
    let parentSelected: Bool
    let accentColor: Color
    var indentLevel = 1

    var body: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                let itemSelected = model.selectedItemIDs.contains(item.id)
                let forcedOn = model.backupMode == .fullDisk || parentSelected
                let disabled = model.isRunning || model.backupMode == .fullDisk || parentSelected

                NestedContentItemRow(
                    item: item,
                    isSelected: itemSelected,
                    isForcedOn: forcedOn,
                    isDisabled: disabled,
                    accentColor: accentColor,
                    isExpandable: item.hasExpandableChildren,
                    isExpanded: model.isExpanded(item),
                    indentLevel: indentLevel,
                    onToggle: { selected in
                        model.setItem(item, selected: selected)
                    },
                    onDisclosureToggle: item.hasExpandableChildren ? {
                        model.toggleExpanded(item)
                    } : nil
                )

                if item.hasExpandableChildren, model.isExpanded(item) {
                    NestedContentTreeRows(
                        model: model,
                        items: model.visibleChildren(for: item),
                        parentSelected: parentSelected || itemSelected,
                        accentColor: accentColor,
                        indentLevel: indentLevel + 1
                    )
                }
            }
        }
    }
}

private struct ItemArtwork: View {
    let item: PSPContentItem
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(0.12))

                if let image = iconImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: proxy.size.width - 6, maxHeight: proxy.size.height - 6)
                } else {
                    Image(systemName: item.kind.symbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var iconImage: NSImage? {
        guard let iconURL = item.iconURL else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }
}

private struct StorageFooterMeter: View {
    let usage: StorageUsage?
    var isLastKnown = false

    var body: some View {
        HStack(spacing: 8) {
            Label(isLastKnown ? "Last known" : "Storage", systemImage: "externaldrive")
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .fixedSize()

            ProgressView(value: usage?.percentUsed ?? 0)
                .tint(storageTint)
                .frame(width: 110)

            Text(usage?.counterText ?? "Unknown")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
        }
        .frame(height: 24, alignment: .center)
    }

    private var storageTint: Color {
        guard let usage else {
            return .secondary
        }

        if usage.percentUsed >= 0.92 {
            return .red
        }

        if usage.percentUsed >= 0.78 {
            return .orange
        }

        return .accentColor
    }
}

private struct BackupSuccessSheet: View {
    let summary: BackupCompletionSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.green.opacity(0.16))
                    Image(systemName: summary.isAlreadyCurrent ? "checkmark.seal" : "externaldrive.badge.checkmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.title)
                        .font(.title2.bold())
                    Text(summary.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                BackupSuccessStat(title: "Updated", value: "\(summary.changedFileCount)")
                BackupSuccessStat(title: "Changed Size", value: summary.changedByteText)
                BackupSuccessStat(title: "Deleted", value: "\(summary.deletedFileCount)")
                BackupSuccessStat(title: "Unchanged", value: "\(summary.unchangedFileCount)")
            }

            Divider()

            if summary.changedItems.isEmpty {
                InfoPanel(
                    symbol: summary.emptyChangeSymbolName,
                    title: summary.emptyChangeTitle,
                    subtitle: summary.emptyChangeSubtitle
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backed Up")
                        .font(.headline)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(summary.changedItems) { item in
                                BackupSummaryItemRow(item: item)
                            }
                        }
                    }
                    .frame(maxHeight: 310)
                }
            }

            if summary.deletedFileCount > 0 {
                Text("\(summary.deletedFileCount) stale backup files were removed from the mirror.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([summary.backupURL])
                } label: {
                    Label("Reveal Backup", systemImage: "arrow.up.forward.app")
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 660)
    }
}

private struct BackupSuccessStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct BackupSummaryItemRow: View {
    let item: PSPContentItem
    var isExpandable = false
    var isExpanded = false
    var onDisclosureToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if isExpandable {
                Button {
                    onDisclosureToggle?()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
            }

            ItemArtwork(item: item, accentColor: Color.accentColor)
                .frame(width: 68, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.subtitle.isEmpty ? item.relativePath : item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Label(item.kind.title, systemImage: item.kind.symbolName)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text("\(item.fileCount) files - \(item.byteCountText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45))
        )
    }
}

private struct BackupSummaryTreeRows: View {
    @ObservedObject var model: BackupViewModel
    let items: [PSPContentItem]
    var indentLevel = 1

    var body: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color.accentColor.opacity(0.32))
                        .frame(width: 2)
                    BackupSummaryItemRow(
                        item: item,
                        isExpandable: item.hasExpandableChildren,
                        isExpanded: model.isExpanded(item),
                        onDisclosureToggle: item.hasExpandableChildren ? {
                            model.toggleExpanded(item)
                        } : nil
                    )
                }
                .padding(.leading, CGFloat(44 + max(indentLevel - 1, 0) * 24))

                if item.hasExpandableChildren, model.isExpanded(item) {
                    BackupSummaryTreeRows(
                        model: model,
                        items: model.visibleChildren(for: item),
                        indentLevel: indentLevel + 1
                    )
                }
            }
        }
    }
}

private struct DeviceAvatar: View {
    let color: DeviceColor
    let symbol: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.color.opacity(0.95), color.color.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55))
        )
    }
}

private struct InfoPanel: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55))
        )
    }
}

private struct UnconfiguredDevicePanel: View {
    let volume: PSPVolume
    let onSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoPanel(
                symbol: "sparkles",
                title: "Setup available",
                subtitle: "\(volume.fallbackName) can be linked."
            )

            Button(action: onSetup) {
                Label("Setup This Device", systemImage: "gamecontroller")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct LoadingPanel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
        )
    }
}

private struct EmptySidebarCard: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
        )
    }
}

private struct SidebarSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(nsColor: .textBackgroundColor)))
        }
    }
}

private struct OnlineBadge: View {
    let title: String
    var isOnline = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isOnline ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isOnline ? Color.green : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill((isOnline ? Color.green : Color.secondary).opacity(0.12)))
    }
}

final class BackupViewModel: ObservableObject {
    @Published var profiles: [PSPDeviceProfile]
    @Published var volumes: [PSPVolume] = []
    @Published var selectedVolumeID: String?
    @Published var selectedProfileID: String?
    @Published var contentItems: [PSPContentItem] = []
    @Published var selectedItemIDs: Set<String> = []
    @Published var isScanningContent = false
    @Published var isAnalyzingBackup = false
    @Published var backupAnalysis: BackupAnalysis?
    @Published var storageUsage: StorageUsage?
    @Published var backupMode: BackupMode = .fullDisk
    @Published var contentFilter: ContentFilter = .all
    @Published var contentSort: ContentSortMode = .defaultOrder
    @Published var searchText = ""
    @Published var expandedItemIDs: Set<String> = []
    @Published var isRunning = false
    @Published var progressFraction = 0.0
    @Published var progressTitle = "Ready"
    @Published var progressSummary = "0%"
    @Published var progressMessage = "Connect a PSP or choose a linked device."
    @Published var setupContext: DeviceSetupContext?
    @Published var destinationSetupContext: BackupDestinationSetupContext?
    @Published var destinationMovePrompt: DestinationMovePrompt?
    @Published var alert: AlertInfo?
    @Published var backupCompletion: BackupCompletionSummary?
    @Published var settingsContext: SettingsContext?
    @Published var relativeTimeNow = Date()
    @Published var appSettings: AppBackupSettings?

    private var cancellation: BackupCancellation?
    private var scanToken = UUID()
    private var volumeObservers: [NSObjectProtocol] = []

    init() {
        profiles = DeviceStore.load()
        appSettings = AppSettingsStore.load()
        if appSettings == nil, let migratedSettings = migratedBackupSettings(from: profiles) {
            appSettings = migratedSettings
            AppSettingsStore.save(migratedSettings)
        }
        startWatchingVolumes()
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in volumeObservers {
            center.removeObserver(observer)
        }
    }

    var statusLine: String {
        if isRunning {
            return progressMessage
        }

        if appSettings == nil {
            return "Choose a backup destination."
        }

        if let selectedVolume {
            if let profile = profile(for: selectedVolume) {
                if let backupAnalysis {
                    return "\(profile.name) - \(backupAnalysis.summaryText)"
                }

                return "Ready for \(profile.name)"
            }

            return "Setup available for \(selectedVolume.fallbackName)"
        }

        if volumes.isEmpty {
            return "Connect a PSP or Memory Stick."
        }

        return "Choose a connected PSP."
    }

    var selectedVolume: PSPVolume? {
        guard let selectedVolumeID else {
            return nil
        }

        return volumes.first { $0.id == selectedVolumeID }
    }

    var selectedProfile: PSPDeviceProfile? {
        guard let selectedProfileID else {
            return nil
        }

        return profiles.first { $0.id == selectedProfileID }
    }

    var visibleContentItems: [PSPContentItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredItems = contentItems.filter { item in
            contentFilter.includes(item)
                && (query.isEmpty
                    || item.deepMatchesSearch(query))
        }

        return sortedContentItems(filteredItems)
    }

    var visibleContentRows: [ContentDisplayRow] {
        let flatItems = visibleContentItems
        let games = flatItems.filter(\.isGameContent)
        var groupedSaveIDs = Set<String>()
        var saveGroups: [String: [PSPContentItem]] = [:]

        for save in flatItems where save.kind == .save {
            guard let game = matchingGame(for: save, in: games) else {
                continue
            }

            saveGroups[game.id, default: []].append(save)
            groupedSaveIDs.insert(save.id)
        }

        return flatItems.compactMap { item in
            if item.isGameContent {
                let saves = sortedContentItems(saveGroups[item.id] ?? [])

                return saves.isEmpty ? .item(item) : .gameGroup(parent: item, saves: saves)
            }

            if groupedSaveIDs.contains(item.id) {
                return nil
            }

            if item.hasExpandableChildren {
                return .expandableGroup(parent: item, children: visibleChildren(for: item))
            }

            return .item(item)
        }
    }

    var selectedItems: [PSPContentItem] {
        contentItems.flatMap { selectedItems(in: $0, ancestorSelected: false) }
    }

    var selectionSummary: String {
        if backupMode == .fullDisk {
            let bytes = contentItems.reduce(Int64(0)) { $0 + $1.byteCount }
            if let backupAnalysis {
                return "Everything - \(backupAnalysis.summaryText)"
            }

            return "Everything - \(ByteCountFormatter.backupString(from: bytes)) indexed"
        }

        let items = selectedItems
        let bytes = items.reduce(Int64(0)) { $0 + $1.byteCount }
        return "\(items.count) selected - \(ByteCountFormatter.backupString(from: bytes))"
    }

    var memoryUsageText: String {
        displayedStorageUsage?.counterText ?? "Unknown"
    }

    var displayedStorageUsage: StorageUsage? {
        storageUsage ?? selectedProfile?.lastStorageUsage
    }

    var isShowingLastKnownStorage: Bool {
        displayedStorageUsage != nil && (storageUsage == nil || selectedVolumeID == nil)
    }

    var backupDestinationURL: URL? {
        guard let appSettings else {
            return nil
        }

        return BookmarkStore.resolve(appSettings.backupRootBookmark) ?? appSettings.backupRootURL
    }

    func start() {
        refreshVolumes()
        if let destination = backupDestinationURL {
            updateProfilesForGlobalDestination(destination)
            createLinkedDeviceBackupFolders(in: destination)
        }
        ensureBackupDestinationConfigured()
    }

    func showBackupDestinationSetup(required: Bool = false) {
        destinationSetupContext = BackupDestinationSetupContext(
            currentURL: backupDestinationURL,
            defaultURL: defaultDestinationURL(),
            isRequired: required || appSettings == nil
        )
    }

    func showSettings() {
        settingsContext = SettingsContext()
    }

    func saveBackupDestination(_ destination: URL) {
        let destination = destination.standardizedFileURL
        if let oldDestination = backupDestinationURL?.standardizedFileURL,
           oldDestination.path != destination.path,
           backupDataAvailable(in: oldDestination) {
            destinationMovePrompt = DestinationMovePrompt(oldURL: oldDestination, newURL: destination)
            return
        }

        applyBackupDestination(destination, moveBackupsFrom: nil)
    }

    func confirmDestinationChange(_ prompt: DestinationMovePrompt, moveBackups: Bool) {
        destinationMovePrompt = nil
        applyBackupDestination(prompt.newURL, moveBackupsFrom: moveBackups ? prompt.oldURL : nil)
    }

    private func applyBackupDestination(_ destination: URL, moveBackupsFrom oldDestination: URL?) {
        let destination = destination.standardizedFileURL
        let access = destination.startAccessingSecurityScopedResource()
        defer {
            if access {
                destination.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let bookmark = BookmarkStore.makeBookmark(for: destination)
            var settings = AppBackupSettings.new(destination: destination, bookmark: bookmark)
            if let existingSettings = appSettings {
                settings.createdAt = existingSettings.createdAt
            }

            if let oldDestination {
                try moveExistingBackupFolders(from: oldDestination, to: destination)
            }

            appSettings = settings
            AppSettingsStore.save(settings)
            updateProfilesForGlobalDestination(destination)
            createLinkedDeviceBackupFolders(in: destination)
            progressMessage = "Backup destination set to \(destination.path)."
            reloadSelectedVolumeContent()
        } catch {
            alert = AlertInfo(title: "Destination Failed", message: error.localizedDescription)
        }
    }

    private func ensureBackupDestinationConfigured() {
        guard appSettings == nil else {
            return
        }

        showBackupDestinationSetup(required: true)
    }

    func updateRelativeTime(_ date: Date) {
        relativeTimeNow = date
    }

    func lastSeenText(for profile: PSPDeviceProfile) -> String {
        if isOnline(profile) {
            return "Now"
        }

        return profile.lastSeenText(relativeTo: relativeTimeNow)
    }

    func lastBackupText(for profile: PSPDeviceProfile?) -> String {
        profile?.lastBackupText(relativeTo: relativeTimeNow) ?? "No backups yet"
    }

    func storageText(for profile: PSPDeviceProfile) -> String {
        profile.lastStorageUsage?.counterText ?? "Unknown"
    }

    var backupPercentText: String {
        if isAnalyzingBackup {
            return "Checking"
        }

        return backupAnalysis?.currentPercentText ?? "No backup"
    }

    var backupNeedsText: String {
        if isAnalyzingBackup {
            return "..."
        }

        return backupAnalysis?.needsBackupText ?? "-"
    }

    var canStartBackup: Bool {
        guard !isRunning,
              !isScanningContent,
              !isAnalyzingBackup,
              selectedVolume != nil,
              backupDestinationURL != nil else {
            return false
        }

        if backupMode == .selectedItems, selectedItems.isEmpty {
            return false
        }

        guard selectedVolume.flatMap({ profile(for: $0) }) != nil else {
            return false
        }

        return hasBackupChangesAvailable
    }

    var backupButtonTitle: String {
        if isRunning {
            return "Backing Up"
        }

        if backupMode == .selectedItems, selectedItems.isEmpty {
            return "Start Backup"
        }

        if selectedVolume.flatMap({ profile(for: $0) }) != nil,
           backupAnalysis != nil,
           !hasBackupChangesAvailable {
            return "Up to Date"
        }

        return "Start Backup"
    }

    private var hasBackupChangesAvailable: Bool {
        guard let backupAnalysis else {
            return true
        }

        if backupMode == .fullDisk {
            return backupAnalysis.filesNeedingSync > 0
        }

        return selectedItems.contains { $0.needsBackup }
    }

    func refreshVolumes() {
        let discovered = PSPDetector.discoverVolumes()
        volumes = discovered
        mergeMarkers(from: discovered)

        if let selectedVolumeID, !volumes.contains(where: { $0.id == selectedVolumeID }) {
            self.selectedVolumeID = nil
        }

        if selectedVolumeID == nil, let onlineProfile = profiles.first(where: isOnline(_:)),
           let volume = volumes.first(where: { $0.profileID == onlineProfile.id }) {
            select(volume)
        } else if selectedVolumeID == nil, let firstVolume = volumes.first {
            select(firstVolume)
        } else if selectedVolumeID == nil, selectedProfileID == nil, let firstProfile = profiles.first {
            select(firstProfile)
        } else if let selectedVolume {
            loadContent(for: selectedVolume)
        }
    }

    func choosePSPFolder() {
        guard backupDestinationURL != nil else {
            showBackupDestinationSetup(required: true)
            return
        }

        FolderPanel.chooseFolder(
            title: "Choose PSP",
            message: "Select a PSP Memory Stick or its PSP folder.",
            canCreateDirectories: false,
            prompt: "Add"
        ) { [weak self] url in
            guard let self else {
                return
            }

            do {
                let volume = try PSPDetector.externalVolume(from: url)
                if !self.volumes.contains(where: { $0.id == volume.id }) {
                    self.volumes.append(volume)
                    self.volumes.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                }
                self.mergeMarkers(from: [volume])
                self.select(volume)
            } catch {
                self.alert = AlertInfo(title: "Cannot Add Device", message: error.localizedDescription)
            }
        }
    }

    func select(_ volume: PSPVolume) {
        selectedVolumeID = volume.id
        selectedProfileID = profile(for: volume)?.id
        progressMessage = profile(for: volume).map { "Ready for \($0.name)." } ?? "Set up \(volume.fallbackName)."
        loadContent(for: volume)
    }

    func select(_ profile: PSPDeviceProfile) {
        if let onlineVolume = volumes.first(where: { $0.profileID == profile.id }) {
            select(onlineVolume)
            return
        }

        selectedProfileID = profile.id
        selectedVolumeID = nil
        contentItems = []
        selectedItemIDs = []
        backupAnalysis = nil
        storageUsage = profile.lastStorageUsage
        expandedItemIDs = []
        isScanningContent = false
        isAnalyzingBackup = false
        if contentFilter == .outdated {
            contentFilter = .all
        }
        progressMessage = "\(profile.name) is not mounted."
        loadBackupContent(for: profile)
    }

    func isSelected(_ volume: PSPVolume) -> Bool {
        selectedVolumeID == volume.id
    }

    func isSelected(_ profile: PSPDeviceProfile) -> Bool {
        selectedProfileID == profile.id
    }

    func isOnline(_ profile: PSPDeviceProfile) -> Bool {
        volumes.contains { $0.profileID == profile.id }
    }

    func profile(for volume: PSPVolume) -> PSPDeviceProfile? {
        guard let profileID = volume.profileID else {
            return nil
        }

        return profiles.first { $0.id == profileID }
    }

    func showSetup(for volume: PSPVolume) {
        guard backupDestinationURL != nil else {
            showBackupDestinationSetup(required: true)
            return
        }

        let profile = profile(for: volume)
        setupContext = DeviceSetupContext(
            volume: volume,
            profile: profile
        )
    }

    func completeSetup(context: DeviceSetupContext, name: String, color: DeviceColor, note: String) {
        guard let destination = backupDestinationURL?.standardizedFileURL else {
            showBackupDestinationSetup(required: true)
            return
        }

        let destinationAccess = destination.startAccessingSecurityScopedResource()
        defer {
            if destinationAccess {
                destination.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            var marker = context.volume.marker ?? PSPDeviceMarker.new(name: name, color: color, destination: destination, note: note)
            marker.displayName = name
            marker.color = color
            marker.backupDestinationPath = destination.path
            marker.note = note
            marker.updatedAt = Date()

            let sourceAccess = context.volume.rootURL.startAccessingSecurityScopedResource()
            defer {
                if sourceAccess {
                    context.volume.rootURL.stopAccessingSecurityScopedResource()
                }
            }

            try PSPDetector.writeMarker(marker, to: context.volume.rootURL)

            upsertProfile(marker: marker, bookmark: nil, volumePath: context.volume.rootURL.path)
            createLinkedDeviceBackupFolder(for: marker.identifier, in: destination)
            progressMessage = "Linked \(name)."
            refreshVolumes()
            if let refreshed = volumes.first(where: { $0.rootURL.standardizedFileURL == context.volume.rootURL.standardizedFileURL }) {
                select(refreshed)
            }
        } catch {
            alert = AlertInfo(title: "Setup Failed", message: error.localizedDescription)
        }
    }

    func setItem(_ item: PSPContentItem, selected: Bool) {
        if selected {
            selectedItemIDs.insert(item.id)
        } else {
            selectedItemIDs.remove(item.id)
        }
    }

    func selectAllVisibleItems() {
        for item in visibleContentItems {
            selectedItemIDs.insert(item.id)
        }
    }

    func clearVisibleItems() {
        for item in visibleContentItems {
            selectedItemIDs.remove(item.id)
            for child in item.descendants {
                selectedItemIDs.remove(child.id)
            }
        }
    }

    func isExpanded(_ item: PSPContentItem) -> Bool {
        expandedItemIDs.contains(item.id)
    }

    func toggleExpanded(_ item: PSPContentItem) {
        if expandedItemIDs.contains(item.id) {
            expandedItemIDs.remove(item.id)
        } else {
            expandedItemIDs.insert(item.id)
        }
    }

    func visibleChildren(for item: PSPContentItem) -> [PSPContentItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentMatchesQuery = query.isEmpty || item.matchesSearch(query)

        let filteredChildren = item.children.filter { child in
            parentMatchesQuery || child.deepMatchesSearch(query)
        }

        return sortedContentItems(filteredChildren)
    }

    private func sortedContentItems(_ items: [PSPContentItem]) -> [PSPContentItem] {
        switch contentSort {
        case .defaultOrder:
            return items
        case .storage:
            return items.sorted { lhs, rhs in
                if lhs.byteCount != rhs.byteCount {
                    return lhs.byteCount > rhs.byteCount
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        case .lastChanged:
            return items.sorted { lhs, rhs in
                switch (lastChangedSortDate(for: lhs), lastChangedSortDate(for: rhs)) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
        }
    }

    private func lastChangedSortDate(for item: PSPContentItem) -> Date? {
        if item.isGameContent, let latestSaveDate = latestSaveDate(for: item) {
            return latestSaveDate
        }

        return item.latestChangeDate
    }

    private func latestSaveDate(for game: PSPContentItem) -> Date? {
        contentItems
            .filter { $0.kind == .save && matchingGame(for: $0, in: [game]) != nil }
            .compactMap(\.latestChangeDate)
            .max()
    }

    private func selectedItems(in item: PSPContentItem, ancestorSelected: Bool) -> [PSPContentItem] {
        let isSelected = selectedItemIDs.contains(item.id)
        if isSelected {
            return [item]
        }

        guard !ancestorSelected else {
            return []
        }

        return item.children.flatMap { selectedItems(in: $0, ancestorSelected: false) }
    }

    private func matchingGame(for save: PSPContentItem, in games: [PSPContentItem]) -> PSPContentItem? {
        let saveKeys = save.gameIdentityKeys

        if !saveKeys.isEmpty,
           let match = games.first(where: { !$0.gameIdentityKeys.isDisjoint(with: saveKeys) }) {
            return match
        }

        let saveTitle = save.matchableTitle
        guard saveTitle.count >= 4 else {
            return nil
        }

        return games.first { game in
            let gameTitle = game.matchableTitle
            guard gameTitle.count >= 4 else {
                return false
            }

            return saveTitle.contains(gameTitle) || gameTitle.contains(saveTitle)
        }
    }

    func startBackup() {
        guard let volume = selectedVolume else {
            alert = AlertInfo(title: "Choose a PSP", message: "Select a connected PSP to back up.")
            return
        }

        guard let profile = profile(for: volume) else {
            alert = AlertInfo(title: "Setup Required", message: "Set up this PSP before backing it up.")
            return
        }

        guard let destinationURL = backupDestinationURL else {
            showBackupDestinationSetup(required: true)
            return
        }

        let selectedItems = backupMode == .fullDisk ? contentItems : self.selectedItems

        if backupMode == .selectedItems, selectedItems.isEmpty {
            alert = AlertInfo(title: "Nothing Selected", message: "Select at least one save, game, theme, plugin, or folder.")
            return
        }

        guard hasBackupChangesAvailable else {
            progressTitle = "Ready"
            progressSummary = "100%"
            progressFraction = 1
            progressMessage = "\(profile.name) is already up to date."
            return
        }

        isRunning = true
        progressFraction = 0
        progressTitle = "Starting"
        progressSummary = "0%"
        progressMessage = "Preparing \(profile.name)..."

        let cancellation = BackupCancellation()
        self.cancellation = cancellation

        let request = BackupRequest(
            volume: volume,
            profile: profile,
            mode: backupMode,
            selectedItems: selectedItems,
            destinationURL: destinationURL
        )

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try BackupEngine.run(request: request, cancellation: cancellation) { progress in
                    DispatchQueue.main.async {
                        self.apply(progress)
                    }
                }

                DispatchQueue.main.async {
                    self.finishBackup(result: result, profileID: profile.id)
                }
            } catch PSPBackupError.cancelled {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.cancellation = nil
                    self.progressTitle = "Cancelled"
                    self.progressSummary = "0%"
                    self.progressFraction = 0
                    self.progressMessage = "Backup cancelled."
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.cancellation = nil
                    self.progressTitle = "Failed"
                    self.progressSummary = "0%"
                    self.progressFraction = 0
                    self.progressMessage = "Backup failed."
                    self.alert = AlertInfo(title: "Backup Failed", message: error.localizedDescription)
                }
            }
        }
    }

    func cancelBackup() {
        cancellation?.cancel()
        progressMessage = "Cancelling..."
    }

    func openDestination(for profile: PSPDeviceProfile) {
        guard let destinationURL = backupDestinationURL else {
            showBackupDestinationSetup(required: true)
            return
        }

        let url = BackupEngine.deviceBackupRoot(for: profile, destinationRoot: destinationURL)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    func eject(_ volume: PSPVolume) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volume.rootURL)
            progressMessage = "\(volume.displayName) was ejected."
            refreshVolumes()
        } catch {
            alert = AlertInfo(title: "Eject Failed", message: error.localizedDescription)
        }
    }

    func resetAppData() {
        cancellation?.cancel()
        cancellation = nil
        DeviceStore.reset()
        AppSettingsStore.reset()
        IconCache.reset()

        profiles = []
        appSettings = nil
        selectedVolumeID = nil
        selectedProfileID = nil
        contentItems = []
        selectedItemIDs = []
        backupAnalysis = nil
        storageUsage = nil
        backupMode = .fullDisk
        contentFilter = .all
        contentSort = .defaultOrder
        searchText = ""
        expandedItemIDs = []
        isRunning = false
        isScanningContent = false
        isAnalyzingBackup = false
        setupContext = nil
        destinationSetupContext = nil
        destinationMovePrompt = nil
        backupCompletion = nil
        progressTitle = "Reset"
        progressSummary = "0%"
        progressFraction = 0
        progressMessage = "App data was reset. Backups were not deleted."
        DispatchQueue.main.async { [weak self] in
            self?.showBackupDestinationSetup(required: true)
        }
    }

    private func loadContent(for volume: PSPVolume) {
        touchLastSeen(for: volume)

        let token = UUID()
        scanToken = token
        isScanningContent = true
        isAnalyzingBackup = profile(for: volume) != nil
        backupAnalysis = nil
        storageUsage = nil
        contentItems = []
        selectedItemIDs = []
        expandedItemIDs = []
        if !isRunning {
            progressTitle = "Scanning"
            progressSummary = "0%"
            progressFraction = 0
            progressMessage = "Checking PSP content..."
        }
        let profile = profile(for: volume)
        let destinationURL = profile.flatMap { _ in backupDestinationURL }

        DispatchQueue.global(qos: .userInitiated).async {
            let sourceAccess = volume.rootURL.startAccessingSecurityScopedResource()
            var items = PSPContentScanner.scan(volume: volume)
            let storageUsage = StorageUsage.read(from: volume.rootURL)
            var backupAnalysis: BackupAnalysis?

            if let profile, let destinationURL {
                let destinationAccess = destinationURL.startAccessingSecurityScopedResource()
                backupAnalysis = BackupEngine.analyzeBackup(
                    volume: volume,
                    profile: profile,
                    destinationURL: destinationURL,
                    items: items
                )
                if destinationAccess {
                    destinationURL.stopAccessingSecurityScopedResource()
                }

                items = BackupEngine.applyBackupAnalysis(backupAnalysis, to: items)
            }

            if sourceAccess {
                volume.rootURL.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                guard self.scanToken == token else {
                    return
                }

                self.contentItems = items
                self.selectedItemIDs = Set(items.map(\.id))
                self.expandedItemIDs.formIntersection(Set(items.flatMap(\.treeIDs)))
                self.storageUsage = storageUsage
                if let storageUsage {
                    self.rememberStorageUsage(storageUsage, for: volume)
                }
                self.backupAnalysis = backupAnalysis
                self.isScanningContent = false
                self.isAnalyzingBackup = false
                if items.isEmpty {
                    self.progressTitle = "Ready"
                    self.progressSummary = "0%"
                    self.progressFraction = 0
                    self.progressMessage = "No PSP content was indexed."
                } else if let backupAnalysis {
                    self.progressTitle = "Backup Check"
                    self.progressSummary = backupAnalysis.currentPercentText
                    self.progressFraction = backupAnalysis.currentFraction
                    self.progressMessage = backupAnalysis.summaryText
                } else {
                    self.progressTitle = "Indexed"
                    self.progressSummary = "\(items.count)"
                    self.progressFraction = 1
                    self.progressMessage = "Indexed \(items.count) backup items."
                }
            }
        }
    }

    private func loadBackupContent(for profile: PSPDeviceProfile) {
        guard let destinationURL = backupDestinationURL else {
            progressMessage = "\(profile.name) is offline. Choose a backup destination to browse backups."
            return
        }

        let token = UUID()
        scanToken = token
        isScanningContent = true
        isAnalyzingBackup = false
        backupAnalysis = nil
        storageUsage = profile.lastStorageUsage
        contentItems = []
        selectedItemIDs = []
        expandedItemIDs = []
        progressTitle = "Loading"
        progressSummary = "0%"
        progressFraction = 0
        progressMessage = "Loading backup contents for \(profile.name)..."

        DispatchQueue.global(qos: .userInitiated).async {
            let access = destinationURL.startAccessingSecurityScopedResource()
            let contentRoot = BackupEngine.deviceBackupContentRoot(for: profile, destinationRoot: destinationURL)
            let pspDirectory = contentRoot.appendingPathComponent("PSP", isDirectory: true)
            let backupVolume = PSPVolume(rootURL: contentRoot, pspDirectoryURL: pspDirectory, marker: nil)
            let items = FileManager.default.isDirectory(contentRoot) ? PSPContentScanner.scan(volume: backupVolume) : []

            if access {
                destinationURL.stopAccessingSecurityScopedResource()
            }

            DispatchQueue.main.async {
                guard self.scanToken == token, self.selectedProfileID == profile.id, self.selectedVolumeID == nil else {
                    return
                }

                self.contentItems = items
                self.selectedItemIDs = []
                self.expandedItemIDs.formIntersection(Set(items.flatMap(\.treeIDs)))
                self.isScanningContent = false
                self.isAnalyzingBackup = false
                self.progressTitle = "Offline"
                self.progressSummary = "\(items.count)"
                self.progressFraction = items.isEmpty ? 0 : 1
                self.progressMessage = items.isEmpty ? "No backup contents found for \(profile.name)." : "Loaded \(items.count) items from backup."
            }
        }
    }

    private func touchLastSeen(for volume: PSPVolume) {
        guard let marker = volume.marker,
              let index = profiles.firstIndex(where: { $0.id == marker.identifier }) else {
            return
        }

        var updatedProfiles = profiles
        updatedProfiles[index].lastSeenAt = Date()
        updatedProfiles[index].lastVolumePath = volume.rootURL.path
        profiles = updatedProfiles
        DeviceStore.save(updatedProfiles)
    }

    private func rememberStorageUsage(_ usage: StorageUsage, for volume: PSPVolume) {
        guard let marker = volume.marker,
              let index = profiles.firstIndex(where: { $0.id == marker.identifier }) else {
            return
        }

        var updatedProfiles = profiles
        guard updatedProfiles[index].lastStorageUsage != usage else {
            return
        }

        updatedProfiles[index].lastStorageUsage = usage
        updatedProfiles[index].lastStorageUpdatedAt = Date()
        profiles = updatedProfiles
        DeviceStore.save(updatedProfiles)
    }

    private func mergeMarkers(from volumes: [PSPVolume]) {
        var updatedProfiles = profiles
        var changed = false
        var adoptedNames: [String] = []
        let seenAt = Date()

        for volume in volumes {
            guard let marker = volume.marker else {
                continue
            }

            if let index = updatedProfiles.firstIndex(where: { $0.id == marker.identifier }) {
                let existingProfile = updatedProfiles[index]
                var refreshedProfile = existingProfile
                refreshedProfile.name = marker.displayName
                refreshedProfile.color = marker.color
                refreshedProfile.note = marker.note
                refreshedProfile.destinationPath = localDestinationPath(for: marker, existingProfile: existingProfile)
                refreshedProfile.updatedAt = marker.updatedAt
                refreshedProfile.lastSeenAt = seenAt
                refreshedProfile.lastVolumePath = volume.rootURL.path

                if refreshedProfile != existingProfile {
                    updatedProfiles[index] = refreshedProfile
                    changed = true
                }
            } else {
                var localMarker = marker
                localMarker.backupDestinationPath = localDestinationPath(for: marker, existingProfile: nil)
                let profile = PSPDeviceProfile.from(marker: localMarker, destinationBookmark: nil, volumePath: volume.rootURL.path)
                updatedProfiles.append(profile)
                adoptedNames.append(profile.name)
                changed = true
            }
        }

        if changed {
            updatedProfiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            profiles = updatedProfiles
            DeviceStore.save(updatedProfiles)

            if !adoptedNames.isEmpty {
                let names = adoptedNames.joined(separator: ", ")
                progressMessage = "Added linked PSP from device file: \(names)."
            }
        }
    }

    private func upsertProfile(marker: PSPDeviceMarker, bookmark: Data?, volumePath: String?) {
        var updatedProfiles = profiles

        if let index = updatedProfiles.firstIndex(where: { $0.id == marker.identifier }) {
            let oldBackupAt = updatedProfiles[index].lastBackupAt
            let oldBackupPath = updatedProfiles[index].lastBackupPath
            let oldBackupCount = updatedProfiles[index].backupCount
            let oldStorageUsage = updatedProfiles[index].lastStorageUsage
            let oldStorageUpdatedAt = updatedProfiles[index].lastStorageUpdatedAt
            updatedProfiles[index] = PSPDeviceProfile.from(marker: marker, destinationBookmark: bookmark, volumePath: volumePath)
            updatedProfiles[index].lastBackupAt = oldBackupAt
            updatedProfiles[index].lastBackupPath = oldBackupPath
            updatedProfiles[index].backupCount = oldBackupCount
            updatedProfiles[index].lastStorageUsage = oldStorageUsage
            updatedProfiles[index].lastStorageUpdatedAt = oldStorageUpdatedAt
        } else {
            updatedProfiles.append(PSPDeviceProfile.from(marker: marker, destinationBookmark: bookmark, volumePath: volumePath))
        }

        updatedProfiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        profiles = updatedProfiles
        DeviceStore.save(updatedProfiles)
    }

    private func finishBackup(result: BackupResult, profileID: String) {
        isRunning = false
        cancellation = nil
        progressFraction = 1
        progressTitle = "Complete"
        progressSummary = "100%"
        if result.fileCount == 0, result.deletedFileCount == 0 {
            progressMessage = "Backup already up to date. \(result.totalFileCount) files checked."
        } else {
            progressMessage = "Updated \(result.fileCount) files, deleted \(result.deletedFileCount), \(result.skippedFileCount) unchanged."
        }

        let completionSummary = makeBackupCompletionSummary(result: result, profileID: profileID)

        if let index = profiles.firstIndex(where: { $0.id == profileID }) {
            var updatedProfiles = profiles
            updatedProfiles[index].lastBackupAt = Date()
            updatedProfiles[index].lastBackupPath = result.backupURL.path
            updatedProfiles[index].backupCount += 1
            profiles = updatedProfiles
            DeviceStore.save(updatedProfiles)
        }

        backupCompletion = completionSummary
        reloadSelectedVolumeContent()
    }

    private func reloadSelectedVolumeContent() {
        if let selectedVolume {
            loadContent(for: selectedVolume)
            return
        }

        if let selectedProfile {
            loadBackupContent(for: selectedProfile)
        }
    }

    private func apply(_ progress: BackupProgress) {
        progressFraction = progress.fraction
        progressTitle = progress.title
        progressSummary = progress.summary
        progressMessage = progress.message
    }

    private func makeBackupCompletionSummary(result: BackupResult, profileID: String) -> BackupCompletionSummary {
        let profileName = profiles.first(where: { $0.id == profileID })?.name ?? "PSP"
        let changedItems = contentItemsImpacted(by: result.changedFileRelativePaths)

        return BackupCompletionSummary(
            profileName: profileName,
            backupURL: result.backupURL,
            logURL: result.logURL,
            changedFileCount: result.fileCount,
            changedByteCount: result.byteCount,
            deletedFileCount: result.deletedFileCount,
            unchangedFileCount: result.skippedFileCount,
            totalFileCount: result.totalFileCount,
            totalByteCount: result.totalByteCount,
            changedItems: changedItems,
            deletedRelativePaths: result.deletedFileRelativePaths
        )
    }

    private func contentItemsImpacted(by relativePaths: [String]) -> [PSPContentItem] {
        guard !relativePaths.isEmpty else {
            return []
        }

        let sortedItems = contentItems.sorted { lhs, rhs in
            lhs.relativePath.count > rhs.relativePath.count
        }
        var itemIDs = Set<String>()

        for relativePath in relativePaths {
            guard let item = sortedItems.first(where: { item in
                relativePath == item.relativePath || relativePath.hasPrefix(item.relativePath + "/")
            }) else {
                continue
            }

            itemIDs.insert(item.id)
        }

        return contentItems.filter { itemIDs.contains($0.id) }
    }

    private func migratedBackupSettings(from profiles: [PSPDeviceProfile]) -> AppBackupSettings? {
        let fileManager = FileManager.default

        for profile in profiles {
            let resolvedURL = BookmarkStore.resolve(profile.destinationBookmark)
            let pathURL = profile.destinationPath.isEmpty ? nil : URL(fileURLWithPath: profile.destinationPath, isDirectory: true)

            for url in [resolvedURL, pathURL].compactMap({ $0 }) {
                let standardizedURL = url.standardizedFileURL
                guard fileManager.isDirectory(standardizedURL) else {
                    continue
                }

                return AppBackupSettings.new(
                    destination: standardizedURL,
                    bookmark: profile.destinationBookmark ?? BookmarkStore.makeBookmark(for: standardizedURL)
                )
            }
        }

        return nil
    }

    private func updateProfilesForGlobalDestination(_ destination: URL) {
        guard !profiles.isEmpty else {
            return
        }

        let destination = destination.standardizedFileURL
        var updatedProfiles = profiles

        for index in updatedProfiles.indices {
            updatedProfiles[index].destinationPath = destination.path
            updatedProfiles[index].destinationBookmark = nil

            if let lastBackupPath = updatedProfiles[index].lastBackupPath {
                let lastBackupURL = URL(fileURLWithPath: lastBackupPath, isDirectory: true).standardizedFileURL
                if !lastBackupURL.isEqualToOrInside(destination) {
                    updatedProfiles[index].lastBackupPath = nil
                }
            }
        }

        profiles = updatedProfiles
        DeviceStore.save(updatedProfiles)
    }

    private func backupDataAvailable(in destination: URL) -> Bool {
        backupFolderMovePlans(from: destination, to: destination).contains { plan in
            FileManager.default.isDirectory(plan.source)
        }
    }

    private func moveExistingBackupFolders(from oldDestination: URL, to newDestination: URL) throws {
        let fileManager = FileManager.default
        let plans = backupFolderMovePlans(from: oldDestination, to: newDestination)
        guard !plans.isEmpty else {
            return
        }

        try fileManager.createDirectory(at: newDestination, withIntermediateDirectories: true)
        var movedProfilePaths: [String: String] = [:]

        for plan in plans where fileManager.isDirectory(plan.source) {
            guard plan.source.standardizedFileURL.path != plan.destination.standardizedFileURL.path else {
                continue
            }

            try moveOrMergeItem(from: plan.source, to: plan.destination)
            movedProfilePaths[plan.profileID] = plan.destination.path
        }

        guard !movedProfilePaths.isEmpty else {
            return
        }

        var updatedProfiles = profiles
        for index in updatedProfiles.indices {
            if let movedPath = movedProfilePaths[updatedProfiles[index].id] {
                updatedProfiles[index].lastBackupPath = movedPath
            }
        }

        profiles = updatedProfiles
        DeviceStore.save(updatedProfiles)
    }

    private func backupFolderMovePlans(from oldDestination: URL, to newDestination: URL) -> [BackupFolderMovePlan] {
        var plans: [BackupFolderMovePlan] = []
        var seenSources = Set<String>()

        for profile in profiles {
            let standardSource = BackupEngine.deviceBackupRoot(for: profile, destinationRoot: oldDestination)
            let standardDestination = BackupEngine.deviceBackupRoot(for: profile, destinationRoot: newDestination)
            appendMovePlan(profileID: profile.id, source: standardSource, destination: standardDestination, plans: &plans, seenSources: &seenSources)

            if let lastBackupPath = profile.lastBackupPath {
                let lastBackupURL = URL(fileURLWithPath: lastBackupPath, isDirectory: true).standardizedFileURL
                if lastBackupURL.isEqualToOrInside(oldDestination) {
                    appendMovePlan(profileID: profile.id, source: lastBackupURL, destination: standardDestination, plans: &plans, seenSources: &seenSources)
                }
            }
        }

        return plans
    }

    private func appendMovePlan(
        profileID: String,
        source: URL,
        destination: URL,
        plans: inout [BackupFolderMovePlan],
        seenSources: inout Set<String>
    ) {
        let source = source.standardizedFileURL
        guard seenSources.insert(source.path).inserted else {
            return
        }

        plans.append(BackupFolderMovePlan(profileID: profileID, source: source, destination: destination.standardizedFileURL))
    }

    private func moveOrMergeItem(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        var sourceIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &sourceIsDirectory) else {
            return
        }

        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: source, to: destination)
            return
        }

        var destinationIsDirectory: ObjCBool = false
        fileManager.fileExists(atPath: destination.path, isDirectory: &destinationIsDirectory)

        if sourceIsDirectory.boolValue, destinationIsDirectory.boolValue {
            let children = try fileManager.contentsOfDirectory(
                at: source,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )

            for child in children {
                try moveOrMergeItem(from: child, to: destination.appendingPathComponent(child.lastPathComponent))
            }

            if (try? fileManager.contentsOfDirectory(atPath: source.path).isEmpty) == true {
                try fileManager.removeItem(at: source)
            }
            return
        }

        try fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: source, to: destination)
    }

    private func createLinkedDeviceBackupFolders(in destination: URL) {
        for profile in profiles {
            let folder = BackupEngine.deviceBackupRoot(for: profile, destinationRoot: destination)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    private func createLinkedDeviceBackupFolder(for profileID: String, in destination: URL) {
        guard let profile = profiles.first(where: { $0.id == profileID }) else {
            return
        }

        let folder = BackupEngine.deviceBackupRoot(for: profile, destinationRoot: destination)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func startWatchingVolumes() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]

        volumeObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshVolumes()
            }
        }
    }

    private func defaultDestinationURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PSP Backups", isDirectory: true)
    }

    private func localDestinationPath(for marker: PSPDeviceMarker, existingProfile: PSPDeviceProfile?) -> String {
        let fileManager = FileManager.default

        if let destination = backupDestinationURL {
            return destination.path
        }

        if !marker.backupDestinationPath.isEmpty {
            let markerDestination = URL(fileURLWithPath: marker.backupDestinationPath, isDirectory: true).standardizedFileURL
            if fileManager.isDirectory(markerDestination) {
                return markerDestination.path
            }
        }

        if let existingProfile, !existingProfile.destinationPath.isEmpty {
            return existingProfile.destinationPath
        }

        let fallbackDestination = defaultDestinationURL()
        try? fileManager.createDirectory(at: fallbackDestination, withIntermediateDirectories: true)
        return fallbackDestination.path
    }
}

struct DeviceSetupContext: Identifiable {
    var volume: PSPVolume
    var profile: PSPDeviceProfile?

    var id: String {
        "\(volume.id)-\(profile?.id ?? "new")"
    }

    var isEditing: Bool {
        profile != nil
    }

    var name: String {
        profile?.name ?? volume.displayName
    }

    var color: DeviceColor {
        profile?.color ?? volume.marker?.color ?? .teal
    }

    var note: String {
        profile?.note ?? volume.marker?.note ?? ""
    }
}

struct BackupDestinationSetupContext: Identifiable {
    let id = UUID()
    var currentURL: URL?
    var defaultURL: URL
    var isRequired: Bool
}

struct DestinationMovePrompt: Identifiable {
    let id = UUID()
    var oldURL: URL
    var newURL: URL
}

struct SettingsContext: Identifiable {
    let id = UUID()
}

private struct BackupFolderMovePlan {
    var profileID: String
    var source: URL
    var destination: URL
}

struct BackupCompletionSummary: Identifiable {
    let id = UUID()
    var profileName: String
    var backupURL: URL
    var logURL: URL
    var changedFileCount: Int
    var changedByteCount: Int64
    var deletedFileCount: Int
    var unchangedFileCount: Int
    var totalFileCount: Int
    var totalByteCount: Int64
    var changedItems: [PSPContentItem]
    var deletedRelativePaths: [String]

    var isAlreadyCurrent: Bool {
        changedFileCount == 0 && deletedFileCount == 0
    }

    var isCleanupOnly: Bool {
        changedFileCount == 0 && deletedFileCount > 0
    }

    var title: String {
        isAlreadyCurrent ? "Backup Already Current" : "Backup Complete"
    }

    var subtitle: String {
        if isAlreadyCurrent {
            return "\(profileName) has \(totalFileCount) files current."
        }

        if isCleanupOnly {
            return "\(profileName) removed \(deletedFileCount) stale backup files."
        }

        return "\(profileName) synced \(changedFileCount) files and checked \(totalFileCount)."
    }

    var changedByteText: String {
        ByteCountFormatter.backupString(from: changedByteCount)
    }

    var emptyChangeSymbolName: String {
        if isAlreadyCurrent {
            return "checkmark.circle"
        }

        return isCleanupOnly ? "trash" : "doc.badge.clock"
    }

    var emptyChangeTitle: String {
        if isAlreadyCurrent {
            return "Everything is current"
        }

        return isCleanupOnly ? "Backup mirror cleaned" : "File changes were synced"
    }

    var emptyChangeSubtitle: String {
        if isAlreadyCurrent {
            return "\(profileName) already matched the backup."
        }

        if isCleanupOnly {
            return "\(deletedFileCount) stale backup files were removed."
        }

        return "\(changedFileCount) files changed across the memory stick."
    }
}

enum ContentDisplayRow: Identifiable {
    case item(PSPContentItem)
    case gameGroup(parent: PSPContentItem, saves: [PSPContentItem])
    case expandableGroup(parent: PSPContentItem, children: [PSPContentItem])

    var id: String {
        switch self {
        case .item(let item):
            return item.id
        case .gameGroup(let parent, _):
            return "group-\(parent.id)"
        case .expandableGroup(let parent, _):
            return "expandable-\(parent.id)"
        }
    }
}

enum ContentFilter: String, CaseIterable, Identifiable {
    case all
    case outdated
    case saves
    case games
    case media
    case extras

    var id: String {
        rawValue
    }

    static var offlineCases: [ContentFilter] {
        allCases.filter { $0 != .outdated }
    }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .outdated:
            return "Outdated"
        case .saves:
            return "Saves"
        case .games:
            return "Games"
        case .media:
            return "Media"
        case .extras:
            return "Extras"
        }
    }

    func includes(_ item: PSPContentItem) -> Bool {
        switch self {
        case .all:
            return true
        case .outdated:
            return item.backupNeedsFileCount > 0 || item.backupState == .missing || item.backupState == .changed
        case .saves:
            return item.kind == .save
        case .games:
            return item.kind == .game || item.kind == .iso
        case .media:
            return item.kind == .media || item.kind == .theme
        case .extras:
            return item.kind == .plugin || item.kind == .cheat || item.kind == .system || item.kind == .folder || item.kind == .file
        }
    }
}

enum ContentSortMode: String, CaseIterable, Identifiable {
    case defaultOrder
    case storage
    case lastChanged

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .defaultOrder:
            return "Default"
        case .storage:
            return "Storage"
        case .lastChanged:
            return "Last Changed"
        }
    }
}

enum FolderPanel {
    static func chooseFolder(
        title: String,
        message: String,
        canCreateDirectories: Bool,
        directoryURL: URL? = nil,
        prompt: String = "Choose",
        completion: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = canCreateDirectories
        panel.directoryURL = closestExistingDirectory(to: directoryURL)
        panel.prompt = prompt

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            completion(url)
        }
    }

    private static func closestExistingDirectory(to url: URL?) -> URL? {
        guard var candidate = url?.standardizedFileURL else {
            return nil
        }

        let fileManager = FileManager.default

        while true {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }

            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                return nil
            }

            candidate = parent
        }
    }
}

extension DeviceColor {
    init(color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
    }
}

private extension PSPContentItem {
    var isGameContent: Bool {
        kind == .game || kind == .iso
    }

    var hasExpandableChildren: Bool {
        !children.isEmpty
    }

    var descendants: [PSPContentItem] {
        children.flatMap { [$0] + $0.descendants }
    }

    var treeIDs: [String] {
        [id] + children.flatMap(\.treeIDs)
    }

    var latestChangeDate: Date? {
        ([modifiedAt].compactMap { $0 } + children.compactMap(\.latestChangeDate)).max()
    }

    var needsBackup: Bool {
        backupNeedsFileCount > 0
            || backupState == .missing
            || backupState == .changed
            || children.contains { $0.needsBackup }
    }

    func matchesSearch(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || subtitle.localizedCaseInsensitiveContains(query)
            || relativePath.localizedCaseInsensitiveContains(query)
    }

    func deepMatchesSearch(_ query: String) -> Bool {
        matchesSearch(query) || children.contains { $0.deepMatchesSearch(query) }
    }

    var gameIdentityKeys: Set<String> {
        var keys = Set<String>()
        let metadataKeys = ["DISC_ID", "DISCID", "CONTENT_ID"]

        for key in metadataKeys {
            if let value = sfoValues[key]?.normalizedGameIdentifier {
                keys.insert(value)
            }
        }

        if kind == .save, let folderName = relativePath.split(separator: "/").last {
            let normalizedFolder = String(folderName).alphanumericUppercased
            if normalizedFolder.count >= 9 {
                keys.insert(String(normalizedFolder.prefix(9)))
            }
        }

        return keys
    }

    var matchableTitle: String {
        let candidates = [
            sfoValues["TITLE"],
            sfoValues["TITLE_00"],
            sfoValues["SAVEDATA_TITLE"],
            title
        ]

        for candidate in candidates {
            let normalized = candidate?.normalizedContentTitle ?? ""
            if !normalized.isEmpty {
                return normalized
            }
        }

        return ""
    }
}

private extension String {
    var alphanumericUppercased: String {
        String(unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }).uppercased()
    }

    var normalizedGameIdentifier: String? {
        let cleaned = alphanumericUppercased
        guard cleaned.count >= 4 else {
            return nil
        }

        if cleaned.count >= 9 {
            return String(cleaned.prefix(9))
        }

        return cleaned
    }

    var normalizedContentTitle: String {
        String(unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }).lowercased()
    }
}

#Preview {
    ContentView()
}
