//
//  PSPBackupCore.swift
//  PSP Easy Backup
//
import AppKit
import Foundation
import SwiftUI

struct DeviceColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }

    static let teal = DeviceColor(red: 0.04, green: 0.58, blue: 0.64)
    static let indigo = DeviceColor(red: 0.29, green: 0.35, blue: 0.88)

    static let palette: [DeviceColor] = [
        DeviceColor(red: 0.04, green: 0.58, blue: 0.64),
        DeviceColor(red: 0.17, green: 0.48, blue: 0.95),
        DeviceColor(red: 0.29, green: 0.35, blue: 0.88),
        DeviceColor(red: 0.56, green: 0.31, blue: 0.86),
        DeviceColor(red: 0.82, green: 0.22, blue: 0.48),
        DeviceColor(red: 0.88, green: 0.30, blue: 0.24),
        DeviceColor(red: 0.95, green: 0.60, blue: 0.16),
        DeviceColor(red: 0.25, green: 0.62, blue: 0.27),
        DeviceColor(red: 0.13, green: 0.66, blue: 0.49),
        DeviceColor(red: 0.12, green: 0.56, blue: 0.78),
        DeviceColor(red: 0.35, green: 0.38, blue: 0.42),
        DeviceColor(red: 0.12, green: 0.12, blue: 0.14)
    ]
}

struct PSPDeviceMarker: Codable, Equatable {
    var schemaVersion: Int
    var appName: String
    var identifier: String
    var displayName: String
    var color: DeviceColor
    var backupDestinationPath: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    static func new(name: String, color: DeviceColor, destination: URL, note: String) -> PSPDeviceMarker {
        PSPDeviceMarker(
            schemaVersion: 1,
            appName: "PSP Easy Backup",
            identifier: UUID().uuidString,
            displayName: name,
            color: color,
            backupDestinationPath: destination.path,
            note: note,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

struct PSPDeviceProfile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var color: DeviceColor
    var note: String
    var destinationPath: String
    var destinationBookmark: Data?
    var createdAt: Date
    var updatedAt: Date
    var lastSeenAt: Date?
    var lastVolumePath: String?
    var lastBackupAt: Date?
    var lastBackupPath: String?
    var lastStorageUsage: StorageUsage?
    var lastStorageUpdatedAt: Date?
    var backupCount: Int

    var destinationURL: URL {
        URL(fileURLWithPath: destinationPath, isDirectory: true)
    }

    var shortID: String {
        String(id.prefix(8)).uppercased()
    }

    var backupFolderName: String {
        "\(name.safePathComponent)-\(shortID)"
    }

    var lastSeenText: String {
        lastSeenText(relativeTo: Date())
    }

    func lastSeenText(relativeTo date: Date) -> String {
        guard let lastSeenAt else {
            return "Not seen yet"
        }

        return RelativeDateTimeFormatter.pspRelative.localizedString(for: lastSeenAt, relativeTo: date)
    }

    var lastBackupText: String {
        lastBackupText(relativeTo: Date())
    }

    func lastBackupText(relativeTo date: Date) -> String {
        guard let lastBackupAt else {
            return "No backups yet"
        }

        return RelativeDateTimeFormatter.pspRelative.localizedString(for: lastBackupAt, relativeTo: date)
    }

    static func from(marker: PSPDeviceMarker, destinationBookmark: Data?, volumePath: String?) -> PSPDeviceProfile {
        PSPDeviceProfile(
            id: marker.identifier,
            name: marker.displayName,
            color: marker.color,
            note: marker.note,
            destinationPath: marker.backupDestinationPath,
            destinationBookmark: destinationBookmark,
            createdAt: marker.createdAt,
            updatedAt: marker.updatedAt,
            lastSeenAt: Date(),
            lastVolumePath: volumePath,
            lastBackupAt: nil,
            lastBackupPath: nil,
            lastStorageUsage: nil,
            lastStorageUpdatedAt: nil,
            backupCount: 0
        )
    }
}

struct AppBackupSettings: Codable, Equatable {
    var backupRootPath: String
    var backupRootBookmark: Data?
    var createdAt: Date
    var updatedAt: Date

    var backupRootURL: URL {
        URL(fileURLWithPath: backupRootPath, isDirectory: true)
    }

    static func new(destination: URL, bookmark: Data?) -> AppBackupSettings {
        let now = Date()
        return AppBackupSettings(
            backupRootPath: destination.standardizedFileURL.path,
            backupRootBookmark: bookmark,
            createdAt: now,
            updatedAt: now
        )
    }
}

struct PSPVolume: Identifiable, Equatable {
    let rootURL: URL
    let pspDirectoryURL: URL
    let marker: PSPDeviceMarker?

    var id: String {
        rootURL.standardizedFileURL.path
    }

    var profileID: String? {
        marker?.identifier
    }

    var displayName: String {
        marker?.displayName ?? fallbackName
    }

    var fallbackName: String {
        let name = rootURL.lastPathComponent
        return name.isEmpty ? rootURL.path : name
    }

    var isConfigured: Bool {
        marker != nil
    }
}

enum BackupMode: String, CaseIterable, Codable, Identifiable {
    case fullDisk
    case selectedItems

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fullDisk:
            return "Everything"
        case .selectedItems:
            return "Selected"
        }
    }
}

enum ContentKind: String, Codable, CaseIterable {
    case save
    case game
    case iso
    case theme
    case plugin
    case cheat
    case media
    case system
    case folder
    case file

    var title: String {
        switch self {
        case .save:
            return "Save"
        case .game:
            return "Game"
        case .iso:
            return "ISO"
        case .theme:
            return "Theme"
        case .plugin:
            return "Plugin"
        case .cheat:
            return "Cheat"
        case .media:
            return "Media"
        case .system:
            return "System"
        case .folder:
            return "Folder"
        case .file:
            return "File"
        }
    }

    var symbolName: String {
        switch self {
        case .save:
            return "memorychip"
        case .game:
            return "gamecontroller"
        case .iso:
            return "opticaldiscdrive"
        case .theme:
            return "paintpalette"
        case .plugin:
            return "puzzlepiece.extension"
        case .cheat:
            return "wand.and.stars"
        case .media:
            return "photo.on.rectangle"
        case .system:
            return "gearshape"
        case .folder:
            return "folder"
        case .file:
            return "doc"
        }
    }
}

struct PSPContentItem: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var subtitle: String
    var relativePath: String
    var sourcePath: String
    var kind: ContentKind
    var byteCount: Int64
    var fileCount: Int
    var iconPath: String?
    var sfoValues: [String: String]
    var createdAt: Date?
    var modifiedAt: Date?
    var backupCreatedAt: Date?
    var backupModifiedAt: Date?
    var backupState: BackupItemState?
    var backupTotalFileCount: Int?
    var backupChangedFileCount: Int?
    var backupMissingFileCount: Int?
    var backupUpToDateFileCount: Int?
    var childItems: [PSPContentItem]?

    var sourceURL: URL {
        URL(fileURLWithPath: sourcePath)
    }

    var iconURL: URL? {
        guard let iconPath else {
            return nil
        }

        return URL(fileURLWithPath: iconPath)
    }

    var byteCountText: String {
        ByteCountFormatter.backupString(from: byteCount)
    }

    var backupNeedsFileCount: Int {
        (backupChangedFileCount ?? 0) + (backupMissingFileCount ?? 0)
    }

    var backupTimelineText: String? {
        guard let backupState else {
            return nil
        }

        switch backupState {
        case .upToDate:
            guard let modifiedAt else {
                return "Backed up"
            }

            return "PSP and backup: \(DateFormatter.shortDateTime.string(from: modifiedAt))"
        case .missing:
            guard let modifiedAt else {
                return "Not in backup yet"
            }

            return "PSP: \(DateFormatter.shortDateTime.string(from: modifiedAt)) - not in backup yet"
        case .changed:
            let sourceText = modifiedAt.map { DateFormatter.shortDateTime.string(from: $0) } ?? "unknown"
            let backupText = backupModifiedAt.map { DateFormatter.shortDateTime.string(from: $0) } ?? "missing"
            return "PSP: \(sourceText) - Backup: \(backupText)"
        }
    }

    var backupStatusText: String {
        guard let backupState else {
            return "Checking"
        }

        switch backupState {
        case .upToDate:
            return "Up to date"
        case .missing:
            return "New"
        case .changed:
            return "Needs backup"
        }
    }

    var children: [PSPContentItem] {
        childItems ?? []
    }
}

enum BackupItemState: String, Codable, Equatable {
    case upToDate
    case missing
    case changed
}

struct StorageUsage: Codable, Equatable {
    var usedBytes: Int64
    var totalBytes: Int64
    var freeBytes: Int64

    var usedText: String {
        ByteCountFormatter.backupString(from: usedBytes)
    }

    var totalText: String {
        ByteCountFormatter.backupString(from: totalBytes)
    }

    var counterText: String {
        "\(usedText) / \(totalText)"
    }

    var percentUsed: Double {
        guard totalBytes > 0 else {
            return 0
        }

        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    static func read(from volumeRoot: URL) -> StorageUsage? {
        guard let values = try? volumeRoot.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacity,
              total > 0 else {
            return nil
        }

        let used = max(total - free, 0)
        return StorageUsage(usedBytes: Int64(used), totalBytes: Int64(total), freeBytes: Int64(free))
    }
}

struct BackupAnalysis {
    var totalFiles: Int
    var upToDateFiles: Int
    var missingFiles: Int
    var changedFiles: Int
    var staleFiles: Int
    var totalBytes: Int64
    var upToDateBytes: Int64
    var changedBytes: Int64
    var staleBytes: Int64
    var backupRootPath: String
    var contentRootPath: String
    var staleFileRelativePaths: [String]
    var itemComparisons: [String: BackupItemComparison]

