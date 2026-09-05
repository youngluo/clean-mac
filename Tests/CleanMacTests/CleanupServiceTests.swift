import XCTest
@testable import CleanMac

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
        fixtureRoot = FileManager.default.temporaryDirectory.appendingPathComponent("CleanMacTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defaultsName = "CleanMacTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsName)!
        service = CleanerService(
            homeDirectory: fixtureRoot,
            startupVolumeURL: fixtureRoot,
            userDefaults: defaults
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
        XCTAssertGreaterThanOrEqual(
            result.volumeSummary?.usageItems.first(where: { $0.displayName == "Downloads" })?.byteSize ?? 0,
            200_000_001
        )
        XCTAssertFalse(result.volumeSummary?.usageItems.isEmpty ?? true)
    }

    func testAnalysisFindsFilesBelowPreviousThreshold() throws {
        let documents = fixtureRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let smallFile = documents.appendingPathComponent("small.txt")
        try Data("small".utf8).write(to: smallFile)

        let result = service.scanProvider(category: .analysis)

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == smallFile.path })
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
        let output = "Snapshots for disk /:\ncom.apple.TimeMachine.2026-09-05-120000\n"

        XCTAssertEqual(
            CleanerService.localSnapshotEntries(from: output),
            ["com.apple.TimeMachine.2026-09-05-120000"]
        )
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

    func testAnalysisExcludesPhotosAppAndPhotoDirectories() throws {
        let photosAppData = fixtureRoot.appendingPathComponent("Applications/Photos.app/Contents/Resources/library.data")
        try FileManager.default.createDirectory(at: photosAppData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: photosAppData, size: 200_000_001)

        let installedAppData = fixtureRoot.appendingPathComponent("Applications/Example.app/Contents/Resources/app.data")
        try FileManager.default.createDirectory(at: installedAppData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: installedAppData, size: 200_000_001)

        let photoDirectoryData = fixtureRoot.appendingPathComponent("Library/Photos/originals/photo.data")
        try FileManager.default.createDirectory(at: photoDirectoryData.deletingLastPathComponent(), withIntermediateDirectories: true)
        try createSparseFile(at: photoDirectoryData, size: 200_000_001)

        let result = service.scanProvider(category: .analysis)

        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("Photos.app") })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("Example.app") })
        XCTAssertFalse(result.candidates.contains { $0.pathDescription.contains("/Photos/") })
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
        XCTAssertFalse(result.volumeSummary?.usageItems.contains { $0.url.path.contains("Music Library.musiclibrary") } ?? false)
        XCTAssertFalse(result.diagnostics.contains { rendered($0.message).contains("Music Library.musiclibrary") })
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

        XCTAssertEqual(result.candidates.count, 502)
        XCTAssertFalse(result.isPartial)
        XCTAssertFalse(result.diagnostics.contains { rendered($0.message).contains("仅展示占用最大") })
        XCTAssertTrue(zip(result.candidates, result.candidates.dropFirst()).allSatisfy { left, right in
            (left.byteSize ?? 0) >= (right.byteSize ?? 0)
        })
    }

    func testUnifiedScanOrdersProvidersAndKeepsEligibleCandidatesSelectable() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)

        let application = fixtureRoot.appendingPathComponent("Applications/Example.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        try writeBundleInfo(at: application.appendingPathComponent("Info.plist"), identifier: "com.example.app")

        let leftover = fixtureRoot.appendingPathComponent("Library/Application Support/com.example.removed", isDirectory: true)
        try FileManager.default.createDirectory(at: leftover, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 32).write(to: leftover.appendingPathComponent("state.data"))

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
        let result = service.scanUnified { event in collector.append(event) }
        let providerOrder = result.providers.map(\.provider)

        XCTAssertEqual(providerOrder, [.deepCleanup, .projectArtifacts, .applications, .spaceAnalysis])
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == cache.path })
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == cache.path && $0.provider == .deepCleanup })
        XCTAssertFalse(result.eligibleCandidates.contains { $0.pathDescription == application.deletingLastPathComponent().path })
        XCTAssertTrue(result.eligibleCandidates.contains { $0.pathDescription == leftover.path && $0.provider == .applications })
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

    func testUninstalledApplicationPreferenceAndExpandedRootAreProposed() throws {
        let preference = fixtureRoot.appendingPathComponent("Library/Preferences/com.example.removed.plist")
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("preference".utf8).write(to: preference)

        let storage = fixtureRoot.appendingPathComponent("Library/HTTPStorages/com.example.removed", isDirectory: true)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        try Data("storage".utf8).write(to: storage.appendingPathComponent("cache.data"))

        let result = service.scanUnified()

        XCTAssertTrue(result.candidates.contains { $0.pathDescription == preference.path && $0.provider == .applications })
        XCTAssertTrue(result.candidates.contains { $0.pathDescription == storage.path && $0.provider == .applications })
        XCTAssertTrue(result.candidates.filter { $0.provider == .applications }.allSatisfy { !$0.isSelected })
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

    func testProjectArtifactStopsNestedCandidateTraversalAndUsesAggregateSize() throws {
        let project = fixtureRoot.appendingPathComponent("Projects/WebApp", isDirectory: true)
        let next = project.appendingPathComponent(".next", isDirectory: true)
        let nestedBuild = next.appendingPathComponent("cache/build", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedBuild, withIntermediateDirectories: true)
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

    func testExcludedPathIsUnselected() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/pip", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        service.addExclusion(for: cache)

        let result = service.scanProvider(category: .routine)

        XCTAssertEqual(result.candidates.first(where: { $0.pathDescription == cache.path })?.isSelected, false)
    }

    func testRoutineCacheWithoutTrashPermissionIsProtected() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        let cacheParent = cache.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
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
        let filename = "cleanmac-trash-\(UUID().uuidString).txt"
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
        let file = fixtureRoot.appendingPathComponent("Movies/movie.bin")
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
        let file = fixtureRoot.appendingPathComponent("Movies/movie.bin")
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
            privilegedRunner: { _ in "__CLEANMAC_OK__|\(candidateID.uuidString)" }
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
