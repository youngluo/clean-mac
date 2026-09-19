import XCTest
@testable import Spotless

private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CleanupEvent] = []

    func append(_ event: CleanupEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    var events: [CleanupEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

final class CleanupServiceTests: XCTestCase {
    private var fixtureRoot: URL!
    private var defaults: UserDefaults!
    private var defaultsName = ""
    private var service: CleanerService!

    private let testLocale = Locale(identifier: "en")

    private func rendered(_ message: LocalizedMessage) -> String {
        message.resolve(in: testLocale)
    }

    override func setUpWithError() throws {
        // fixture 不能放在 /var/folders（受保护前缀）或 ~/Library（触发 Library/Caches
        // 组件级排除）下，否则扫描与 execute 安全校验都会拒绝 fixture 内的候选
        fixtureRoot = URL(fileURLWithPath: "/Users/Shared/SpotlessTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defaultsName = "SpotlessTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsName)!
        let temporaryDirectoryURLs = ["private-tmp", "private-var-tmp", "user-tmp"].map {
            fixtureRoot.appendingPathComponent($0, isDirectory: true)
        }
        service = CleanerService(
            homeDirectory: fixtureRoot,
            startupVolumeURL: fixtureRoot,
            userDefaults: defaults,
            temporaryDirectoryURLs: temporaryDirectoryURLs,
            installedApplicationRoots: [
                fixtureRoot.appendingPathComponent("Applications", isDirectory: true),
                fixtureRoot.appendingPathComponent("Library/Input Methods", isDirectory: true),
                fixtureRoot.appendingPathComponent("opt/homebrew/Caskroom", isDirectory: true),
                fixtureRoot.appendingPathComponent("Library/Application Support/Setapp/Applications", isDirectory: true),
                fixtureRoot.appendingPathComponent("UnreadableApplications", isDirectory: true)
            ],
            includesRunningApplicationIdentities: false
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixtureRoot)
        defaults.removePersistentDomain(forName: defaultsName)
    }

    func testAnalysisFindsLargeFilesAcrossStartupVolume() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let oldLarge = downloads.appendingPathComponent("old-large.bin")
        try createSparseFile(at: oldLarge, size: 200_000_001)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)], ofItemAtPath: oldLarge.path)

        let documents = fixtureRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let recentLarge = documents.appendingPathComponent("recent-large.bin")
        try createSparseFile(at: recentLarge, size: 200_000_001)

        let result = service.scanProvider(category: .analysis)

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == oldLarge.path })
        XCTAssertTrue(result.candidates.contains { $0.pathDescription == recentLarge.path })
        XCTAssertTrue(result.candidates.allSatisfy { $0.risk == .review && $0.removalMode == .trash && !$0.isSelected })
        XCTAssertEqual(result.volumeSummary?.candidateCount, result.candidates.count)
        let oldCandidateSize = result.candidates.first { $0.pathDescription == oldLarge.path }?.byteSize ?? 0
        XCTAssertGreaterThanOrEqual(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Downloads" })?.byteSize ?? 0,
            oldCandidateSize
        )
        XCTAssertEqual(result.candidates.first { $0.pathDescription == oldLarge.path }?.logicalByteSize, 200_000_002)
        XCTAssertEqual(result.candidates.first { $0.pathDescription == recentLarge.path }?.logicalByteSize, 200_000_002)
        XCTAssertFalse(result.volumeSummary?.usageItems.isEmpty ?? true)
    }

    func testAnalysisFindsGlobalInstallersIncludingLibrary() throws {
        let library = fixtureRoot.appendingPathComponent("Library", isDirectory: true)
        let libraryInstaller = library.appendingPathComponent("Installer.dmg")
        let libraryLargeFile = library.appendingPathComponent("large-library-file.bin")
        let nestedInstaller = fixtureRoot.appendingPathComponent("Downloads/Music/Archive.pkg")
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedInstaller.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 16).write(to: libraryInstaller)
        try createSparseFile(at: libraryLargeFile, size: 20_000_001)
        try Data(repeating: 1, count: 16).write(to: nestedInstaller)

        let result = service.scanProvider(category: .analysis)

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == libraryInstaller.path })
        XCTAssertTrue(result.candidates.contains { $0.pathDescription == nestedInstaller.path })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == libraryLargeFile.path })
        XCTAssertEqual(
            result.candidates.first { $0.pathDescription == libraryInstaller.path }?.source,
            .key(.sourceInstallers)
        )
    }

    func testAnalysisDoesNotProposeSmallFilesInStandardFolders() throws {
        let documents = fixtureRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let smallFile = documents.appendingPathComponent("small.txt")
        try Data("small".utf8).write(to: smallFile)

        let result = service.scanProvider(category: .analysis)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == smallFile.path })
    }

    func testAnalysisReportsEmptyResultAsSuccessful() {
        let result = service.scanProvider(category: .analysis)

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertFalse(result.isPartial)
        XCTAssertNotNil(result.volumeSummary)
        XCTAssertTrue(result.diagnostics.contains { !$0.isWarning && $0.message == .key(.scanNoMeasurableUserFiles) })
    }

    func testLocalSnapshotParserIgnoresEmptyDiskHeader() {
        let output = "Snapshots for disk /:\n"

        XCTAssertTrue(CleanerService.localSnapshotEntries(from: output).isEmpty)
    }

    func testLocalSnapshotParserKeepsActualSnapshotEntries() {
        let output = "Snapshots for volume group containing disk /:\ncom.apple.TimeMachine.2026-09-05-120000\n"

        XCTAssertEqual(
            CleanerService.localSnapshotEntries(from: output),
            ["com.apple.TimeMachine.2026-09-05-120000"]
        )
    }

    func testLocalSnapshotParserIgnoresSystemUpdateSnapshots() {
        let output = """
        Snapshots for volume group containing disk /:
        com.apple.os.update-2555E3E58AD284A3D1FD76F8FB071FBE0254898E3EDF47E707B9F6CFB0978E9F
        com.apple.os.update-MSUPrepareUpdate
        """

        XCTAssertTrue(CleanerService.localSnapshotEntries(from: output).isEmpty)
    }

    func testAnalysisSkipsProtectedStartupDirectories() throws {
        let protected = fixtureRoot.appendingPathComponent("System/secret.bin")
        try FileManager.default.createDirectory(at: protected.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: protected, size: 200_000_001)

        let result = service.scanProvider(category: .analysis)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == protected.path })
        XCTAssertTrue(result.volumeSummary?.usageItems.contains { $0.displayName == "System" && $0.isProtected } ?? false)
    }

    func testAnalysisExcludesPhotosLibrary() throws {
        let photosLibrary = fixtureRoot.appendingPathComponent("Pictures/Photos Library.photoslibrary", isDirectory: true)
        let photoData = photosLibrary.appendingPathComponent("originals/photo.bin")
        try FileManager.default.createDirectory(at: photoData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: photoData, size: 200_000_001)

        let result = service.scanProvider(category: .analysis)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("Photos Library.photoslibrary") })
        XCTAssertFalse(result.volumeSummary?.usageItems.contains { $0.url.path.contains("Photos Library.photoslibrary") } ?? false)
        XCTAssertFalse(result.diagnostics.contains { rendered($0.message).contains("Photos Library.photoslibrary") })
    }

    func testAnalysisProtectsPhotosAppButScansUnrelatedPhotoDirectories() throws {
        let photosAppData = fixtureRoot.appendingPathComponent("Applications/Photos.app/Contents/Resources/library.data")
        try FileManager.default.createDirectory(at: photosAppData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: photosAppData, size: 200_000_001)

        let installedAppData = fixtureRoot.appendingPathComponent("Applications/Example.app/Contents/Resources/app.data")
        try FileManager.default.createDirectory(at: installedAppData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: installedAppData, size: 200_000_001)

        let photoDirectoryData = fixtureRoot.appendingPathComponent("Library/Photos/originals/photo.data")
        try FileManager.default.createDirectory(at: photoDirectoryData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: photoDirectoryData, size: 200_000_001)

        let nestedPhotoData = fixtureRoot.appendingPathComponent("Downloads/Photos/album.data")
        try FileManager.default.createDirectory(at: nestedPhotoData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: nestedPhotoData, size: 200_000_001)

        let result = service.scanProvider(category: .analysis)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("Photos.app") })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("Example.app") })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == photoDirectoryData.path })
        XCTAssertTrue(result.candidates.contains { $0.pathDescription == nestedPhotoData.path })
    }

    func testAnalysisExcludesMusicLibrary() throws {
        let musicLibrary = fixtureRoot.appendingPathComponent("Music/Music Library.musiclibrary", isDirectory: true)
        let track = musicLibrary.appendingPathComponent("Media/track.m4a")
        try FileManager.default.createDirectory(at: track.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: track, size: 200_000_001)

        let unrelatedTrack = fixtureRoot.appendingPathComponent("Music/Media/track-2.m4a")
        try FileManager.default.createDirectory(at: unrelatedTrack.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: unrelatedTrack, size: 200_000_001)

        let result = service.scanProvider(category: .analysis)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("Music Library.musiclibrary") })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("track-2.m4a") })
        XCTAssertGreaterThan(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Music" })?.byteSize ?? 0,
            0
        )
        XCTAssertFalse(result.diagnostics.contains { rendered($0.message).contains("Music Library.musiclibrary") })
    }

    func testAnalysisAllowsUnrelatedMediaLibraryArchives() throws {
        let photoArchive = fixtureRoot.appendingPathComponent("Pictures/manual-photo-backup.zip")
        let musicArchive = fixtureRoot.appendingPathComponent("Music/manual-music-backup.zip")
        try FileManager.default.createDirectory(at: photoArchive.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: musicArchive.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("photo archive".utf8).write(to: photoArchive)
        try Data("music archive".utf8).write(to: musicArchive)

        let result = service.scanProvider(category: .analysis)

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == photoArchive.path })
        XCTAssertTrue(result.candidates.contains { $0.pathDescription == musicArchive.path })
    }

    func testAnalysisDoesNotDuplicateHardLinkedCandidate() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let original = downloads.appendingPathComponent("original.bin")
        let hardLink = downloads.appendingPathComponent("hard-link.bin")
        try createSparseFile(at: original, size: 12_000_001)
        try FileManager.default.linkItem(atPath: original.path, toPath: hardLink.path)

        let result = service.scanProvider(category: .analysis)

        XCTAssertEqual(
            result.candidates.filter { $0.pathDescription == original.path || $0.pathDescription == hardLink.path }.count,
            1
        )
    }

    func testUnifiedScanExcludesAppleMusicApplicationData() throws {
        let musicContainer = fixtureRoot.appendingPathComponent("Library/Containers/com.apple.Music", isDirectory: true)
        let mediaDatabase = musicContainer.appendingPathComponent("Data/Library/MediaLibrary.sqlite")
        try FileManager.default.createDirectory(at: mediaDatabase.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: mediaDatabase, size: 200_000_001)

        let musicPreferences = fixtureRoot.appendingPathComponent("Library/Preferences/com.apple.Music.plist")
        try FileManager.default.createDirectory(at: musicPreferences.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("protected".utf8).write(to: musicPreferences)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("com.apple.Music") })
        XCTAssertFalse(result.volumeSummary?.usageItems.contains { $0.url.path.contains("com.apple.Music") } ?? false)
        XCTAssertFalse(result.diagnostics.contains { rendered($0.message).contains("com.apple.Music") })
    }

    func testUnifiedScanExcludesPhotosApplicationData() throws {
        let photosContainer = fixtureRoot.appendingPathComponent("Library/Containers/com.apple.Photos", isDirectory: true)
        let photoDatabase = photosContainer.appendingPathComponent("Data/Library/Photos.sqlite")
        try FileManager.default.createDirectory(at: photoDatabase.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: photoDatabase, size: 200_000_001)

        let photosGroupContainer = fixtureRoot.appendingPathComponent("Library/Group Containers/group.com.apple.Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosGroupContainer, withIntermediateDirectories: true)
        try Data("protected".utf8).write(to: photosGroupContainer.appendingPathComponent("library.data"))

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("com.apple.Photos") })
        XCTAssertFalse(result.volumeSummary?.usageItems.contains { $0.url.path.contains("com.apple.Photos") } ?? false)
        XCTAssertFalse(result.diagnostics.contains { rendered($0.message).contains("com.apple.Photos") })
    }

    func testZeroByteCountUsesNumericZero() {
        XCTAssertEqual(formatByteCount(0, locale: Locale(identifier: "en")), "0 KB")
    }

    func testDiskAccessStatusReflectsProbeAvailability() throws {
        let probe = fixtureRoot.appendingPathComponent("TCC.db")
        let limitedService = CleanerService(
            homeDirectory: fixtureRoot,
            startupVolumeURL: fixtureRoot,
            userDefaults: defaults,
            fullDiskAccessProbeURL: probe
        )
        XCTAssertEqual(limitedService.startupVolumeAccessStatus(), .limited)

        try Data("authorized".utf8).write(to: probe)
        let fullService = CleanerService(
            homeDirectory: fixtureRoot,
            startupVolumeURL: fixtureRoot,
            userDefaults: defaults,
            fullDiskAccessProbeURL: probe
        )
        XCTAssertEqual(fullService.startupVolumeAccessStatus(), .full)
    }

    func testAnalysisSkipsExternalAndNetworkMountPoints() throws {
        for mountPoint in ["Volumes/External", "Network/Remote"] {
            let file = fixtureRoot.appendingPathComponent("\(mountPoint)/large.bin")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try createSparseFile(at: file, size: 200_000_001)
        }

        let result = service.scanProvider(category: .analysis)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("External") })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("Remote") })
    }

    func testAnalysisReportsUnreadableLocationWhenFilesystemDeniesAccess() throws {
        let unreadable = fixtureRoot.appendingPathComponent("Restricted", isDirectory: true)
        try FileManager.default.createDirectory(at: unreadable, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadable.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: unreadable.path) }

        let result = service.scanProvider(category: .analysis)

        XCTAssertTrue(result.isPartial)
        XCTAssertTrue(result.diagnostics.contains { rendered($0.message).contains("Restricted") })
    }

    func testAnalysisEmitsProgressAndFinishedEvents() throws {
        let file = fixtureRoot.appendingPathComponent("Movies/movie.bin")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: file, size: 200_000_001)
        let collector = EventCollector()

        let result = service.scanProvider(category: .analysis, emit: { @Sendable event in
            collector.append(event)
        })

        XCTAssertNotNil(result.volumeSummary)
        let progress = collector.events.compactMap { event -> Int? in
            if case .scanProgress(let value) = event { return value.processedEntries }
            return nil
        }
        XCTAssertTrue(progress.count >= 2)
        XCTAssertEqual(progress, progress.sorted())
        XCTAssertTrue(collector.events.contains { event in
            if case .scanProgress = event { return true }
            return false
        })
    }

    func testScanProgressIsThrottledButFinalCountIsExact() throws {
        let documents = fixtureRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        for index in 0..<512 {
            try Data([0]).write(to: documents.appendingPathComponent("file-" + String(index) + ".bin"))
        }
        let collector = EventCollector()

        let result = service.scanProvider(category: .analysis) { event in
            collector.append(event)
        }

        let progress = collector.events.compactMap { event -> Int? in
            if case .scanProgress(let value) = event { return value.processedEntries }
            return nil
        }
        XCTAssertEqual(progress.last, result.scannedCount)
        XCTAssertLessThan(progress.count, 32)
    }

    func testAnalysisKeepsAllCandidatesAndSortsBySize() throws {
        let directory = fixtureRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<501 {
            try createSparseFile(at: directory.appendingPathComponent("large-\(index).bin"), size: 200_000_001 + UInt64(index))
        }

        let result = service.scanProvider(category: .analysis)

        XCTAssertEqual(result.candidates.count, 501)
        XCTAssertFalse(result.isPartial)
        XCTAssertFalse(result.diagnostics.contains { rendered($0.message).contains("仅展示占用最大") })
        XCTAssertTrue(zip(result.candidates, result.candidates.dropFirst()).allSatisfy { left, right in
            (left.byteSize ?? 0) >= (right.byteSize ?? 0)
        })
    }

    func testUnifiedScanOrdersProvidersAndKeepsEligibleCandidatesSelectable() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 32).write(to: cache.appendingPathComponent("cache.data"))

        let application = fixtureRoot.appendingPathComponent("Applications/Example.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.removed")

        let leftover = fixtureRoot.appendingPathComponent("Library/Application Support/com.example.removed", isDirectory: true)
        try FileManager.default.createDirectory(at: leftover, withIntermediateDirectories: true)
        let leftoverInstaller = leftover.appendingPathComponent("installer.dmg")
        try Data(repeating: 1, count: 32).write(to: leftoverInstaller)

        let installer = fixtureRoot.appendingPathComponent("Downloads/Example.dmg")
        try FileManager.default.createDirectory(at: installer.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 16).write(to: installer)

        let nodeModules = fixtureRoot.appendingPathComponent("Projects/Example/node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: nodeModules.deletingLastPathComponent().appendingPathComponent("package.json"))
        try Data("lock".utf8).write(to: nodeModules.deletingLastPathComponent().appendingPathComponent("package-lock.json"))
        let nestedDependency = nodeModules.appendingPathComponent("package/index.js")
        try FileManager.default.createDirectory(at: nestedDependency.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 64).write(to: nestedDependency)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)], ofItemAtPath: nodeModules.deletingLastPathComponent().path)

        let collector = EventCollector()
        let installedResult = service.scanUnified()
        XCTAssertFalse(installedResult.candidates.contains { $0.pathDescription == leftover.path })
        try FileManager.default.removeItem(at: application.deletingLastPathComponent())

        let result = service.scanUnified { event in collector.append(event) }
        let providerOrder = result.providers.map(\.provider)

        XCTAssertEqual(providerOrder, [.deepCleanup, .projectArtifacts, .applications, .spaceAnalysis])
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == cache.path })
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == cache.path && $0.provider == .deepCleanup })
        XCTAssertFalse(result.eligibleCandidates.contains { $0.pathDescription == application.deletingLastPathComponent().path })
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == leftover.path && $0.provider == .applications })
        XCTAssertFalse(result.candidates.contains {
            $0.pathDescription == leftoverInstaller.path && $0.provider == .spaceAnalysis
        })
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == installer.path && $0.provider == .spaceAnalysis })
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == nodeModules.path && $0.provider == .projectArtifacts })
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
        XCTAssertFalse(result.candidates.contains {
            $0.provider == .projectArtifacts && $0.pathDescription.contains("package/index.js")
        })
        XCTAssertTrue(collector.events.contains { event in
            if case .providerStatus(let status) = event, status.provider == .applications { return true }
            return false
        })
        XCTAssertFalse(collector.events.contains { event in
            guard case .scanProgress(let progress) = event,
                  let provider = progress.provider else { return false }
            return progress.stage == provider.titleMessage
        })

        var maximumScannedCounts: [CleanupProvider: Int] = [:]
        for event in collector.events {
            if case .scanProgress(let progress) = event, let provider = progress.provider {
                maximumScannedCounts[provider] = max(maximumScannedCounts[provider, default: 0], progress.processedEntries)
            }
        }
        XCTAssertGreaterThan(
            maximumScannedCounts[.projectArtifacts, default: 0],
            result.candidates.filter { $0.provider == .projectArtifacts }.count
        )

        XCTAssertFalse(collector.events.contains { event in
            if case .candidateDiscovered = event { return true }
            return false
        })
    }

    func testUnifiedScanReusesArtifactDirectoryAndKeepsParentOwnership() throws {
        let project = fixtureRoot.appendingPathComponent("Documents/ArchiveProject", isDirectory: true)
        let artifact = project.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))
        let nestedArchive = artifact.appendingPathComponent("downloaded-package.zip")
        try Data("zip".utf8).write(to: nestedArchive)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)],
            ofItemAtPath: project.path
        )
        let unownedLargeFile = fixtureRoot.appendingPathComponent("Downloads/unowned-large.bin")
        try FileManager.default.createDirectory(at: unownedLargeFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: unownedLargeFile, size: 12_000_001)

        let result = service.scanUnified()

        XCTAssertTrue(result.candidates.contains {
            $0.pathDescription == artifact.path && $0.provider == .projectArtifacts
        })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == nestedArchive.path })
        XCTAssertTrue(result.candidates.contains {
            $0.pathDescription == unownedLargeFile.path && $0.provider == .spaceAnalysis
        })
        let projectStatus = try XCTUnwrap(result.providers.first { $0.provider == .projectArtifacts })
        XCTAssertEqual(projectStatus.candidateCount, 1)
        XCTAssertEqual(result.volumeSummary?.candidateCount, result.candidates.filter { $0.provider == .spaceAnalysis }.count)
    }

    func testUnifiedScanOnlySuppressesPathsOwnedByEarlierProviders() throws {
        let recentProject = fixtureRoot.appendingPathComponent("Documents/workspace/resume", isDirectory: true)
        let projectArtifact = recentProject.appendingPathComponent(".next/cache", isDirectory: true)
        let projectFile = projectArtifact.appendingPathComponent("webpack-cache.node")
        try FileManager.default.createDirectory(at: projectArtifact, withIntermediateDirectories: true)
        try createSparseFile(at: projectFile, size: 12_000_001)

        let cacheRoot = fixtureRoot.appendingPathComponent("Library/Caches/pip", isDirectory: true)
        let cacheFile = cacheRoot.appendingPathComponent("download.zip")
        try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        try Data("cache archive".utf8).write(to: cacheFile)

        let appDataRoot = fixtureRoot.appendingPathComponent("Library/Application Support/com.example.app", isDirectory: true)
        let appDataFile = appDataRoot.appendingPathComponent("installer.dmg")
        try FileManager.default.createDirectory(at: appDataRoot, withIntermediateDirectories: true)
        try Data("app archive".utf8).write(to: appDataFile)

        let result = service.scanUnified()

        XCTAssertTrue(result.candidates.contains {
            $0.pathDescription == projectFile.path && $0.provider == .spaceAnalysis
        })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == cacheFile.path })
        XCTAssertTrue(result.candidates.contains {
            $0.pathDescription == appDataFile.path && $0.provider == .spaceAnalysis
        })
        XCTAssertTrue(result.candidates.contains {
            $0.provider == .deepCleanup && $0.pathDescription == cacheRoot.path
        })
        XCTAssertGreaterThan(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Documents" })?.byteSize ?? 0,
            0
        )
    }

    func testUnifiedScanDoesNotReuseIncompleteArtifactDirectory() throws {
        let project = fixtureRoot.appendingPathComponent("Documents/UnreadableProject", isDirectory: true)
        let artifact = project.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))
        try Data("zip".utf8).write(to: artifact.appendingPathComponent("package.zip"))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)],
            ofItemAtPath: project.path
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: artifact.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: artifact.path) }

        let result = service.scanUnified()

        XCTAssertTrue(result.isPartial)
        XCTAssertTrue(result.diagnostics.contains { rendered($0.message).contains(artifact.path) })
    }

    func testUnifiedScanExcludesAppleApplicationsAndAppleData() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/SystemTool.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.apple.systemtool")

        let appleData = fixtureRoot.appendingPathComponent("Library/Application Support/com.apple.private", isDirectory: true)
        try FileManager.default.createDirectory(at: appleData, withIntermediateDirectories: true)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("SystemTool.app") })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("com.apple.private") })
    }

    func testInstalledApplicationPreferenceAndSavedStateAreNotLeftovers() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Example.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.app")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.app.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("preference".utf8).write(to: preference)

        let savedState = fixtureRoot.appendingPathComponent("Library/Saved Application State/com.example.app.savedState", isDirectory: true)
        try FileManager.default.createDirectory(at: savedState, withIntermediateDirectories: true)
        try Data("state".utf8).write(to: savedState.appendingPathComponent("window.data"))

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == preference.path })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == savedState.path })
    }

    func testInstalledApplicationComponentsAndAmbiguousDataAreNotLeftovers() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Example.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.app")

        let helper = application.appendingPathComponent("XPCServices/ExampleService.xpc/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: helper, withIntermediateDirectories: true)
        try writeBundleInfo(at: helper.appendingPathComponent("Info.plist"), identifier: "com.example.app.CUAService")

        let cache = fixtureRoot.appendingPathComponent("Library/Caches/com.example.app", isDirectory: true)
        let container = fixtureRoot.appendingPathComponent("Library/Containers/com.example.app", isDirectory: true)
        let webKit = fixtureRoot.appendingPathComponent("Library/WebKit/com.example.app", isDirectory: true)
        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.app.CUAService.plist")
        for directory in [cache, container, webKit] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("active".utf8).write(to: directory.appendingPathComponent("state.data"))
        }
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("active".utf8).write(to: preference)

        let result = service.scanUnified()

        for path in [cache.path, container.path, webKit.path, preference.path] {
            XCTAssertFalse(result.candidates.contains { $0.pathDescription == path }, "active application data must not be a leftover: \(path)")
        }
    }

    func testOrphanLaunchItemDoesNotKeepApplicationDataActive() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/LaunchHost.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.launcher")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.launcher.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("active".utf8).write(to: preference)

        XCTAssertFalse(service.scanUnified().candidates.contains { $0.pathDescription == preference.path })

        try FileManager.default.removeItem(at: application.deletingLastPathComponent())
        let launchAgent = fixtureRoot.appendingPathComponent("Library/LaunchAgents/com.example.launcher.plist")
        let launchAgentInfo: [String: Any] = ["Label": "com.example.launcher"]
        let launchAgentData = try PropertyListSerialization.data(fromPropertyList: launchAgentInfo, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: launchAgent.deletingLastPathComponent(), withIntermediateDirectories: true)
        try launchAgentData.write(to: launchAgent)

        let result = service.scanUnified()

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == preference.path })
    }

    func testUninstalledApplicationPreferenceAndExpandedRootAreProposed() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Removed.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.removed")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.removed.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("preference".utf8).write(to: preference)

        let storage = fixtureRoot.appendingPathComponent("Library/HTTPStorages/com.example.removed", isDirectory: true)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        try Data("storage".utf8).write(to: storage.appendingPathComponent("cache.data"))

        let installedResult = service.scanUnified()
        XCTAssertFalse(installedResult.candidates.contains { $0.pathDescription == preference.path })
        XCTAssertFalse(installedResult.candidates.contains { $0.pathDescription == storage.path })

        try FileManager.default.removeItem(at: application.deletingLastPathComponent())
        let result = service.scanUnified()

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == preference.path && $0.provider == .applications })
        XCTAssertTrue(result.candidates.contains { $0.pathDescription == storage.path && $0.provider == .applications })
        XCTAssertTrue(result.candidates.filter { $0.provider == .applications }.allSatisfy { !$0.isSelected })
    }

    func testDeepNestedApplicationComponentsProtectAndThenReleaseTheirData() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Host.app/Contents", isDirectory: true)
        let nestedUpdater = application.appendingPathComponent(
            "Frameworks/Updater.framework/Versions/A/Helpers/UpdateServer.app/Contents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: nestedUpdater, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.host")
        let frameworkResources = application.appendingPathComponent(
            "Frameworks/Updater.framework/Versions/A/Resources",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: frameworkResources, withIntermediateDirectories: true)
        try writeBundleInfo(
            at: application.appendingPathComponent("Frameworks/Updater.framework/Info.plist"),
            identifier: "com.example.updater.framework"
        )
        try writeBundleInfo(at: frameworkResources.appendingPathComponent("Info.plist"), identifier: "com.example.updater.framework")
        try writeBundleInfo(at: nestedUpdater.appendingPathComponent("Info.plist"), identifier: "com.example.updater")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.updater.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("updater".utf8).write(to: preference)

        let installedResult = service.scanUnified()
        XCTAssertFalse(installedResult.candidates.contains { $0.pathDescription == preference.path })

        try FileManager.default.removeItem(at: application.deletingLastPathComponent().deletingLastPathComponent())
        let removedResult = service.scanUnified()
        XCTAssertTrue(removedResult.candidates.contains { $0.pathDescription == preference.path })
    }

    func testSharedNestedComponentStaysProtectedUntilAllOwnersDisappear() throws {
        let firstApplication = fixtureRoot.appendingPathComponent("Applications/FirstHost.app/Contents", isDirectory: true)
        let secondApplication = fixtureRoot.appendingPathComponent("Applications/SecondHost.app/Contents", isDirectory: true)
        let sharedComponentRelativePath = "Helpers/SharedUpdater.xpc/Contents"
        let firstComponent = firstApplication.appendingPathComponent(sharedComponentRelativePath, isDirectory: true)
        let secondComponent = secondApplication.appendingPathComponent(sharedComponentRelativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: firstComponent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondComponent, withIntermediateDirectories: true)
        try writeBundleInfo(at: firstApplication.appendingPathComponent("Info.plist"), identifier: "com.example.firsthost")
        try writeBundleInfo(at: secondApplication.appendingPathComponent("Info.plist"), identifier: "com.example.secondhost")
        for component in [firstComponent, secondComponent] {
            try writeBundleInfo(at: component.appendingPathComponent("Info.plist"), identifier: "com.example.sharedupdater")
        }

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.sharedupdater.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("shared".utf8).write(to: preference)

        XCTAssertFalse(service.scanUnified().candidates.contains { $0.pathDescription == preference.path })

        try FileManager.default.removeItem(at: firstApplication.deletingLastPathComponent())
        XCTAssertFalse(service.scanUnified().candidates.contains { $0.pathDescription == preference.path })

        try FileManager.default.removeItem(at: secondApplication.deletingLastPathComponent())
        XCTAssertTrue(service.scanUnified().candidates.contains { $0.pathDescription == preference.path })
    }

    func testUnknownSharedSDKAndNativeMessagingDataStayHidden() throws {
        let sdkData = fixtureRoot.appendingPathComponent("Library/Application Support/com.example.sharedsdk", isDirectory: true)
        let nativeMessagingData = fixtureRoot.appendingPathComponent("Library/Application Support/com.example.browser", isDirectory: true)
            .appendingPathComponent("NativeMessagingHosts/com.example.extension.json")
        try FileManager.default.createDirectory(at: sdkData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nativeMessagingData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("sdk".utf8).write(to: sdkData.appendingPathComponent("state.data"))
        try Data("extension".utf8).write(to: nativeMessagingData)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == sdkData.path })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == nativeMessagingData.path })
    }

    func testBinaryCookiesUseHistoricalBundleNamespaceAndWeakDatabaseFilesStayHidden() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Browser.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.browser")

        let binaryCookies = fixtureRoot.appendingPathComponent("Library/HTTPStorages/com.example.browser.binarycookies")
        let weakDatabaseFile = fixtureRoot.appendingPathComponent("Library/Application Support/default.store-wal")
        try FileManager.default.createDirectory(at: binaryCookies.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: weakDatabaseFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("cookies".utf8).write(to: binaryCookies)
        try Data("wal".utf8).write(to: weakDatabaseFile)

        let installedResult = service.scanUnified()
        XCTAssertFalse(installedResult.candidates.contains { $0.pathDescription == binaryCookies.path })
        XCTAssertFalse(installedResult.candidates.contains { $0.pathDescription == weakDatabaseFile.path })

        try FileManager.default.removeItem(at: application.deletingLastPathComponent())
        let removedResult = service.scanUnified()
        XCTAssertTrue(removedResult.candidates.contains { $0.pathDescription == binaryCookies.path })
        XCTAssertFalse(removedResult.candidates.contains { $0.pathDescription == weakDatabaseFile.path })
    }

    func testLaunchItemAssociatedIdentifiersAndProgramProtectData() throws {
        let application = fixtureRoot.appendingPathComponent("Custom/ProgramHost.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.programhost")

        let launchAgent = fixtureRoot.appendingPathComponent("Library/LaunchAgents/com.example.launcher.plist")
        let launchAgentInfo: [String: Any] = [
            "Label": "com.example.launcher",
            "AssociatedBundleIdentifiers": ["com.example.associated"],
            "ProgramArguments": [application.deletingLastPathComponent().appendingPathComponent("Contents/MacOS/ProgramHost").path]
        ]
        let launchAgentData = try PropertyListSerialization.data(fromPropertyList: launchAgentInfo, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: launchAgent.deletingLastPathComponent(), withIntermediateDirectories: true)
        try launchAgentData.write(to: launchAgent)

        let associatedPreference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.associated.plist")
        let programPreference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.programhost.plist")
        try FileManager.default.createDirectory(at: associatedPreference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("associated".utf8).write(to: associatedPreference)
        try Data("program".utf8).write(to: programPreference)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == associatedPreference.path })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == programPreference.path })
    }

    func testUserInputMethodProtectsItsPreferenceNamespace() throws {
        let inputMethod = fixtureRoot.appendingPathComponent("Library/Input Methods/Example.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: inputMethod, withIntermediateDirectories: true)
        try writeBundleInfo(at: inputMethod.appendingPathComponent("Info.plist"), identifier: "com.example.inputmethod")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.inputmethod.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("input method".utf8).write(to: preference)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == preference.path })
    }

    func testHomebrewAndSetappApplicationsProtectTheirData() throws {
        let homebrewApplication = fixtureRoot.appendingPathComponent(
            "opt/homebrew/Caskroom/Example/1.0/Example.app/Contents",
            isDirectory: true
        )
        let setappApplication = fixtureRoot.appendingPathComponent(
            "Library/Application Support/Setapp/Applications/SetappExample.app/Contents",
            isDirectory: true
        )
        for (contents, identifier) in [
            (homebrewApplication, "com.example.homebrew"),
            (setappApplication, "com.example.setapp")
        ] {
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            try writeBundleInfo(at: contents.appendingPathComponent("Info.plist"), identifier: identifier)
        }

        let homebrewPreference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.homebrew.plist")
        let setappPreference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.setapp.plist")
        try FileManager.default.createDirectory(at: homebrewPreference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("homebrew".utf8).write(to: homebrewPreference)
        try Data("setapp".utf8).write(to: setappPreference)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == homebrewPreference.path })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == setappPreference.path })
    }

    func testBundlePayloadDoesNotInvalidateApplicationInventory() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Visible.app/Contents", isDirectory: true)
        let payload = fixtureRoot.appendingPathComponent(
            "Applications/Resources.bundle/Contents/Resources/zh_CN.lproj",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.visible")

        let result = service.scanUnified()

        XCTAssertFalse(result.isPartial)
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == application.deletingLastPathComponent().path })
    }

    func testIncompleteInstalledApplicationSourceDoesNotAuthorizeLeftovers() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Removed.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.incomplete")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.incomplete.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("preference".utf8).write(to: preference)
        _ = service.scanUnified()

        try FileManager.default.removeItem(at: application.deletingLastPathComponent())
        FileManager.default.createFile(
            atPath: fixtureRoot.appendingPathComponent("UnreadableApplications").path,
            contents: Data("not a directory".utf8)
        )

        let result = service.scanUnified()

        XCTAssertTrue(result.isPartial)
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == preference.path })
    }

    func testUnreadableApplicationIdentityDoesNotAuthorizeLeftovers() throws {
        let knownApplication = fixtureRoot.appendingPathComponent("Applications/Known.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: knownApplication, withIntermediateDirectories: true)
        try writeBundleInfo(at: knownApplication.appendingPathComponent("Info.plist"), identifier: "com.example.unreadable")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.unreadable.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("preference".utf8).write(to: preference)
        _ = service.scanUnified()

        try FileManager.default.removeItem(at: knownApplication.deletingLastPathComponent())
        let unreadableApplication = fixtureRoot.appendingPathComponent("Applications/Unreadable.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: unreadableApplication, withIntermediateDirectories: true)
        try writeBundleInfo(at: unreadableApplication.appendingPathComponent("Info.plist"), identifier: "com.example.unreadable")
        try FileManager.default.createDirectory(
            at: unreadableApplication.appendingPathComponent("_CodeSignature", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: unreadableApplication.appendingPathComponent("XPCServices/Broken.xpc/Contents", isDirectory: true),
            withIntermediateDirectories: true
        )

        let result = service.scanUnified()

        XCTAssertTrue(result.isPartial)
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == preference.path })
    }

    func testApplicationLeftoverExecutionRechecksInstalledApplicationSources() throws {
        let application = fixtureRoot.appendingPathComponent("Applications/Reappeared.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.reappeared")

        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.reappeared.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("preference".utf8).write(to: preference)
        _ = service.scanUnified()

        try FileManager.default.removeItem(at: application.deletingLastPathComponent())
        let leftover = try XCTUnwrap(service.scanUnified().candidates.first { $0.pathDescription == preference.path })

        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.reappeared")

        let summary = service.execute(
            plan: CleanupPlan(selectedCandidates: [leftover], allCandidates: [leftover]),
            cancellation: CancellationToken()
        ) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .failed)
        XCTAssertTrue(summary.results.first?.message.requiresRescan == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: preference.path))
    }

    func testExpandedInstallerTypesAreSpaceCandidates() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let xip = downloads.appendingPathComponent("Xcode.xip")
        let ipsw = downloads.appendingPathComponent("Device.ipsw")
        try Data("xip".utf8).write(to: xip)
        try Data("ipsw".utf8).write(to: ipsw)

        let result = service.scanUnified()

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == xip.path && $0.source == .key(.sourceInstallers) })
        XCTAssertTrue(result.candidates.contains { $0.pathDescription == ipsw.path && $0.source == .key(.sourceInstallers) })
    }

    func testInstallersAndArchivesAreFoundAnywhereWithoutSizeThreshold() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let largeArchive = downloads.appendingPathComponent("archive.zip")
        try createSparseFile(at: largeArchive, size: 10_000_001)
        let smallArchive = downloads.appendingPathComponent("small.zip")
        try Data("zip".utf8).write(to: smallArchive)
        let externalInstaller = fixtureRoot.appendingPathComponent("Projects/Tool.pkg")
        try FileManager.default.createDirectory(at: externalInstaller.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("pkg".utf8).write(to: externalInstaller)
        let externalArchive = fixtureRoot.appendingPathComponent("Projects/source.tar.gz")
        try Data("archive".utf8).write(to: externalArchive)
        let smallOrdinaryFile = downloads.appendingPathComponent("small.txt")
        // createSparseFile 实际写入 size+1 字节；普通大文件阈值为 10_000_000，
        // 这里必须保持在阈值之内才不会被视为大文件候选
        try createSparseFile(at: smallOrdinaryFile, size: 9_999_999)

        let result = service.scanUnified()

        for path in [largeArchive.path, smallArchive.path, externalInstaller.path, externalArchive.path] {
            XCTAssertTrue(result.candidates.contains {
                $0.pathDescription == path
                    && $0.provider == .spaceAnalysis
                    && $0.source == .key(.sourceInstallers)
            })
        }
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == smallOrdinaryFile.path })
    }

    func testAnalysisTimeoutReturnsPartialResult() throws {
        let file = fixtureRoot.appendingPathComponent("Documents/large.bin")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: file, size: 200_000_001)
        let timedService = CleanerService(
            homeDirectory: fixtureRoot,
            startupVolumeURL: fixtureRoot,
            userDefaults: defaults,
            analysisTimeout: 0
        )

        let result = timedService.scanProvider(category: .analysis)

        XCTAssertTrue(result.isPartial)
        XCTAssertTrue(result.diagnostics.contains { $0.message == .key(.scanStartupDiskTimeout) })
    }

    func testRecentDeveloperArtifactIsNotProposed() throws {
        let artifact = fixtureRoot.appendingPathComponent("Projects/App/node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: artifact.deletingLastPathComponent().appendingPathComponent("package.json"))
        try Data("lockfile".utf8).write(to: artifact.deletingLastPathComponent().appendingPathComponent("package-lock.json"))

        let result = service.scanProvider(category: .developer)

        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testOldDeveloperArtifactIsProposed() throws {
        let artifact = fixtureRoot.appendingPathComponent("Projects/App/node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: artifact.deletingLastPathComponent().appendingPathComponent("package.json"))
        try Data("lockfile".utf8).write(to: artifact.deletingLastPathComponent().appendingPathComponent("package-lock.json"))
        // 空目录会被扫描按零体积丢弃，候选必须有内容
        try Data("export {}".utf8).write(to: artifact.appendingPathComponent("index.js"))
        let oldDate = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: artifact.deletingLastPathComponent().path)

        let result = service.scanProvider(category: .developer)

        XCTAssertTrue(result.candidates.contains { $0.displayName == "node_modules" })
        XCTAssertTrue(result.candidates.allSatisfy { $0.risk == .review || $0.risk == .safe })
    }

    func testNodeModulesUsesAggregateSizeAndTrashRouting() throws {
        let project = fixtureRoot.appendingPathComponent("Projects/App", isDirectory: true)
        let artifact = project.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))
        try Data("lockfile".utf8).write(to: project.appendingPathComponent("pnpm-lock.yaml"))
        let nested = artifact.appendingPathComponent("package-a/index.js")
        try FileManager.default.createDirectory(at: nested.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 256).write(to: nested)
        let oldDate = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: project.path)

        let result = service.scanProvider(category: .developer)
        let candidate = try XCTUnwrap(result.candidates.first { $0.displayName == "node_modules" })

        XCTAssertEqual(candidate.removalMode, .trash)
        XCTAssertFalse(candidate.isSelected)
        XCTAssertGreaterThanOrEqual(candidate.byteSize ?? 0, 256)
        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("package-a") })
    }

    func testGlobalDevelopmentCacheBelongsToCacheProviderAndIsUnselected() throws {
        let npmCache = fixtureRoot.appendingPathComponent(".npm/_cacache", isDirectory: true)
        try FileManager.default.createDirectory(at: npmCache, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 128).write(to: npmCache.appendingPathComponent("entry.data"))

        let cacheResult = service.scanProvider(category: .routine)
        let projectResult = service.scanProvider(category: .developer)
        let candidate = try XCTUnwrap(cacheResult.candidates.first { $0.pathDescription == npmCache.path })

        XCTAssertEqual(candidate.provider, .deepCleanup)
        XCTAssertEqual(candidate.risk, .review)
        XCTAssertFalse(candidate.isSelected)
        XCTAssertGreaterThanOrEqual(candidate.byteSize ?? 0, 128)
        XCTAssertFalse(projectResult.candidates.contains { $0.pathDescription == npmCache.path })
    }

    func testTemporaryDirectoriesAreMergedIntoCacheCandidates() throws {
        let temporaryRoots = ["private-tmp", "private-var-tmp", "user-tmp"].map {
            fixtureRoot.appendingPathComponent($0, isDirectory: true)
        }
        let oldDate = Date().addingTimeInterval(-16 * 24 * 60 * 60)
        var temporaryFiles: [URL] = []
        for (index, root) in temporaryRoots.enumerated() {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("ai-temp-\(index).data")
            try Data(repeating: 1, count: 128).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
            temporaryFiles.append(file)
        }
        let secondOldFile = temporaryRoots[0].appendingPathComponent("ai-temp-second.data")
        try Data(repeating: 1, count: 256).write(to: secondOldFile)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: secondOldFile.path)
        temporaryFiles.append(secondOldFile)
        let recentFile = temporaryRoots[0].appendingPathComponent("ai-temp-recent.data")
        try Data(repeating: 1, count: 128).write(to: recentFile)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-10 * 24 * 60 * 60)],
            ofItemAtPath: recentFile.path
        )

        let result = service.scanProvider(category: .routine)
        let candidates = result.candidates.filter { $0.source == .key(.sourceTemporaryFiles) }

        XCTAssertEqual(candidates.count, temporaryRoots.count)
        XCTAssertTrue(candidates.allSatisfy {
            $0.provider == .deepCleanup
                && $0.category == .routine
                && $0.risk == .review
                && $0.removalMode == .trash
                && !$0.isSelected
        })
        XCTAssertEqual(Set(candidates.compactMap { $0.url?.path }), Set(temporaryRoots.map { $0.path }))
        XCTAssertEqual(candidates.first { $0.url?.path == temporaryRoots[0].path }?.targetCount, 2)
        XCTAssertEqual(
            Set(candidates.flatMap { $0.targets.map(\.url.path) }),
            Set(temporaryFiles.map { $0.path })
        )
        XCTAssertFalse(candidates.flatMap(\.targets).contains { $0.url.path == recentFile.path })
    }

    func testLogsAreNotDefaultCleanupCandidates() throws {
        let logs = fixtureRoot.appendingPathComponent("Library/Logs/com.openai.codex", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let logFile = logs.appendingPathComponent("diagnostic.log")
        let diagnosticArchive = logs.appendingPathComponent("diagnostic.dmg")
        try Data(repeating: 1, count: 128).write(to: logFile)
        try Data(repeating: 1, count: 16).write(to: diagnosticArchive)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)],
            ofItemAtPath: logFile.path
        )

        let result = service.scanProvider(category: .routine)

        XCTAssertFalse(result.candidates.contains { $0.url?.path == logFile.path })

        let analysisResult = service.scanProvider(category: .analysis)
        XCTAssertFalse(analysisResult.candidates.contains { $0.url?.path == diagnosticArchive.path })
    }

    func testTemporaryAggregateCleansTargetsAndKeepsRoot() throws {
        let root = fixtureRoot.appendingPathComponent("private-tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let oldDate = Date().addingTimeInterval(-16 * 24 * 60 * 60)
        let files = ["aggregate-a.data", "aggregate-b.data"].map { root.appendingPathComponent($0) }
        for file in files {
            try Data(repeating: 1, count: 128).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
        }

        var candidate = try XCTUnwrap(
            service.scanProvider(category: .routine).candidates.first { $0.url?.path == root.path }
        )
        candidate.isSelected = true
        let summary = service.execute(
            plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]),
            cancellation: CancellationToken()
        ) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .movedToTrash)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        XCTAssertTrue(files.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        for file in files {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash").appendingPathComponent(file.lastPathComponent))
        }
    }

    func testTemporaryAggregateReportsPartialBytesWhenTargetChanges() throws {
        let root = fixtureRoot.appendingPathComponent("private-tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let oldDate = Date().addingTimeInterval(-16 * 24 * 60 * 60)
        let files = ["partial-a.data", "partial-b.data"].map { root.appendingPathComponent($0) }
        for file in files {
            try Data(repeating: 1, count: 128).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
        }

        var candidate = try XCTUnwrap(
            service.scanProvider(category: .routine).candidates.first { $0.url?.path == root.path }
        )
        candidate.isSelected = true
        // byteSize 全程使用分配大小（与候选展示一致），partial 上报被移动目标的分配字节
        let movedAllocatedBytes = Int64(try XCTUnwrap(
            try files[0].resourceValues(forKeys: [.fileAllocatedSizeKey]).fileAllocatedSize
        ))
        try FileManager.default.removeItem(at: files[1])

        let summary = service.execute(
            plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]),
            cancellation: CancellationToken()
        ) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .partiallyCompleted)
        XCTAssertEqual(summary.results.first?.byteSize, movedAllocatedBytes)
        XCTAssertTrue(summary.isPartial)
        XCTAssertEqual(summary.categories.first?.affectedBytes, movedAllocatedBytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash").appendingPathComponent(files[0].lastPathComponent)
        )
    }

    func testWhitelistedAppleCacheKeepsAggregateSizeAndDefaultSelection() throws {
        let safariCache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: safariCache, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 96).write(to: safariCache.appendingPathComponent("cache.data"))

        let result = service.scanProvider(category: .routine)
        let candidate = try XCTUnwrap(result.candidates.first { $0.pathDescription == safariCache.path })

        XCTAssertEqual(candidate.risk, .safe)
        XCTAssertTrue(candidate.isSelected)
        XCTAssertGreaterThanOrEqual(candidate.byteSize ?? 0, 96)
    }

    func testCacheCandidateReportsAllocatedSizeAndKeepsLogicalSize() throws {
        let derivedData = fixtureRoot.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        let logicalSize: UInt64 = 200_000_001
        let file = derivedData.appendingPathComponent("sparse-cache.data")
        try createSparseFile(at: file, size: logicalSize)

        let candidate = try XCTUnwrap(
            service.scanProvider(category: .routine).candidates.first { $0.pathDescription == derivedData.path }
        )

        XCTAssertEqual(candidate.logicalByteSize, Int64(logicalSize + 1))
        XCTAssertLessThan(candidate.byteSize ?? Int64.max, candidate.logicalByteSize ?? 0)
    }

    func testProjectArtifactStopsNestedCandidateTraversalAndUsesAggregateSize() throws {
        let project = fixtureRoot.appendingPathComponent("Projects/WebApp", isDirectory: true)
        let next = project.appendingPathComponent(".next", isDirectory: true)
        let nestedBuild = next.appendingPathComponent("cache/build", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedBuild, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))
        try Data(repeating: 1, count: 192).write(to: nestedBuild.appendingPathComponent("output.data"))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)],
            ofItemAtPath: project.path
        )

        let result = service.scanProvider(category: .developer)
        let candidate = try XCTUnwrap(result.candidates.first { $0.pathDescription == next.path })

        XCTAssertGreaterThanOrEqual(candidate.byteSize ?? 0, 192)
        XCTAssertFalse(candidate.isSelected)
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == nestedBuild.path })
        XCTAssertEqual(result.candidates.filter { $0.pathDescription.hasPrefix(next.path) }.count, 1)
    }

    func testGenericArtifactNameWithoutProjectMarkerIsNotCandidate() throws {
        let materials = fixtureRoot.appendingPathComponent("Documents/TripMaterials/build", isDirectory: true)
        try FileManager.default.createDirectory(at: materials, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 64).write(to: materials.appendingPathComponent("slides.pdf"))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)],
            ofItemAtPath: materials.deletingLastPathComponent().path
        )

        let result = service.scanProvider(category: .developer)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == materials.path })
    }

    func testDeepArtifactUsesMonorepoRootMarker() throws {
        let repo = fixtureRoot.appendingPathComponent("Projects/Mono", isDirectory: true)
        let build = repo.appendingPathComponent("packages/app/build", isDirectory: true)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: repo.appendingPathComponent("package.json"))
        try Data(repeating: 1, count: 64).write(to: build.appendingPathComponent("output.data"))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)],
            ofItemAtPath: build.deletingLastPathComponent().path
        )

        let result = service.scanProvider(category: .developer)

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == build.path })
    }

    func testRecentProjectArtifactSubtreeIsProtectedFromSpaceAnalysis() throws {
        let project = fixtureRoot.appendingPathComponent("Documents/LiveApp", isDirectory: true)
        let nodeModules = project.appendingPathComponent("node_modules", isDirectory: true)
        let binary = nodeModules.appendingPathComponent("next-swc.darwin-arm64.node")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))
        try createSparseFile(at: binary, size: 12_000_001)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == binary.path })
        XCTAssertFalse(result.candidates.contains {
            $0.pathDescription == nodeModules.path && $0.provider == .projectArtifacts
        })
        XCTAssertGreaterThan(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Documents" })?.byteSize ?? 0,
            0
        )
    }

    func testGenericArtifactDirectoryWithoutMarkerStaysCandidateInSpaceAnalysis() throws {
        let build = fixtureRoot.appendingPathComponent("Documents/AssetsPack/build", isDirectory: true)
        let large = build.appendingPathComponent("render-output.bin")
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try createSparseFile(at: large, size: 12_000_001)

        let result = service.scanUnified()

        XCTAssertTrue(result.candidates.contains {
            $0.pathDescription == large.path && $0.provider == .spaceAnalysis
        })
    }

    func testVcsObjectFilesAreNotSpaceAnalysisCandidates() throws {
        let packDirectory = fixtureRoot.appendingPathComponent("Documents/Repo/.git/objects/pack", isDirectory: true)
        let packFile = packDirectory.appendingPathComponent("pack-d54b8.pack")
        try FileManager.default.createDirectory(at: packDirectory, withIntermediateDirectories: true)
        try createSparseFile(at: packFile, size: 12_000_001)
        try Data("readme".utf8).write(to: packDirectory.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("README.md"))

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == packFile.path })
        XCTAssertGreaterThan(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Documents" })?.byteSize ?? 0,
            0
        )
    }

    func testVirtualMachineBundleContentsAreNotSpaceAnalysisCandidates() throws {
        let vmBundle = fixtureRoot.appendingPathComponent("Documents/Windows.vmwarevm", isDirectory: true)
        let diskImage = vmBundle.appendingPathComponent("Virtual Disk.dmg")
        try FileManager.default.createDirectory(at: vmBundle, withIntermediateDirectories: true)
        try createSparseFile(at: diskImage, size: 12_000_001)
        try Data("note".utf8).write(to: fixtureRoot.appendingPathComponent("Documents/notes.txt"))

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == diskImage.path })
        XCTAssertGreaterThan(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Documents" })?.byteSize ?? 0,
            0
        )
    }

    func testDefaultMusicLibraryRemainsExcludedFromAnalysis() throws {
        let libraryMedia = fixtureRoot.appendingPathComponent("Music/Music/Music Library.musiclibrary/Media/Downloads", isDirectory: true)
        let archive = libraryMedia.appendingPathComponent("album.zip")
        try FileManager.default.createDirectory(at: libraryMedia, withIntermediateDirectories: true)
        try createSparseFile(at: archive, size: 12_000_001)

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == archive.path })
    }

    func testRecentProjectDerivedDataIsProtectedFromSpaceAnalysis() throws {
        let project = fixtureRoot.appendingPathComponent("Documents/PhotoUI", isDirectory: true)
        let moduleCache = project.appendingPathComponent("DerivedData/ModuleCache.noindex", isDirectory: true)
        let pcm = moduleCache.appendingPathComponent("UIKit-9X64B4P.pcm")
        try FileManager.default.createDirectory(at: moduleCache, withIntermediateDirectories: true)
        try createSparseFile(at: pcm, size: 12_000_001)
        try Data("readme".utf8).write(to: project.appendingPathComponent("README.md"))

        let result = service.scanUnified()

        XCTAssertFalse(result.candidates.contains { $0.pathDescription == pcm.path })
        XCTAssertGreaterThan(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Documents" })?.byteSize ?? 0,
            0
        )
    }

    func testOldDerivedDataBecomesWholeDirectoryCandidateWithoutMarker() throws {
        let project = fixtureRoot.appendingPathComponent("Documents/OldPhotoUI", isDirectory: true)
        let derived = project.appendingPathComponent("DerivedData", isDirectory: true)
        let pcm = derived.appendingPathComponent("ModuleCache.noindex/UIKit.pcm")
        try FileManager.default.createDirectory(at: pcm.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 64).write(to: pcm)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-31 * 24 * 60 * 60)],
            ofItemAtPath: project.path
        )

        let result = service.scanProvider(category: .developer)

        XCTAssertTrue(result.candidates.contains {
            $0.pathDescription == derived.path && $0.provider == .projectArtifacts
        })
    }

    func testVolumeSummaryGapBytesMatchesTotalMinusAvailableMinusMeasured() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try createSparseFile(at: downloads.appendingPathComponent("large.bin"), size: 12_000_001)

        let summary = try XCTUnwrap(service.scanUnified().volumeSummary)
        let total = try XCTUnwrap(summary.totalBytes)
        let available = try XCTUnwrap(summary.availableBytes)

        XCTAssertEqual(summary.gapBytes, max(0, total - available - summary.measuredBytes))
    }

    func testUsrLocalIsMeasuredWhileOtherUsrChildrenStayProtected() throws {
        let usrLocal = fixtureRoot.appendingPathComponent("usr/local/lib", isDirectory: true)
        try FileManager.default.createDirectory(at: usrLocal, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 65_536).write(to: usrLocal.appendingPathComponent("libtool.a"))
        let usrBin = fixtureRoot.appendingPathComponent("usr/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: usrBin, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 65_536).write(to: usrBin.appendingPathComponent("tool"))

        let result = service.scanUnified()
        let summary = try XCTUnwrap(result.volumeSummary)
        let usr = try XCTUnwrap(summary.usageItems.first { $0.displayName == "usr" })

        XCTAssertEqual(usr.status, .measured)
        XCTAssertGreaterThanOrEqual(usr.byteSize ?? 0, 65_536)
        XCTAssertTrue(summary.usageItems.contains { $0.displayName == "bin" && $0.isProtected })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription == usrLocal.appendingPathComponent("libtool.a").path })
    }

    func testExcludedPathIsUnselected() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/pip", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 32).write(to: cache.appendingPathComponent("entry.data"))
        service.addExclusion(for: cache)

        let result = service.scanProvider(category: .routine)

        XCTAssertEqual(result.candidates.first(where: { $0.pathDescription == cache.path })?.isSelected, false)
    }

    func testRoutineCacheWithoutTrashPermissionIsProtected() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        let cacheParent = cache.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 32).write(to: cache.appendingPathComponent("cache.data"))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: cacheParent.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cacheParent.path) }

        let result = service.scanProvider(category: .routine)
        let candidate = result.candidates.first { $0.pathDescription == cache.path }

        XCTAssertEqual(candidate?.risk, .protected)
        XCTAssertEqual(candidate?.isSelected, false)
        XCTAssertEqual(candidate?.protectionReason, .key(.cleanupNoTrashPermission))
    }

    func testRoutineCacheSizeChangeReportsRescanReason() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("before".utf8).write(to: cache.appendingPathComponent("cache.data"))

        let candidate = try XCTUnwrap(service.scanProvider(category: .routine).candidates.first { $0.pathDescription == cache.path })
        try Data("after-the-scan".utf8).write(to: cache.appendingPathComponent("cache.data"))

        let summary = service.execute(
            plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]),
            cancellation: CancellationToken()
        ) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .failed)
        XCTAssertTrue(summary.results.first?.message.requiresRescan == true)
        XCTAssertEqual(summary.results.first?.message, .failure(.candidateChanged(cache.path)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
    }

    func testRoutineCacheReplacementWithSameSizeReportsRescanReason() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        let replacement = fixtureRoot.appendingPathComponent("replacement-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("same".utf8).write(to: cache.appendingPathComponent("cache.data"))

        let candidate = try XCTUnwrap(service.scanProvider(category: .routine).candidates.first { $0.pathDescription == cache.path })
        XCTAssertNotNil(candidate.fileIdentity)

        try FileManager.default.moveItem(at: cache, to: replacement)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("same".utf8).write(to: cache.appendingPathComponent("cache.data"))

        let summary = service.execute(
            plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]),
            cancellation: CancellationToken()
        ) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .failed)
        XCTAssertTrue(summary.results.first?.message.requiresRescan == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacement.path))
    }

    func testSymlinkIsNotScanned() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let target = downloads.appendingPathComponent("target.bin")
        try createSparseFile(at: target, size: 200_000_001)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)], ofItemAtPath: target.path)
        let link = downloads.appendingPathComponent("linked.bin")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let result = service.scanProvider(category: .analysis)

        XCTAssertTrue(result.candidates.contains { $0.displayName == "target.bin" })
        XCTAssertFalse(result.candidates.contains { $0.displayName == "linked.bin" })
    }

    func testAnalysisCandidateUsesTrashOutcome() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let filename = "spotless-trash-\(UUID().uuidString).txt"
        let file = downloads.appendingPathComponent(filename)
        try Data("test".utf8).write(to: file)
        let candidate = CleanupCandidate(
            url: file,
            provider: .spaceAnalysis,
            category: .analysis,
            displayName: filename,
            byteSize: 4,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .trash,
            source: .raw("测试"),
            isSelected: true
        )

        let summary = service.execute(plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]), cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .movedToTrash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let trashFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash").appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: trashFile)
    }

    func testArbitraryPathFailsClosed() {
        let candidate = CleanupCandidate(
            url: URL(fileURLWithPath: "/tmp/not-an-allowed-path"),
            provider: .projectArtifacts,
            category: .developer,
            displayName: "outside",
            byteSize: nil,
            modifiedAt: nil,
            risk: .review,
            removalMode: .trash,
            source: .raw("测试"),
            isSelected: true
        )

        let summary = service.execute(plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]), cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .failed)
    }

    func testAnalysisCandidateOutsideDownloadsCanMoveToTrash() throws {
        let file = fixtureRoot.appendingPathComponent("Documents/movie.bin")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("test".utf8).write(to: file)
        let candidate = CleanupCandidate(
            url: file,
            provider: .spaceAnalysis,
            category: .analysis,
            displayName: file.lastPathComponent,
            byteSize: 4,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .trash,
            source: .raw("测试"),
            isSelected: true
        )

        let summary = service.execute(plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]), cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .movedToTrash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let trashFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash").appendingPathComponent(file.lastPathComponent)
        try? FileManager.default.removeItem(at: trashFile)
    }

    func testAnalysisCandidateFailsWhenSizeChanged() throws {
        let file = fixtureRoot.appendingPathComponent("Documents/movie.bin")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("changed-size".utf8).write(to: file)
        let candidate = CleanupCandidate(
            url: file,
            provider: .spaceAnalysis,
            category: .analysis,
            displayName: file.lastPathComponent,
            byteSize: 4,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .trash,
            source: .raw("测试"),
            isSelected: true
        )

        let summary = service.execute(plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]), cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .failed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try? FileManager.default.removeItem(at: file)
    }

    func testKnownTrashPermissionErrorUsesApplicationLocale() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.Code.fileWriteNoPermission.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "未能将项目移到废纸篓，因为你没有访问权限"]
        )

        XCTAssertEqual(
            CleanupErrorMessage.localized(error, locale: Locale(identifier: "en")),
            L10n.resolve(.cleanupTrashPermissionRetry, locale: Locale(identifier: "en"))
        )
        XCTAssertEqual(
            CleanupErrorMessage.localized(error, locale: Locale(identifier: "zh-Hans")),
            L10n.resolve(.cleanupTrashPermissionRetry, locale: Locale(identifier: "zh-Hans"))
        )
    }

    func testCancelledAnalysisIsPartial() {
        let token = CancellationToken()
        token.cancel()

        let result = service.scanProvider(category: .analysis, cancellation: token)

        XCTAssertTrue(result.isPartial)
        XCTAssertTrue(result.diagnostics.contains { $0.isWarning })
    }

    func testProtectedCandidateCannotBeSelected() {
        let candidate = CleanupCandidate(
            url: URL(fileURLWithPath: "/System/Library/Unsafe"),
            provider: .deepCleanup,
            category: .routine,
            displayName: "受保护项",
            byteSize: nil,
            modifiedAt: nil,
            risk: .protected,
            removalMode: .trash,
            source: .raw("测试"),
            protectionReason: .raw("系统路径"),
            isSelected: false
        )

        XCTAssertTrue(candidate.isProtected)
        XCTAssertFalse(candidate.isEligible)
    }

    func testConfirmedSnapshotIsValueBased() {
        var candidate = CleanupCandidate(
            url: fixtureRoot.appendingPathComponent("Projects/App/node_modules"),
            provider: .projectArtifacts,
            category: .developer,
            displayName: "node_modules",
            byteSize: 1,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .trash,
            source: .raw("测试"),
            isSelected: true
        )
        let confirmed = CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate])
        candidate.isSelected = false

        XCTAssertTrue(confirmed.selectedCandidates[0].isSelected)
        XCTAssertFalse(candidate.isSelected)
    }

    @MainActor
    func testDirectTrashActionStartsCleanupWithoutConfirmation() throws {
        let file = fixtureRoot.appendingPathComponent("Documents/direct-trash.txt")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep me".utf8).write(to: file)

        let candidate = CleanupCandidate(
            url: file,
            provider: .spaceAnalysis,
            category: .analysis,
            displayName: file.lastPathComponent,
            byteSize: 7,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .trash,
            source: .raw("测试"),
            isSelected: true
        )
        let viewModel = CleanerViewModel(service: service)
        viewModel.candidates = [candidate]
        viewModel.appState = .awaitingConfirmation

        viewModel.executeSelectedCandidates()

        XCTAssertTrue(viewModel.isCleaning)
        XCTAssertEqual(viewModel.appState, .applying)

        let deadline = Date().addingTimeInterval(5)
        while viewModel.isCleaning && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertFalse(viewModel.isCleaning)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let trashFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash").appendingPathComponent(file.lastPathComponent)
        try? FileManager.default.removeItem(at: trashFile)
    }

    func testCancellationProducesCancelledResultAndOrderedEvents() {
        let candidate = CleanupCandidate(
            url: nil,
            provider: .spaceAnalysis,
            category: .analysis,
            displayName: "快照",
            byteSize: nil,
            modifiedAt: nil,
            risk: .advanced,
            removalMode: .timeMachine,
            source: .raw("测试"),
            isSelected: true
        )
        let token = CancellationToken()
        token.cancel()
        let collector = EventCollector()

        let summary = service.execute(plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]), cancellation: token, emit: { @Sendable event in
            collector.append(event)
        })
        let events = collector.events

        XCTAssertEqual(summary.results.first?.outcome, .cancelled)
        if case .finished = events.last {
            XCTAssertTrue(true)
        } else {
            XCTFail("finished must be the final event")
        }
    }

    func testPrivilegedAuthorizationFailureIsReportedPerCandidate() throws {
        let systemCache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: systemCache, withIntermediateDirectories: true)
        let failingService = CleanerService(
            homeDirectory: fixtureRoot,
            userDefaults: defaults,
            privilegedRunner: { _ in throw CleanerError.userCancelled }
        )
        let candidate = CleanupCandidate(
            url: systemCache,
            provider: .deepCleanup,
            category: .routine,
            displayName: "系统缓存",
            byteSize: nil,
            modifiedAt: Date(),
            risk: .safe,
            removalMode: .privilegedTrash,
            source: .raw("测试"),
            isSelected: true
        )

        let summary = failingService.execute(plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]), cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .cancelled)
    }

    func testPrivilegedTrashReportsTrashOutcome() throws {
        let systemCache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: systemCache, withIntermediateDirectories: true)
        let candidateID = UUID()
        let privilegedService = CleanerService(
            homeDirectory: fixtureRoot,
            userDefaults: defaults,
            privilegedRunner: { _ in "__SPOTLESS_OK__|\(candidateID.uuidString)" }
        )
        let candidate = CleanupCandidate(
            id: candidateID,
            url: systemCache,
            provider: .deepCleanup,
            category: .routine,
            displayName: "系统缓存",
            byteSize: nil,
            modifiedAt: Date(),
            risk: .safe,
            removalMode: .privilegedTrash,
            source: .raw("测试"),
            isSelected: true
        )

        let summary = privilegedService.execute(plan: CleanupPlan(selectedCandidates: [candidate], allCandidates: [candidate]), cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .movedToTrash)
        XCTAssertTrue(FileManager.default.fileExists(atPath: systemCache.path))
    }

    private func createSparseFile(at url: URL, size: UInt64) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seek(toOffset: size)
        try handle.write(contentsOf: Data([0]))
        try handle.close()
    }

    private func writeBundleInfo(at url: URL, identifier: String) throws {
        let plist: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundlePackageType": "APPL",
            "CFBundleName": identifier
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
    }
}