    var filesNeedingBackup: Int {
        missingFiles + changedFiles
    }

    var filesNeedingSync: Int {
        filesNeedingBackup + staleFiles
    }

    var currentFraction: Double {
        let comparedFiles = totalFiles + staleFiles
        guard comparedFiles > 0 else {
            return 1
        }

        return min(max(Double(upToDateFiles) / Double(comparedFiles), 0), 1)
    }

    var currentPercentText: String {
        "\(Int((currentFraction * 100).rounded()))%"
    }

    var needsBackupText: String {
        filesNeedingSync == 0 ? "0" : "\(filesNeedingSync)"
    }

    var summaryText: String {
        if totalFiles == 0, staleFiles == 0 {
            return "No files to compare"
        }

        if filesNeedingSync == 0 {
            return "\(currentPercentText) backed up - \(totalFiles) files current"
        }

        var parts: [String] = []
        if filesNeedingBackup > 0 {
            parts.append("\(filesNeedingBackup) files need backup")
        }

        if staleFiles > 0 {
            parts.append("\(staleFiles) stale files to remove")
        }

        return "\(currentPercentText) synced - \(parts.joined(separator: ", "))"
    }
}

struct BackupItemComparison {
    var itemID: String
    var state: BackupItemState
    var totalFiles: Int
    var upToDateFiles: Int
    var missingFiles: Int
    var changedFiles: Int
    var sourceModifiedAt: Date?
    var backupCreatedAt: Date?
    var backupModifiedAt: Date?
}

struct BackupManifestEntry: Codable {
    var title: String
    var relativePath: String
    var kind: ContentKind
    var fileCount: Int
    var byteCount: Int64
}

struct BackupRequest {
    var volume: PSPVolume
    var profile: PSPDeviceProfile
    var mode: BackupMode
    var selectedItems: [PSPContentItem]
    var destinationURL: URL
}

struct BackupResult {
    var backupURL: URL
    var logURL: URL
    var fileCount: Int
    var byteCount: Int64
    var totalFileCount: Int = 0
    var totalByteCount: Int64 = 0
    var skippedFileCount: Int = 0
    var deletedFileCount: Int = 0
    var changedFileRelativePaths: [String] = []
    var deletedFileRelativePaths: [String] = []
}

struct BackupProgress {
    var title: String
    var message: String
    var fraction: Double

    var summary: String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

struct AlertInfo: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

enum PSPBackupError: LocalizedError {
    case noPSPFolder(URL)
    case notExternalVolume(URL)
    case markerWriteFailed(URL)
    case invalidBackupFolder(URL)
    case destinationInsideSource
    case sourceInsideDestination
    case noProfileForDevice
    case nothingSelected
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noPSPFolder(let url):
            return "The folder at \(url.path) does not contain a PSP folder."
        case .notExternalVolume(let url):
            return "Can't set an internal folder as a PSP. Choose a mounted external PSP Memory Stick or USB/card reader volume instead of \(url.path)."
        case .markerWriteFailed(let url):
            return "The device marker could not be written to \(url.path)."
        case .invalidBackupFolder(let url):
            return "The folder at \(url.path) does not look like a PSP backup."
        case .destinationInsideSource:
            return "The backup destination cannot be inside the PSP memory stick."
        case .sourceInsideDestination:
            return "The PSP source cannot be inside the backup destination."
        case .noProfileForDevice:
            return "Set up this PSP before backing it up."
        case .nothingSelected:
            return "Select at least one item to back up."
        case .cancelled:
            return "The backup was cancelled."
        }
    }
}

final class BackupCancellation {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func check() throws {
        lock.lock()
        let shouldCancel = cancelled
        lock.unlock()

        if shouldCancel {
            throw PSPBackupError.cancelled
        }
    }
}

enum DeviceStore {
    static func load() -> [PSPDeviceProfile] {
        guard let data = try? Data(contentsOf: storeURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PSPDeviceProfile].self, from: data)) ?? []
    }

    static func save(_ profiles: [PSPDeviceProfile]) {
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(profiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("Could not save PSP device store: \(error.localizedDescription)")
        }
    }

    static func reset() {
        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(at: storeURL)
            }
        } catch {
            NSLog("Could not reset PSP device store: \(error.localizedDescription)")
        }
    }

    private static let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("PSP Easy Backup", isDirectory: true)
            .appendingPathComponent("LinkedPSPDevices.json")
    }()
}

enum BookmarkStore {
    static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ bookmark: Data?) -> URL? {
        guard let bookmark else {
            return nil
        }

        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return url
        } catch {
            return nil
        }
    }
}

enum AppSettingsStore {
    static func load() -> AppBackupSettings? {
        guard let data = try? Data(contentsOf: storeURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppBackupSettings.self, from: data)
    }

    static func save(_ settings: AppBackupSettings) {
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("Could not save PSP Easy Backup settings: \(error.localizedDescription)")
        }
    }

    static func reset() {
        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(at: storeURL)
            }
        } catch {
            NSLog("Could not reset PSP Easy Backup settings: \(error.localizedDescription)")
        }
    }

    private static let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("PSP Easy Backup", isDirectory: true)
            .appendingPathComponent("AppSettings.json")
    }()
}

enum PSPDetector {
    static let markerFileName = ".psp-easy-backup-device.json"

    static func discoverVolumes() -> [PSPVolume] {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let mountedVolumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey, .isDirectoryKey],
            options: [.skipHiddenVolumes]
        ) {
            candidates.append(contentsOf: mountedVolumes)
        }

        if let localPaths = NSWorkspace.shared.mountedLocalVolumePaths() as? [String] {
            candidates.append(contentsOf: localPaths.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            })
        }

        if let removablePaths = NSWorkspace.shared.mountedRemovableMedia() as? [String] {
            candidates.append(contentsOf: removablePaths.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            })
        }

        if let volumesChildren = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes", isDirectory: true),
            includingPropertiesForKeys: [.isDirectoryKey, .volumeIsRemovableKey],
            options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf: volumesChildren)
        }

        var seenPaths = Set<String>()

        return candidates
            .map(\.standardizedFileURL)
            .filter { seenPaths.insert($0.path).inserted }
            .compactMap { try? volume(from: $0) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    static func volume(from selectedURL: URL) throws -> PSPVolume {
        let fileManager = FileManager.default
        let selectedURL = selectedURL.standardizedFileURL
        let rootURL: URL
        let pspDirectoryURL: URL

        if let pspDirectory = fileManager.directChildDirectory(in: selectedURL, named: "PSP")
            ?? fileManager.childDirectory(in: selectedURL, named: "PSP") {
            rootURL = selectedURL
            pspDirectoryURL = pspDirectory
        } else if selectedURL.lastPathComponent.caseInsensitiveCompare("PSP") == .orderedSame,
                  fileManager.isDirectory(selectedURL) {
            rootURL = selectedURL.deletingLastPathComponent()
            pspDirectoryURL = selectedURL
        } else {
            throw PSPBackupError.noPSPFolder(selectedURL)
        }

        return PSPVolume(
            rootURL: rootURL,
            pspDirectoryURL: pspDirectoryURL,
            marker: readMarker(at: rootURL)
        )
    }

    static func externalVolume(from selectedURL: URL) throws -> PSPVolume {
        let volume = try volume(from: selectedURL)
        guard isExternalVolume(volume.rootURL) else {
            throw PSPBackupError.notExternalVolume(volume.rootURL)
        }

        return volume
    }

    static func writeMarker(_ marker: PSPDeviceMarker, to rootURL: URL) throws {
        let markerURL = rootURL.appendingPathComponent(markerFileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(marker)
            try data.write(to: markerURL, options: .atomic)
        } catch {
            throw PSPBackupError.markerWriteFailed(markerURL)
        }
    }

    private static func readMarker(at rootURL: URL) -> PSPDeviceMarker? {
        let markerURL = rootURL.appendingPathComponent(markerFileName)

        guard let data = try? Data(contentsOf: markerURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PSPDeviceMarker.self, from: data)
    }

    private static func isExternalVolume(_ rootURL: URL) -> Bool {
        let standardizedURL = rootURL.standardizedFileURL
        guard isMountedVolumeRoot(standardizedURL) else {
            return false
        }

        let keys: Set<URLResourceKey> = [
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey
        ]
        let values = try? standardizedURL.resourceValues(forKeys: keys)
        if values?.volumeIsInternal == true {
            return false
        }

        if values?.volumeIsRemovable == true || values?.volumeIsEjectable == true {
            return true
        }

        return values?.volumeIsInternal != true
    }

    private static func isMountedVolumeRoot(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path

        if let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) {
            let mountedPaths = Set(mountedVolumes.map { $0.standardizedFileURL.path })
            if mountedPaths.contains(path) {
                return true
            }
        }

        let components = url.standardizedFileURL.pathComponents
        return components.count == 3 && components[0] == "/" && components[1] == "Volumes"
    }
}

enum PSPContentScanner {
    static func scan(volume: PSPVolume) -> [PSPContentItem] {
        let root = volume.rootURL.standardizedFileURL
        var items: [PSPContentItem] = []

        items.append(contentsOf: scanSavedata(root: root))
        items.append(contentsOf: scanGameFolders(root: root))
        items.append(contentsOf: scanISOFiles(root: root))
        items.append(contentsOf: scanThemeFiles(root: root))
        items.append(contentsOf: scanKnownDirectories(root: root))
        items.append(contentsOf: scanRootLooseFiles(root: root))

        return items
            .filter { $0.fileCount > 0 || FileManager.default.fileExists(atPath: $0.sourcePath) }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.sortOrder < rhs.kind.sortOrder
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private static func scanSavedata(root: URL) -> [PSPContentItem] {
        guard let saveRoot = existingDirectory(root: root, path: "PSP/SAVEDATA") else {
            return []
        }

        guard let children = directoryChildren(saveRoot) else {
            return []
        }

        return children.compactMap { folder in
            guard FileManager.default.isDirectory(folder) else {
                return nil
            }

            let sfoURL = folder.appendingPathComponent("PARAM.SFO")
            let sfo = SFOParser.read(url: sfoURL)
            let title = SFOParser.bestTitle(from: sfo) ?? folder.lastPathComponent
            let detail = SFOParser.bestDetail(from: sfo)
            let iconURL = folder.appendingPathComponent("ICON0.PNG")
            let lowerIconURL = folder.appendingPathComponent("ICON0.png")
            let foundIconURL = FileManager.default.fileExists(atPath: iconURL.path) ? iconURL : (FileManager.default.fileExists(atPath: lowerIconURL.path) ? lowerIconURL : nil)
            let stats = FileStats.scan(folder)

            return makeItem(
                root: root,
                sourceURL: folder,
                title: title,
                subtitle: [folder.lastPathComponent, detail].compactMap(\.self).joined(separator: " - "),
                kind: .save,
                stats: stats,
                iconURL: foundIconURL,
                sfoValues: sfo
            )
        }
    }

    private static func scanGameFolders(root: URL) -> [PSPContentItem] {
        guard let gameRoot = existingDirectory(root: root, path: "PSP/GAME") else {
            return []
        }

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: gameRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        )

        var folders: [URL] = []

        while let item = enumerator?.nextObject() as? URL {
            let folder = item.standardizedFileURL

            guard fileManager.isDirectory(folder),
                  fileManager.fileExists(atPath: folder.appendingPathComponent("EBOOT.PBP").path)
                    || fileManager.fileExists(atPath: folder.appendingPathComponent("PARAM.SFO").path) else {
                continue
            }

            folders.append(folder)
            enumerator?.skipDescendants()
        }

        return folders.compactMap { folder in
            let pbp = PBPParser.resources(for: folder.appendingPathComponent("EBOOT.PBP"))
            let localSFO = SFOParser.read(url: folder.appendingPathComponent("PARAM.SFO"))
            let sfo = localSFO.merging(pbp.sfoValues) { local, _ in local }
            let title = SFOParser.bestTitle(from: sfo) ?? folder.lastPathComponent
            let foundIconURL = firstExistingFile(
                in: folder,
                names: ["ICON0.PNG", "ICON0.png", "ICON.PNG", "ICON.png"]
            ) ?? pbp.iconURL
            let category = gameCategory(for: folder, gameRoot: gameRoot)

            return makeItem(
                root: root,
                sourceURL: folder,
                title: title,
                subtitle: [category, folder.lastPathComponent].compactMap(\.self).joined(separator: " - "),
                kind: .game,
                stats: FileStats.scan(folder),
                iconURL: foundIconURL,
                sfoValues: sfo
            )
        }
    }

    private static func scanISOFiles(root: URL) -> [PSPContentItem] {
        guard let isoRoot = existingDirectory(root: root, path: "ISO") else {
            return []
        }

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: isoRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        )

        var files: [URL] = []

        while let item = enumerator?.nextObject() as? URL {
            let file = item.standardizedFileURL
            let ext = file.pathExtension.lowercased()
            guard ext == "iso" || ext == "cso" || ext == "dax" else {
                continue
            }

            files.append(file)
        }

        return files.compactMap { file in
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else {
                return nil
            }

            let isoMetadata = file.pathExtension.caseInsensitiveCompare("iso") == .orderedSame
                ? ISOImageReader.metadata(for: file)
                : ISOGameMetadata(sfoValues: [:], iconURL: nil)
            let title = SFOParser.bestTitle(from: isoMetadata.sfoValues)
                ?? file.deletingPathExtension().lastPathComponent
            let category = gameCategory(for: file.deletingLastPathComponent(), gameRoot: isoRoot)

            return makeItem(
                root: root,
                sourceURL: file,
                title: title,
                subtitle: [category, file.lastPathComponent].compactMap(\.self).joined(separator: " - "),
                kind: .iso,
                stats: FileStats(fileCount: 1, byteCount: Int64(values.fileSize ?? 0)),
                iconURL: isoMetadata.iconURL,
                sfoValues: isoMetadata.sfoValues
            )
        }
    }

    private static func scanThemeFiles(root: URL) -> [PSPContentItem] {
        guard let themeRoot = existingDirectory(root: root, path: "PSP/THEME") else {
            return []
        }

        let stats = FileStats.scan(themeRoot)
        guard stats.fileCount > 0 else {
            return []
        }

        guard let item = makeItem(
            root: root,
            sourceURL: themeRoot,
            title: "Themes",
            subtitle: "\(stats.fileCount) files",
            kind: .theme,
            stats: stats,
            iconURL: nil,
            sfoValues: [:],
            childItems: scanChildItems(root: root, container: themeRoot, kind: .theme)
        ) else {
            return []
        }

        return [item]
    }

    private static func scanKnownDirectories(root: URL) -> [PSPContentItem] {
        let known: [(path: String, title: String, kind: ContentKind)] = [
            ("SEPLUGINS", "Plugins", .plugin),
            ("seplugins", "Plugins", .plugin),
            ("plugins", "Plugins", .plugin),
            ("cheats", "Cheats", .cheat),
            ("PSP/CHEATS", "PSP Cheats", .cheat),
            ("PSP/SYSTEM", "System Data", .system),
            ("PSP/COMMON", "Common Data", .system),
            ("PSP/RSSCH", "RSS Channels", .system),
            ("MUSIC", "Music", .media),
            ("PSP/MUSIC", "PSP Music", .media),
            ("PICTURE", "Pictures", .media),
            ("PSP/PHOTO", "PSP Photos", .media),
            ("VIDEO", "Videos", .media),
            ("MP_ROOT", "MP_ROOT Videos", .media)
        ]

        var seen = Set<String>()

        return known.compactMap { entry in
            guard let url = existingDirectory(root: root, path: entry.path) else {
                return nil
            }

            let seenKey = url.standardizedFileURL.path.lowercased()
            guard !seen.contains(seenKey) else {
                return nil
            }

            seen.insert(seenKey)
            let stats = FileStats.scan(url)
            guard stats.fileCount > 0 else {
                return nil
            }

            return makeItem(
                root: root,
                sourceURL: url,
                title: entry.title,
                subtitle: "\(url.relativePath(from: root) ?? entry.path) - \(stats.fileCount) files",
                kind: entry.kind,
                stats: stats,
                iconURL: nil,
                sfoValues: [:],
                childItems: scanChildItems(root: root, container: url, kind: entry.kind)
            )
        }
    }

    private static func scanRootLooseFiles(root: URL) -> [PSPContentItem] {
        guard let children = directoryChildren(root) else {
            return []
        }

        let ignored = Set(["PSP", "ISO", "MUSIC", "PICTURE", "VIDEO", "MP_ROOT", "SEPLUGINS", "seplugins", "plugins", "cheats"])

        return children.compactMap { file in
            guard !ignored.contains(where: { file.lastPathComponent.caseInsensitiveCompare($0) == .orderedSame }),
                  !file.lastPathComponent.hasPrefix("."),
                  let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                return nil
            }

            return makeItem(
                root: root,
                sourceURL: file,
                title: file.lastPathComponent,
                subtitle: "Memory Stick root",
                kind: .file,
                stats: FileStats(fileCount: 1, byteCount: Int64(values.fileSize ?? 0)),
                iconURL: nil,
                sfoValues: [:]
            )
        }
    }

    private static func makeItem(
        root: URL,
        sourceURL: URL,
        title: String,
        subtitle: String,
        kind: ContentKind,
        stats: FileStats,
        iconURL: URL?,
        sfoValues: [String: String],
        childItems: [PSPContentItem]? = nil
    ) -> PSPContentItem? {
        guard let relativePath = sourceURL.relativePath(from: root) else {
            return nil
        }

        let values = try? sourceURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])

        let cachedIconURL = cachedIconURL(for: iconURL, sourceURL: sourceURL, kind: kind)

        return PSPContentItem(
            id: sourceURL.standardizedFileURL.path,
            title: title,
            subtitle: subtitle,
            relativePath: relativePath,
            sourcePath: sourceURL.standardizedFileURL.path,
            kind: kind,
            byteCount: stats.byteCount,
            fileCount: stats.fileCount,
            iconPath: cachedIconURL?.path,
            sfoValues: sfoValues,
            createdAt: values?.creationDate,
            modifiedAt: values?.contentModificationDate,
            childItems: childItems?.isEmpty == true ? nil : childItems
        )
    }

    private static func cachedIconURL(for iconURL: URL?, sourceURL: URL, kind: ContentKind) -> URL? {
        guard let iconURL else {
            return nil
        }

        guard let data = try? Data(contentsOf: iconURL), data.isPNG else {
            return iconURL
        }

        return IconCache.writePNG(data, sourceURL: sourceURL, label: "\(kind.rawValue)-icon") ?? iconURL
    }

    private static func scanChildItems(root: URL, container: URL, kind: ContentKind) -> [PSPContentItem] {
        guard let children = directoryChildren(container) else {
            return []
        }

        return children
            .sorted { lhs, rhs in
                let lhsIsDirectory = FileManager.default.isDirectory(lhs)
                let rhsIsDirectory = FileManager.default.isDirectory(rhs)
                if lhsIsDirectory != rhsIsDirectory {
                    return lhsIsDirectory
                }

                return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }
            .compactMap { child in
                let child = child.standardizedFileURL
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
                guard values?.isSymbolicLink != true else {
                    return nil
                }

                if values?.isDirectory == true {
                    let childStats = FileStats.scan(child)
                    guard childStats.fileCount > 0 else {
                        return nil
                    }

                    return makeItem(
                        root: root,
                        sourceURL: child,
                        title: child.lastPathComponent,
                        subtitle: "\(child.relativePath(from: root) ?? child.lastPathComponent) - \(childStats.fileCount) files",
                        kind: .folder,
                        stats: childStats,
                        iconURL: nil,
                        sfoValues: [:],
                        childItems: scanChildItems(root: root, container: child, kind: kind)
                    )
                }

                guard values?.isRegularFile == true,
                      !BackupEngine.shouldSkipFile(named: child.lastPathComponent) else {
                    return nil
                }

                return makeFileChild(root: root, file: child, kind: kind)
            }
    }

    private static func makeFileChild(root: URL, file: URL, kind: ContentKind) -> PSPContentItem? {
        guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true else {
            return nil
        }

        let parentPath = file.deletingLastPathComponent().relativePath(from: root) ?? "Memory Stick"
        return makeItem(
            root: root,
            sourceURL: file,
            title: file.lastPathComponent,
            subtitle: parentPath,
            kind: kind,
            stats: FileStats(fileCount: 1, byteCount: Int64(values.fileSize ?? 0)),
            iconURL: nil,
            sfoValues: [:]
        )
    }

    private static func directoryChildren(_ url: URL) -> [URL]? {
        try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
    }

    private static func existingDirectory(root: URL, path: String) -> URL? {
        let fileManager = FileManager.default
        var current = root.standardizedFileURL

        for component in path.split(separator: "/").map(String.init) {
            guard let next = fileManager.directChildDirectory(in: current, named: component)
                    ?? fileManager.childDirectory(in: current, named: component) else {
                return nil
            }

            current = next.standardizedFileURL
        }

        return current
    }

    private static func firstExistingFile(in folder: URL, names: [String]) -> URL? {
        let fileManager = FileManager.default

        for name in names {
            let candidate = folder.appendingPathComponent(name)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return children.first { child in
            names.contains { child.lastPathComponent.caseInsensitiveCompare($0) == .orderedSame }
        }
    }

    private static func listFiles(in folder: URL, matching predicate: (URL) -> Bool) -> [URL] {
        guard let children = directoryChildren(folder) else {
            return []
        }

        return children.filter { file in
            predicate(file) && ((try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
        }
    }

    private static func gameCategory(for folder: URL, gameRoot: URL) -> String? {
        guard let relativePath = folder.relativePath(from: gameRoot) else {
            return nil
        }

        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count > 1, let first = components.first, first.uppercased().hasPrefix("CAT_") else {
            return nil
        }

        return first.cleanedCategoryName
    }
}

enum SFOParser {
    static func read(url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url), data.count >= 20 else {
            return [:]
        }

        return read(data: data)
    }

    static func read(data: Data) -> [String: String] {
        guard data.count >= 20 else {
            return [:]
        }

        let magic = data.subdata(in: 0..<4)
        let validMagic = magic == Data([0x00, 0x50, 0x53, 0x46]) || magic == Data([0x50, 0x53, 0x46, 0x00])

        guard validMagic else {
            return [:]
        }

        let keyTableOffset = Int(data.uint32LE(at: 8))
        let dataTableOffset = Int(data.uint32LE(at: 12))
        let count = Int(data.uint32LE(at: 16))
        guard count >= 0, count < 1000 else {
            return [:]
        }

        var values: [String: String] = [:]

        for index in 0..<count {
            let entryOffset = 20 + index * 16
            guard entryOffset + 16 <= data.count else {
                break
            }

            let keyOffset = Int(data.uint16LE(at: entryOffset))
            let format = data.uint16LE(at: entryOffset + 2)
            let length = Int(data.uint32LE(at: entryOffset + 4))
            let dataOffset = Int(data.uint32LE(at: entryOffset + 12))
            let keyStart = keyTableOffset + keyOffset
            let valueStart = dataTableOffset + dataOffset

            guard keyStart >= 0, keyStart < data.count,
                  valueStart >= 0, valueStart < data.count,
                  length > 0 else {
                continue
            }

            let keyEnd = data.firstZeroByteIndex(from: keyStart) ?? data.count
            guard keyEnd > keyStart else {
                continue
            }

            let valueEnd = min(valueStart + length, data.count)
            let keyData = data.subdata(in: keyStart..<keyEnd)
            let valueData = data.subdata(in: valueStart..<valueEnd)
            guard let key = String(data: keyData, encoding: .ascii), !key.isEmpty else {
                continue
            }

            if format == 0x0004 || format == 0x0204 || format == 0x0404 {
                let trimmed = valueData.trimmedNullTerminatedString()
                if !trimmed.isEmpty {
                    values[key] = trimmed
                }
            }
        }

        return values
    }

    static func bestTitle(from values: [String: String]) -> String? {
        let keys = ["TITLE", "TITLE_00", "SAVEDATA_TITLE", "SUB_TITLE", "DISC_ID"]
        return keys.compactMap { values[$0]?.nilIfEmpty }.first
    }

    static func bestDetail(from values: [String: String]) -> String? {
        let keys = ["DETAIL", "SAVEDATA_DETAIL", "PARENTAL_LEVEL", "CATEGORY"]
        return keys.compactMap { values[$0]?.nilIfEmpty }.first
    }
}

struct PBPResources {
    var sfoValues: [String: String]
    var iconURL: URL?
}

enum PBPParser {
    static func resources(for url: URL) -> PBPResources {
        guard FileManager.default.fileExists(atPath: url.path),
              let handle = try? FileHandle(forReadingFrom: url) else {
            return PBPResources(sfoValues: [:], iconURL: nil)
        }

        defer {
            try? handle.close()
        }

        do {
            let fileSize = try handle.seekToEnd()
            try handle.seek(toOffset: 0)
            guard let header = try handle.read(upToCount: 40),
                  header.count >= 40,
                  header.subdata(in: 0..<4) == Data([0x00, 0x50, 0x42, 0x50]) else {
                return PBPResources(sfoValues: [:], iconURL: nil)
            }

            let offsets = (0..<8).map { UInt64(header.uint32LE(at: 8 + ($0 * 4))) }
            guard offsets.allSatisfy({ $0 <= fileSize }) else {
                return PBPResources(sfoValues: [:], iconURL: nil)
            }

            let sfoData = try readSection(index: 0, offsets: offsets, fileSize: fileSize, handle: handle)
            let iconData = try readSection(index: 1, offsets: offsets, fileSize: fileSize, handle: handle)
            let iconURL = iconData.isPNG ? IconCache.writePNG(iconData, sourceURL: url, label: "pbp-icon0") : nil

            return PBPResources(
                sfoValues: SFOParser.read(data: sfoData),
                iconURL: iconURL
            )
        } catch {
            return PBPResources(sfoValues: [:], iconURL: nil)
        }
    }

    private static func readSection(
        index: Int,
        offsets: [UInt64],
        fileSize: UInt64,
        handle: FileHandle
    ) throws -> Data {
        guard index < offsets.count else {
            return Data()
        }

        let start = offsets[index]
        let end = index + 1 < offsets.count ? offsets[index + 1] : fileSize
        guard end > start, end <= fileSize, end - start <= UInt64(Int.max) else {
            return Data()
        }

        try handle.seek(toOffset: start)
        return try handle.read(upToCount: Int(end - start)) ?? Data()
    }
}

struct ISOGameMetadata {
    var sfoValues: [String: String]
    var iconURL: URL?
}

enum ISOImageReader {
    private static let sectorSize: UInt64 = 2048

    static func metadata(for url: URL) -> ISOGameMetadata {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ISOGameMetadata(sfoValues: [:], iconURL: nil)
        }

        defer {
            try? handle.close()
        }

        do {
            guard let root = try rootRecord(handle: handle) else {
                return ISOGameMetadata(sfoValues: [:], iconURL: nil)
            }

            let sfoData = try readFile(["PSP_GAME", "PARAM.SFO"], root: root, handle: handle)
            let iconData = try readFile(["PSP_GAME", "ICON0.PNG"], root: root, handle: handle)
            let iconURL = iconData.isPNG ? IconCache.writePNG(iconData, sourceURL: url, label: "iso-icon0") : nil

            return ISOGameMetadata(
                sfoValues: SFOParser.read(data: sfoData),
                iconURL: iconURL
            )
        } catch {
            return ISOGameMetadata(sfoValues: [:], iconURL: nil)
        }
    }

    private static func rootRecord(handle: FileHandle) throws -> ISODirectoryRecord? {
        try handle.seek(toOffset: sectorSize * 16)
        guard let descriptor = try handle.read(upToCount: Int(sectorSize)),
              descriptor.count >= 190,
              descriptor[0] == 1,
              String(data: descriptor.subdata(in: 1..<6), encoding: .ascii) == "CD001" else {
            return nil
        }

        let rootLength = Int(descriptor[156])
        guard rootLength > 0, 156 + rootLength <= descriptor.count else {
            return nil
        }

        return parseRecord(descriptor.subdata(in: 156..<(156 + rootLength)))
    }

    private static func readFile(_ path: [String], root: ISODirectoryRecord, handle: FileHandle) throws -> Data {
        var current = root

        for (index, component) in path.enumerated() {
            let entries = try readDirectory(current, handle: handle)
            guard let next = entries.first(where: { $0.name.caseInsensitiveCompare(component) == .orderedSame }) else {
                return Data()
            }

            current = next

            if index == path.count - 1 {
                return next.isDirectory ? Data() : try readData(record: next, handle: handle)
            }
        }

        return Data()
    }

    private static func readDirectory(_ record: ISODirectoryRecord, handle: FileHandle) throws -> [ISODirectoryRecord] {
        guard record.isDirectory else {
            return []
        }

        let data = try readData(record: record, handle: handle)
        var records: [ISODirectoryRecord] = []
        var offset = 0

        while offset < data.count {
            let length = Int(data[offset])

            if length == 0 {
                offset = ((offset / Int(sectorSize)) + 1) * Int(sectorSize)
                continue
            }

            guard offset + length <= data.count else {
                break
            }

            if let record = parseRecord(data.subdata(in: offset..<(offset + length))),
               record.name != ".",
               record.name != ".." {
                records.append(record)
            }

            offset += length
        }

        return records
    }

    private static func readData(record: ISODirectoryRecord, handle: FileHandle) throws -> Data {
        guard UInt64(record.size) <= UInt64(Int.max) else {
            return Data()
        }

        try handle.seek(toOffset: UInt64(record.extent) * sectorSize)
        return try handle.read(upToCount: Int(record.size)) ?? Data()
    }

    private static func parseRecord(_ data: Data) -> ISODirectoryRecord? {
        guard data.count >= 34 else {
            return nil
        }

        let nameLength = Int(data[32])
        guard 33 + nameLength <= data.count else {
            return nil
        }

        let rawName = data.subdata(in: 33..<(33 + nameLength))
        let name: String

        if rawName == Data([0]) {
            name = "."
        } else if rawName == Data([1]) {
            name = ".."
        } else {
            name = (String(data: rawName, encoding: .isoLatin1) ?? "")
                .replacingOccurrences(of: ";1", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }

        return ISODirectoryRecord(
            extent: data.uint32LE(at: 2),
            size: data.uint32LE(at: 10),
            flags: data[25],
            name: name
        )
    }
}

private struct ISODirectoryRecord {
    var extent: UInt32
    var size: UInt32
    var flags: UInt8
    var name: String

    var isDirectory: Bool {
        flags & 0x02 != 0
    }
}

enum IconCache {
    static func writePNG(_ data: Data, sourceURL: URL, label: String) -> URL? {
        guard data.isPNG else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let fileName = "\(sourceURL.path.stableHash)-\(label).png"
            let url = directoryURL.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func reset() {
        do {
            if FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.removeItem(at: directoryURL)
            }
        } catch {
            NSLog("Could not reset PSP Easy Backup icon cache: \(error.localizedDescription)")
        }
    }

    private static let directoryURL: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PSP Easy Backup", isDirectory: true)
            .appendingPathComponent("IconCache", isDirectory: true)
    }()
}

struct FileStats: Equatable, Codable {
    var fileCount: Int
    var byteCount: Int64

    static func scan(_ url: URL) -> FileStats {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]

        if let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true {
            return FileStats(fileCount: 1, byteCount: Int64(values.fileSize ?? 0))
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return FileStats(fileCount: 0, byteCount: 0)
        }

        var count = 0
        var bytes: Int64 = 0

        while let item = enumerator.nextObject() as? URL {
            guard let values = try? item.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  !BackupEngine.shouldSkipFile(named: item.lastPathComponent) else {
                continue
            }

            count += 1
            bytes += Int64(values.fileSize ?? 0)
        }

        return FileStats(fileCount: count, byteCount: bytes)
    }
}

enum BackupEngine {
    static let metadataFileName = ".psp-easy-backup-summary.json"
    static let manifestFileName = "contents-manifest.json"
    private static let mirrorContentFolderName = "PSP Contents"
    private static let logFolderName = "Logs"
    private static let modificationWindow: TimeInterval = 2

    static func run(
        request: BackupRequest,
        cancellation: BackupCancellation,
        progress: @escaping (BackupProgress) -> Void
    ) throws -> BackupResult {
        let sourceAccess = request.volume.rootURL.startAccessingSecurityScopedResource()
        let destinationAccess = request.destinationURL.startAccessingSecurityScopedResource()

        defer {
            if sourceAccess {
                request.volume.rootURL.stopAccessingSecurityScopedResource()
            }
            if destinationAccess {
                request.destinationURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let sourceRoot = request.volume.rootURL.standardizedFileURL
        let destinationRoot = request.destinationURL.standardizedFileURL

        if destinationRoot.isEqualToOrInside(sourceRoot) {
            throw PSPBackupError.destinationInsideSource
        }

        if sourceRoot.isEqualToOrInside(destinationRoot) {
            throw PSPBackupError.sourceInsideDestination
        }

        try fileManager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        let backupURL = mirrorRoot(for: request, destinationRoot: destinationRoot)
        let contentRoot = mirrorContentRoot(in: backupURL)
        let logFolder = backupURL.appendingPathComponent(logFolderName, isDirectory: true)

        if backupURL.isEqualToOrInside(sourceRoot) || contentRoot.isEqualToOrInside(sourceRoot) {
            throw PSPBackupError.destinationInsideSource
        }

        if sourceRoot.isEqualToOrInside(backupURL) || sourceRoot.isEqualToOrInside(contentRoot) {
            throw PSPBackupError.sourceInsideDestination
        }

        try cancellation.check()
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: contentRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logFolder, withIntermediateDirectories: true)

        progress(BackupProgress(title: "Scanning", message: "Building backup plan for \(request.profile.name)...", fraction: 0))
        let plan = try makePlan(request: request)
        guard !plan.files.isEmpty || request.mode == .fullDisk else {
            throw PSPBackupError.nothingSelected
        }

        try cancellation.check()
        let description = "\(plan.files.count) files, \(ByteCountFormatter.backupString(from: plan.totalBytes))"
        progress(BackupProgress(title: "Preparing", message: "Preparing incremental mirror for \(description)...", fraction: 0.06))

        for directory in plan.directories.sorted() {
            let destination = contentRoot.appendingPathComponent(directory, isDirectory: true)
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        var stats = MirrorStats()
        var processedBytes: Int64 = 0
        var processedFiles = 0
        var logLines: [String] = [
            "PSP Easy Backup",
            "Started: \(DateFormatter.backupLog.string(from: Date()))",
            "Device: \(request.profile.name)",
            "Identifier: \(request.profile.id)",
            "Source: \(sourceRoot.path)",
            "Backup root: \(backupURL.path)",
            "Mirror: \(contentRoot.path)",
            "Mode: \(request.mode.title)",
            ""
        ]

        for file in plan.files {
            try cancellation.check()

            let destinationFile = contentRoot.appendingPathComponent(file.relativePath)
            try fileManager.createDirectory(at: destinationFile.deletingLastPathComponent(), withIntermediateDirectories: true)

            let decision = mirrorCopyDecision(source: file.url, destination: destinationFile, sourceByteCount: file.byteCount)

            switch decision {
            case .skip:
                stats.skippedFiles += 1
            case .create, .update:
                try copyReplacingItem(at: file.url, with: destinationFile)
                stats.copiedFiles += 1
                stats.copiedBytes += file.byteCount
                stats.copiedRelativePaths.append(file.relativePath)
                logLines.append("\(decision.logVerb) \(file.relativePath)")
            }

            processedFiles += 1
            processedBytes += file.byteCount

            let fraction: Double
            if plan.totalBytes > 0 {
                fraction = 0.08 + min(Double(processedBytes) / Double(plan.totalBytes), 1) * 0.82
            } else if !plan.files.isEmpty {
                fraction = 0.08 + min(Double(processedFiles) / Double(plan.files.count), 1) * 0.82
            } else {
                fraction = 0.9
            }

            progress(
                BackupProgress(
                    title: "Syncing",
                    message: "\(stats.copiedFiles) changed, \(stats.skippedFiles) unchanged - \(file.shortRelativePath)",
                    fraction: fraction
                )
            )
        }

        try cancellation.check()
        progress(BackupProgress(title: "Cleaning", message: "Removing files no longer on the PSP...", fraction: 0.92))
        let deletedFiles = try deleteStaleFiles(in: contentRoot, request: request, plan: plan)
        stats.deletedFiles = deletedFiles.count
        logLines.append(contentsOf: deletedFiles.map { "deleted \($0)" })

        try writeManifest(request: request, plan: plan, backupURL: backupURL, fileCount: plan.files.count, byteCount: plan.totalBytes)
        let logURL = logFolder.appendingPathComponent("Backup_\(DateFormatter.backupTimestamp.string(from: Date())).log")
        logLines.append("")
        logLines.append("Finished: \(DateFormatter.backupLog.string(from: Date()))")
        logLines.append("Changed files: \(stats.copiedFiles)")
        logLines.append("Deleted files: \(stats.deletedFiles)")
        logLines.append("Unchanged files: \(stats.skippedFiles)")
        logLines.append("Mirror files: \(plan.files.count)")
        logLines.append("Changed size: \(ByteCountFormatter.backupString(from: stats.copiedBytes))")
        logLines.append("Mirror size: \(ByteCountFormatter.backupString(from: plan.totalBytes))")
        try logLines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)

        progress(
            BackupProgress(
                title: "Complete",
                message: mirrorCompletionMessage(stats: stats, plan: plan),
                fraction: 1
            )
        )

        return BackupResult(
            backupURL: backupURL,
            logURL: logURL,
            fileCount: stats.copiedFiles,
            byteCount: stats.copiedBytes,
            totalFileCount: plan.files.count,
            totalByteCount: plan.totalBytes,
            skippedFileCount: stats.skippedFiles,
            deletedFileCount: stats.deletedFiles,
            changedFileRelativePaths: stats.copiedRelativePaths,
            deletedFileRelativePaths: deletedFiles
        )
    }

    static func importExistingBackup(
        folder: URL,
        profile: PSPDeviceProfile,
        cancellation: BackupCancellation,
        progress: @escaping (BackupProgress) -> Void
    ) throws -> BackupResult {
        let fileManager = FileManager.default
        let backupURL = folder.standardizedFileURL

        guard fileManager.isDirectory(backupURL) else {
            throw PSPBackupError.invalidBackupFolder(backupURL)
        }

        try cancellation.check()
        let roots = importContentRoots(in: backupURL)

        guard !roots.isEmpty else {
            throw PSPBackupError.invalidBackupFolder(backupURL)
        }

        progress(BackupProgress(title: "Scanning", message: "Indexing existing backup...", fraction: 0.08))

        let importSourceRoot = roots.count == 1 ? roots[0] : backupURL
        let plan = try scanRoots(roots, sourceRoot: importSourceRoot)

        guard !plan.files.isEmpty else {
            throw PSPBackupError.invalidBackupFolder(backupURL)
        }

        try cancellation.check()
        progress(
            BackupProgress(
                title: "Preparing",
                message: "Found \(plan.files.count) files, \(ByteCountFormatter.backupString(from: plan.totalBytes)).",
                fraction: 0.72
            )
        )

        try writeImportedManifest(profile: profile, plan: plan, backupURL: backupURL)

        let logURL = backupURL.appendingPathComponent("backup-import-log.txt")
        let logLines = [
            "PSP Easy Backup Import",
            "Imported: \(DateFormatter.backupLog.string(from: Date()))",
            "Device: \(profile.name)",
            "Identifier: \(profile.id)",
            "Folder: \(backupURL.path)",
            "Files: \(plan.files.count)",
            "Size: \(ByteCountFormatter.backupString(from: plan.totalBytes))"
        ]
        try logLines.joined(separator: "\n").write(to: logURL, atomically: true, encoding: .utf8)

        progress(
            BackupProgress(
                title: "Imported",
                message: "Added existing backup without copying files.",
                fraction: 1
            )
        )

        return BackupResult(backupURL: backupURL, logURL: logURL, fileCount: plan.files.count, byteCount: plan.totalBytes)
    }

    static func analyzeBackup(
        volume: PSPVolume,
        profile: PSPDeviceProfile,
        destinationURL: URL,
        items: [PSPContentItem]
    ) -> BackupAnalysis? {
        let sourceRoot = volume.rootURL.standardizedFileURL
        let destinationRoot = destinationURL.standardizedFileURL
        let request = BackupRequest(
            volume: volume,
            profile: profile,
            mode: .fullDisk,
            selectedItems: [],
            destinationURL: destinationRoot
        )
        let backupRoot = mirrorRoot(for: request, destinationRoot: destinationRoot)
        let contentRoot = mirrorContentRoot(in: backupRoot)

        guard let plan = try? scanRoots([sourceRoot], sourceRoot: sourceRoot) else {
            return nil
        }

        var analysis = BackupAnalysis(
            totalFiles: plan.files.count,
            upToDateFiles: 0,
            missingFiles: 0,
            changedFiles: 0,
            staleFiles: 0,
            totalBytes: plan.totalBytes,
            upToDateBytes: 0,
            changedBytes: 0,
            staleBytes: 0,
            backupRootPath: backupRoot.path,
            contentRootPath: contentRoot.path,
            staleFileRelativePaths: [],
            itemComparisons: [:]
        )
        let allItems = itemsIncludingChildren(items)
        var itemAggregates = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, BackupItemAggregate(item: $0)) })
        let sortedItems = allItems.enumerated().sorted { lhs, rhs in
            lhs.element.relativePath.count > rhs.element.relativePath.count
        }

        for file in plan.files {
            let destinationFile = contentRoot.appendingPathComponent(file.relativePath)
            let comparison = compareBackupFile(source: file.url, destination: destinationFile, byteCount: file.byteCount)

            switch comparison.state {
            case .upToDate:
                analysis.upToDateFiles += 1
                analysis.upToDateBytes += file.byteCount
            case .missing:
                analysis.missingFiles += 1
                analysis.changedBytes += file.byteCount
            case .changed:
                analysis.changedFiles += 1
                analysis.changedBytes += file.byteCount
            }

            for itemID in matchingItemIDs(for: file.relativePath, items: sortedItems) {
                itemAggregates[itemID]?.add(file: file, comparison: comparison)
            }
        }

        let expectedFiles = Set(plan.files.map(\.relativePath))
        let staleFiles = staleBackupFiles(
            in: contentRoot,
            expectedFiles: expectedFiles,
            roots: [contentRoot]
        )
        analysis.staleFiles = staleFiles.count
        analysis.staleBytes = staleFiles.reduce(0) { $0 + $1.byteCount }
        analysis.staleFileRelativePaths = staleFiles.map(\.relativePath)
        analysis.itemComparisons = itemAggregates.reduce(into: [:]) { result, pair in
            result[pair.key] = pair.value.comparison
        }

        return analysis
    }

    static func applyBackupAnalysis(_ analysis: BackupAnalysis?, to items: [PSPContentItem]) -> [PSPContentItem] {
        guard let analysis else {
            return items
        }

        return items.map { applyBackupAnalysis(analysis, to: $0) }
    }

    static func deviceBackupRoot(for profile: PSPDeviceProfile, destinationRoot: URL) -> URL {
        destinationRoot
            .appendingPathComponent(profile.backupFolderName, isDirectory: true)
            .standardizedFileURL
    }

    static func deviceBackupContentRoot(for profile: PSPDeviceProfile, destinationRoot: URL) -> URL {
        mirrorContentRoot(in: deviceBackupRoot(for: profile, destinationRoot: destinationRoot))
    }

    private static func mirrorRoot(for request: BackupRequest, destinationRoot: URL) -> URL {
        let fileManager = FileManager.default

        if let lastBackupPath = request.profile.lastBackupPath {
            let lastBackupURL = URL(fileURLWithPath: lastBackupPath, isDirectory: true).standardizedFileURL
            if fileManager.isDirectory(lastBackupURL), lastBackupURL.isEqualToOrInside(destinationRoot) {
                return lastBackupURL
            }
        }

        return deviceBackupRoot(for: request.profile, destinationRoot: destinationRoot)
    }

    private static func mirrorContentRoot(in backupRoot: URL) -> URL {
        let fileManager = FileManager.default

        if let contents = fileManager.directChildDirectory(in: backupRoot, named: mirrorContentFolderName)
            ?? fileManager.childDirectory(in: backupRoot, named: mirrorContentFolderName),
           looksLikePSPContentRoot(contents) {
            return contents.standardizedFileURL
        }

        if looksLikePSPContentRoot(backupRoot) {
            return backupRoot.standardizedFileURL
        }

        return backupRoot.appendingPathComponent(mirrorContentFolderName, isDirectory: true).standardizedFileURL
    }

    private static func compareBackupFile(source: URL, destination: URL, byteCount: Int64) -> BackupFileComparison {
        let state: BackupItemState

        switch mirrorCopyDecision(source: source, destination: destination, sourceByteCount: byteCount) {
        case .skip:
            state = .upToDate
        case .create:
            state = .missing
        case .update:
            state = .changed
        }

        let sourceValues = try? source.resourceValues(forKeys: [.contentModificationDateKey])
        let destinationValues = try? destination.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])

        return BackupFileComparison(
            state: state,
            sourceModifiedAt: sourceValues?.contentModificationDate,
            backupCreatedAt: destinationValues?.creationDate,
            backupModifiedAt: destinationValues?.contentModificationDate
        )
    }

    private static func itemsIncludingChildren(_ items: [PSPContentItem]) -> [PSPContentItem] {
        items.flatMap { item in
            [item] + itemsIncludingChildren(item.children)
        }
    }

    private static func applyBackupAnalysis(_ analysis: BackupAnalysis, to item: PSPContentItem) -> PSPContentItem {
        var updated = item
        if let comparison = analysis.itemComparisons[item.id] {
            updated.backupState = comparison.state
            updated.backupTotalFileCount = comparison.totalFiles
            updated.backupChangedFileCount = comparison.changedFiles
            updated.backupMissingFileCount = comparison.missingFiles
            updated.backupUpToDateFileCount = comparison.upToDateFiles
            updated.modifiedAt = comparison.sourceModifiedAt ?? item.modifiedAt
            updated.backupCreatedAt = comparison.backupCreatedAt
            updated.backupModifiedAt = comparison.backupModifiedAt
        }

        if !item.children.isEmpty {
            updated.childItems = item.children.map { applyBackupAnalysis(analysis, to: $0) }
        }

        return updated
    }

    private static func matchingItemIDs(
        for fileRelativePath: String,
        items: [(offset: Int, element: PSPContentItem)]
    ) -> [String] {
        var ids: [String] = []

        for item in items.map(\.element) {
            let itemPath = item.relativePath
            if fileRelativePath == itemPath || fileRelativePath.hasPrefix(itemPath + "/") {
                ids.append(item.id)
            }
        }

        return ids
    }

    private static func mirrorCopyDecision(source: URL, destination: URL, sourceByteCount: Int64) -> MirrorCopyDecision {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory) else {
            return .create
        }

        guard !isDirectory.boolValue,
              let destinationValues = try? destination.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
              destinationValues.isRegularFile == true else {
            return .update
        }

        if Int64(destinationValues.fileSize ?? -1) != sourceByteCount {
            return .update
        }

        guard let sourceDate = try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
              let destinationDate = destinationValues.contentModificationDate else {
            return .skip
        }

        return abs(sourceDate.timeIntervalSince(destinationDate)) <= modificationWindow ? .skip : .update
    }

    private static func copyReplacingItem(at source: URL, with destination: URL) throws {
        let fileManager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        let temporaryName = ".\(destination.lastPathComponent).psp-easy-backup-\(UUID().uuidString).tmp"
        let temporaryURL = parent.appendingPathComponent(temporaryName)

        do {
            try fileManager.copyItem(at: source, to: temporaryURL)
            preserveModificationDate(from: source, to: temporaryURL)

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            try fileManager.moveItem(at: temporaryURL, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func deleteStaleFiles(in contentRoot: URL, request: BackupRequest, plan: BackupPlan) throws -> [String] {
        let fileManager = FileManager.default
        guard fileManager.isDirectory(contentRoot) else {
            return []
        }

        let expectedFiles = Set(plan.files.map(\.relativePath))
        let roots = staleScanRoots(in: contentRoot, request: request)
        var directoriesToClean: [URL] = []
        let staleFiles = staleBackupFiles(
            in: contentRoot,
            expectedFiles: expectedFiles,
            roots: roots,
            directoriesToClean: &directoriesToClean
        )

        for file in staleFiles {
            try fileManager.removeItem(at: file.url)
        }

        for directory in directoriesToClean.sorted(by: { $0.path.count > $1.path.count }) {
            guard directory.standardizedFileURL.path != contentRoot.standardizedFileURL.path,
                  !mirrorOnlyDirectoryNames.contains(directory.lastPathComponent),
                  (try? fileManager.contentsOfDirectory(atPath: directory.path).isEmpty) == true else {
                continue
            }

            try? fileManager.removeItem(at: directory)
        }

        return staleFiles.map(\.relativePath)
    }

    private static func staleBackupFiles(
        in contentRoot: URL,
        expectedFiles: Set<String>,
        roots: [URL]
    ) -> [StaleBackupFile] {
        var directoriesToClean: [URL] = []
        return staleBackupFiles(
            in: contentRoot,
            expectedFiles: expectedFiles,
            roots: roots,
            directoriesToClean: &directoriesToClean
        )
    }

    private static func staleBackupFiles(
        in contentRoot: URL,
        expectedFiles: Set<String>,
        roots: [URL],
        directoriesToClean: inout [URL]
    ) -> [StaleBackupFile] {
        let fileManager = FileManager.default
        guard fileManager.isDirectory(contentRoot) else {
            return []
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
        var staleFiles: [StaleBackupFile] = []

        for root in roots {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: keys,
                    options: [],
                    errorHandler: { _, _ in true }
                ) else {
                    continue
                }

                while let item = enumerator.nextObject() as? URL {
                    let url = item.standardizedFileURL
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    let name = url.lastPathComponent

                    if values?.isDirectory == true {
                        if mirrorOnlyDirectoryNames.contains(name) {
                            enumerator.skipDescendants()
                            continue
                        }

                        directoriesToClean.append(url)
                        continue
                    }

                    guard values?.isRegularFile == true,
                          !shouldSkipFile(named: name),
                          let relativePath = url.relativePath(from: contentRoot),
                          !expectedFiles.contains(relativePath) else {
                        continue
                    }

                    staleFiles.append(
                        StaleBackupFile(
                            url: url,
                            relativePath: relativePath,
                            byteCount: Int64(values?.fileSize ?? 0)
                        )
                    )
                }
            } else if let values = try? root.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      let relativePath = root.relativePath(from: contentRoot),
                      !expectedFiles.contains(relativePath),
                      !shouldSkipFile(named: root.lastPathComponent) {
                staleFiles.append(
                    StaleBackupFile(
                        url: root,
                        relativePath: relativePath,
                        byteCount: Int64(values.fileSize ?? 0)
                    )
                )
            }
        }

        return staleFiles.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }

    private static func staleScanRoots(in contentRoot: URL, request: BackupRequest) -> [URL] {
        switch request.mode {
        case .fullDisk:
            return [contentRoot]
        case .selectedItems:
            return request.selectedItems.map { contentRoot.appendingPathComponent($0.relativePath) }
        }
    }

    private static func mirrorCompletionMessage(stats: MirrorStats, plan: BackupPlan) -> String {
        guard stats.copiedFiles > 0 || stats.deletedFiles > 0 else {
            return "Backup already up to date. \(plan.files.count) files checked."
        }

        var parts: [String] = []

        if stats.copiedFiles > 0 {
            parts.append("\(stats.copiedFiles) changed")
        }

        if stats.deletedFiles > 0 {
            parts.append("\(stats.deletedFiles) deleted")
        }

        parts.append("\(stats.skippedFiles) unchanged")
        return parts.joined(separator: ", ") + "."
    }

    static func shouldSkipFile(named name: String) -> Bool {
        skippedFileNames.contains(name) || name.hasPrefix("._") || name == PSPDetector.markerFileName
    }

    private static func makePlan(request: BackupRequest) throws -> BackupPlan {
        switch request.mode {
        case .fullDisk:
            return try scanRoots([request.volume.rootURL], sourceRoot: request.volume.rootURL)
        case .selectedItems:
            let roots = request.selectedItems.map(\.sourceURL)
            return try scanRoots(roots, sourceRoot: request.volume.rootURL)
        }
    }

    private static func scanRoots(_ roots: [URL], sourceRoot: URL) throws -> BackupPlan {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]
        var filesByPath: [String: BackupFile] = [:]
        var directories = Set<String>()
        var totalBytes: Int64 = 0

        for root in roots {
            let root = root.standardizedFileURL

            guard fileManager.fileExists(atPath: root.path) else {
                continue
            }

            let values = try? root.resourceValues(forKeys: Set(keys))

            if values?.isRegularFile == true, values?.isSymbolicLink != true, !shouldSkipFile(named: root.lastPathComponent), let relativePath = root.relativePath(from: sourceRoot) {
                let file = BackupFile(url: root, relativePath: relativePath, byteCount: Int64(values?.fileSize ?? 0))
                filesByPath[root.path] = file
                continue
            }

            if values?.isDirectory == true {
                if let relativePath = root.relativePath(from: sourceRoot), !relativePath.isEmpty {
                    directories.insert(relativePath)
                }

                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: keys,
                    options: [],
                    errorHandler: { _, _ in true }
                ) else {
                    continue
                }

                while let item = enumerator.nextObject() as? URL {
                    let url = item.standardizedFileURL
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    let name = url.lastPathComponent

                    if values?.isDirectory == true {
                        if prunedDirectoryNames.contains(name) {
                            enumerator.skipDescendants()
                            continue
                        }

                        if let relativePath = url.relativePath(from: sourceRoot), !relativePath.isEmpty {
                            directories.insert(relativePath)
                        }

                        continue
                    }

                    guard values?.isRegularFile == true,
                          values?.isSymbolicLink != true,
                          !shouldSkipFile(named: name),
                          let relativePath = url.relativePath(from: sourceRoot) else {
                        continue
                    }

                    filesByPath[url.path] = BackupFile(url: url, relativePath: relativePath, byteCount: Int64(values?.fileSize ?? 0))
                }
            }
        }

        let files = filesByPath.values.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
        totalBytes = files.reduce(0) { $0 + $1.byteCount }
        return BackupPlan(directories: directories, files: files, totalBytes: totalBytes)
    }

    private static func writeManifest(
        request: BackupRequest,
        plan: BackupPlan,
        backupURL: URL,
        fileCount: Int,
        byteCount: Int64
    ) throws {
        let selectedEntries: [BackupManifestEntry] = request.selectedItems.map {
            BackupManifestEntry(title: $0.title, relativePath: $0.relativePath, kind: $0.kind, fileCount: $0.fileCount, byteCount: $0.byteCount)
        }

        let metadata = BackupMetadata(
            createdAt: Date(),
            deviceIdentifier: request.profile.id,
            deviceName: request.profile.name,
            sourcePath: request.volume.rootURL.path,
            mode: request.mode,
            fileCount: fileCount,
            byteCount: byteCount,
            selectedItems: selectedEntries,
            copiedFileRelativePaths: plan.files.map(\.relativePath)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try data.write(to: backupURL.appendingPathComponent(metadataFileName), options: .atomic)

        let manifest = plan.files.map(\.relativePath).joined(separator: "\n")
        try manifest.write(to: backupURL.appendingPathComponent(manifestFileName), atomically: true, encoding: .utf8)
    }

    private static func writeImportedManifest(
        profile: PSPDeviceProfile,
        plan: BackupPlan,
        backupURL: URL
    ) throws {
        let selectedEntries = [
            BackupManifestEntry(
                title: "Imported backup",
                relativePath: "",
                kind: .folder,
                fileCount: plan.files.count,
                byteCount: plan.totalBytes
            )
        ]

        let metadata = BackupMetadata(
            createdAt: Date(),
            deviceIdentifier: profile.id,
            deviceName: profile.name,
            sourcePath: backupURL.path,
            mode: .fullDisk,
            fileCount: plan.files.count,
            byteCount: plan.totalBytes,
            selectedItems: selectedEntries,
            copiedFileRelativePaths: plan.files.map(\.relativePath)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metadata)
        try data.write(to: backupURL.appendingPathComponent(metadataFileName), options: .atomic)

        let manifest = plan.files.map(\.relativePath).joined(separator: "\n")
        try manifest.write(to: backupURL.appendingPathComponent(manifestFileName), atomically: true, encoding: .utf8)
    }

    private static func importContentRoots(in backupURL: URL) -> [URL] {
        let fileManager = FileManager.default

        if let legacyContent = fileManager.directChildDirectory(in: backupURL, named: "PSP Contents")
            ?? fileManager.childDirectory(in: backupURL, named: "PSP Contents"),
           looksLikePSPContentRoot(legacyContent) {
            return [legacyContent]
        }

        if looksLikePSPContentRoot(backupURL) {
            return [backupURL]
        }

        return []
    }

    private static func looksLikePSPContentRoot(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        let knownDirectories = [
            "PSP",
            "ISO",
            "MUSIC",
            "PICTURE",
            "VIDEO",
            "MP_ROOT",
            "SEPLUGINS",
            "seplugins",
            "plugins"
        ]

        return knownDirectories.contains { name in
            fileManager.directChildDirectory(in: url, named: name) != nil
                || fileManager.childDirectory(in: url, named: name) != nil
        }
    }

    private static func makeUniqueBackupDirectory(in destinationRoot: URL) throws -> URL {
        let timestamp = DateFormatter.backupTimestamp.string(from: Date())
        var candidate = destinationRoot.appendingPathComponent(timestamp, isDirectory: true)
        var number = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = destinationRoot.appendingPathComponent("\(timestamp)-\(number)", isDirectory: true)
            number += 1
        }

        return candidate
    }

    private static func preserveModificationDate(from source: URL, to destination: URL) {
        guard let modificationDate = try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return
        }

        try? FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: destination.path)
    }

    private static let prunedDirectoryNames: Set<String> = [
        ".Spotlight-V100",
        ".Trashes",
        ".fseventsd",
        ".TemporaryItems",
        ".DocumentRevisions-V100",
        "System Volume Information",
        "$RECYCLE.BIN",
        "lost+found"
    ]

    private static let mirrorOnlyDirectoryNames: Set<String> = [
        logFolderName
    ]

    private static let skippedFileNames: Set<String> = [
        ".DS_Store",
        ".apdisk",
        ".VolumeIcon.icns",
        ".metadata_never_index",
        ".metadata_never_index_unless_rootfs",
        ".com.apple.timemachine.donotpresent",
        ".psp-easy-backup-summary.json",
        "contents-manifest.json",
        "backup-import-log.txt",
        "backup-log.txt",
        "Thumbs.db",
        "desktop.ini"
    ]
}

struct BackupMetadata: Codable {
    var createdAt: Date
    var deviceIdentifier: String
    var deviceName: String
    var sourcePath: String
    var mode: BackupMode
    var fileCount: Int
    var byteCount: Int64
    var selectedItems: [BackupManifestEntry]
    var copiedFileRelativePaths: [String]
}

private struct BackupPlan {
    var directories: Set<String>
    var files: [BackupFile]
    var totalBytes: Int64
}

private struct MirrorStats {
    var copiedFiles = 0
    var copiedBytes: Int64 = 0
    var skippedFiles = 0
    var deletedFiles = 0
    var copiedRelativePaths: [String] = []
}

private struct BackupFileComparison {
    var state: BackupItemState
    var sourceModifiedAt: Date?
    var backupCreatedAt: Date?
    var backupModifiedAt: Date?
}

private struct StaleBackupFile {
    var url: URL
    var relativePath: String
    var byteCount: Int64
}

private struct BackupItemAggregate {
    var item: PSPContentItem
    var totalFiles = 0
    var upToDateFiles = 0
    var missingFiles = 0
    var changedFiles = 0
    var sourceModifiedAt: Date?
    var backupCreatedAt: Date?
    var backupModifiedAt: Date?

    mutating func add(file: BackupFile, comparison: BackupFileComparison) {
        totalFiles += 1

        switch comparison.state {
        case .upToDate:
            upToDateFiles += 1
        case .missing:
            missingFiles += 1
        case .changed:
            changedFiles += 1
        }

        sourceModifiedAt = latest(sourceModifiedAt, comparison.sourceModifiedAt)
        backupModifiedAt = latest(backupModifiedAt, comparison.backupModifiedAt)
        backupCreatedAt = earliest(backupCreatedAt, comparison.backupCreatedAt)
    }

    var comparison: BackupItemComparison {
        let state: BackupItemState

        if totalFiles == 0 {
            state = .missing
        } else if missingFiles > 0 {
            state = missingFiles == totalFiles ? .missing : .changed
        } else if changedFiles > 0 {
            state = .changed
        } else {
            state = .upToDate
        }

        return BackupItemComparison(
            itemID: item.id,
            state: state,
            totalFiles: totalFiles,
            upToDateFiles: upToDateFiles,
            missingFiles: missingFiles,
            changedFiles: changedFiles,
            sourceModifiedAt: sourceModifiedAt ?? item.modifiedAt,
            backupCreatedAt: backupCreatedAt,
            backupModifiedAt: backupModifiedAt
        )
    }

    private func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        guard let lhs else {
            return rhs
        }

        guard let rhs else {
            return lhs
        }

        return max(lhs, rhs)
    }

    private func earliest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        guard let lhs else {
            return rhs
        }

        guard let rhs else {
            return lhs
        }

        return min(lhs, rhs)
    }
}

private enum MirrorCopyDecision {
    case create
    case update
    case skip

    var logVerb: String {
        switch self {
        case .create:
            return "created"
        case .update:
            return "updated"
        case .skip:
            return "unchanged"
        }
    }
}

private struct BackupFile {
    var url: URL
    var relativePath: String
    var byteCount: Int64

    var shortRelativePath: String {
        guard relativePath.count > 74 else {
            return relativePath
        }

        return "...\(relativePath.suffix(71))"
    }
}

extension FileManager {
    func directChildDirectory(in parent: URL, named name: String) -> URL? {
        let candidate = parent.appendingPathComponent(name, isDirectory: true).standardizedFileURL
        return isDirectory(candidate) ? candidate : nil
    }

    func childDirectory(in parent: URL, named name: String) -> URL? {
        guard let children = try? contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return nil
        }

        return children.first {
            $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame && isDirectory($0)
        }
    }

    func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

extension URL {
    func relativePath(from root: URL) -> String? {
        let rootPath = root.standardizedFileURL.path
        let path = standardizedFileURL.path

        guard path != rootPath else {
            return ""
        }

        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        guard path.hasPrefix(prefix) else {
            return nil
        }

        return String(path.dropFirst(prefix.count))
    }

    func isEqualToOrInside(_ parent: URL) -> Bool {
        let parentPath = parent.standardizedFileURL.path
        let path = standardizedFileURL.path

        if path == parentPath {
            return true
        }

        let prefix = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        return path.hasPrefix(prefix)
    }
}

extension ByteCountFormatter {
    static func backupString(from bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

extension DateFormatter {
    static let backupTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    static let backupLog: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

extension RelativeDateTimeFormatter {
    static let pspRelative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

extension ContentKind {
    var sortOrder: Int {
        switch self {
        case .save:
            return 0
        case .game:
            return 1
        case .iso:
            return 2
        case .theme:
            return 3
        case .plugin:
            return 4
        case .cheat:
            return 5
        case .media:
            return 6
        case .system:
            return 7
        case .folder:
            return 8
        case .file:
            return 9
        }
    }
}

private extension Data {
    var isPNG: Bool {
        count >= 8 && subdata(in: 0..<8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    func uint16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else {
            return 0
        }

        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else {
            return 0
        }

        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func firstZeroByteIndex(from offset: Int) -> Int? {
        guard offset < count else {
            return nil
        }

        for index in offset..<count where self[index] == 0 {
            return index
        }

        return nil
    }

    func trimmedNullTerminatedString() -> String {
        let end = firstIndex(of: 0) ?? endIndex
        let value = subdata(in: startIndex..<end)
        let encodings: [String.Encoding] = [.utf8, .shiftJIS, .ascii]

        for encoding in encodings {
            if let string = String(data: value, encoding: encoding) {
                return string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ""
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var cleanedCategoryName: String {
        let withoutPrefix: String

        if uppercased().hasPrefix("CAT_") {
            withoutPrefix = String(dropFirst(4))
        } else {
            withoutPrefix = self
        }

        let trimmedNumber = withoutPrefix.drop { $0.isNumber }
        let cleaned = String(trimmedNumber).trimmingCharacters(in: CharacterSet(charactersIn: "_- "))
        return cleaned.isEmpty ? self : cleaned
    }

    var stableHash: String {
        var hash: UInt64 = 14695981039346656037

        for byte in utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }

        return String(format: "%016llx", hash)
    }

    var safePathComponent: String {
        let invalid = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let parts = components(separatedBy: invalid).filter { !$0.isEmpty }
        let joined = parts.joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "PSP" : joined
    }
}
