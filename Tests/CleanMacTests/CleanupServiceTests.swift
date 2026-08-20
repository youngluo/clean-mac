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

    override func setUpWithError() throws {
        fixtureRoot = FileManager.default.temporaryDirectory.appendingPathComponent("CleanMacTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defaultsName = "CleanMacTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsName)!
        service = CleanerService(homeDirectory: fixtureRoot, userDefaults: defaults)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fixtureRoot)
        defaults.removePersistentDomain(forName: defaultsName)
    }

    func testAnalysisFindsOnlyOldLargeDownloads() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let oldLarge = downloads.appendingPathComponent("old-large.bin")
        try createSparseFile(at: oldLarge, size: 200_000_001)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)], ofItemAtPath: oldLarge.path)

        let recentLarge = downloads.appendingPathComponent("recent-large.bin")
        try createSparseFile(at: recentLarge, size: 200_000_001)

        let result = service.scan(category: .analysis)

        XCTAssertEqual(result.candidates.map(\.displayName), ["old-large.bin"])
        XCTAssertEqual(result.candidates.first?.risk, .review)
        XCTAssertEqual(result.candidates.first?.removalMode, .trash)
        XCTAssertFalse(result.candidates.first?.isSelected ?? true)
    }

    func testRecentDeveloperArtifactIsNotProposed() throws {
        let artifact = fixtureRoot.appendingPathComponent("Projects/App/node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)

        let result = service.scan(category: .developer)

        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testOldDeveloperArtifactIsProposed() throws {
        let artifact = fixtureRoot.appendingPathComponent("Projects/App/node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        let oldDate = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: artifact.deletingLastPathComponent().path)

        let result = service.scan(category: .developer)

        XCTAssertTrue(result.candidates.contains { $0.displayName == "node_modules" })
        XCTAssertTrue(result.candidates.allSatisfy { $0.risk == .review || $0.risk == .safe })
    }

    func testExcludedPathIsUnselected() throws {
        let cache = fixtureRoot.appendingPathComponent("Library/Caches/pip", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        service.addExclusion(for: cache)

        let result = service.scan(category: .routine)

        XCTAssertEqual(result.candidates.first(where: { $0.pathDescription == cache.path })?.isSelected, false)
    }

    func testSymlinkIsNotScanned() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let target = downloads.appendingPathComponent("target.bin")
        try createSparseFile(at: target, size: 200_000_001)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-8 * 24 * 60 * 60)], ofItemAtPath: target.path)
        let link = downloads.appendingPathComponent("linked.bin")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let result = service.scan(category: .analysis)

        XCTAssertEqual(result.candidates.map(\.displayName), ["target.bin"])
    }

    func testPermanentRemovalIsBoundedToDeveloperArtifacts() throws {
        let artifact = fixtureRoot.appendingPathComponent("Projects/App/node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        let candidate = CleanupCandidate(
            url: artifact,
            category: .developer,
            displayName: "node_modules",
            byteSize: nil,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .permanent,
            source: "测试",
            isSelected: true
        )

        let summary = service.apply(selected: [candidate], allCandidates: [candidate], cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .removed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: artifact.path))
    }

    func testAnalysisCandidateUsesTrashOutcome() throws {
        let downloads = fixtureRoot.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let filename = "cleanmac-trash-\(UUID().uuidString).txt"
        let file = downloads.appendingPathComponent(filename)
        try Data("test".utf8).write(to: file)
        let candidate = CleanupCandidate(
            url: file,
            category: .analysis,
            displayName: filename,
            byteSize: 4,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .trash,
            source: "测试",
            isSelected: true
        )

        let summary = service.apply(selected: [candidate], allCandidates: [candidate], cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .movedToTrash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let trashFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash").appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: trashFile)
    }

    func testArbitraryPathFailsClosed() {
        let candidate = CleanupCandidate(
            url: URL(fileURLWithPath: "/tmp/not-an-allowed-path"),
            category: .developer,
            displayName: "outside",
            byteSize: nil,
            modifiedAt: nil,
            risk: .review,
            removalMode: .permanent,
            source: "测试",
            isSelected: true
        )

        let summary = service.apply(selected: [candidate], allCandidates: [candidate], cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .failed)
    }

    func testProtectedCandidateCannotBeSelected() {
        let candidate = CleanupCandidate(
            url: URL(fileURLWithPath: "/System/Library/Unsafe"),
            category: .routine,
            displayName: "受保护项",
            byteSize: nil,
            modifiedAt: nil,
            risk: .protected,
            removalMode: .permanent,
            source: "测试",
            protectionReason: "系统路径",
            isSelected: false
        )

        XCTAssertTrue(candidate.isProtected)
        XCTAssertFalse(candidate.isEligible)
    }

    func testConfirmedSnapshotIsValueBased() {
        var candidate = CleanupCandidate(
            url: fixtureRoot.appendingPathComponent("Projects/App/node_modules"),
            category: .developer,
            displayName: "node_modules",
            byteSize: 1,
            modifiedAt: Date(),
            risk: .review,
            removalMode: .permanent,
            source: "测试",
            isSelected: true
        )
        let confirmed = [candidate]
        candidate.isSelected = false

        XCTAssertTrue(confirmed[0].isSelected)
        XCTAssertFalse(candidate.isSelected)
    }

    func testCancellationProducesCancelledResultAndOrderedEvents() {
        let candidate = CleanupCandidate(
            url: nil,
            category: .timeMachine,
            displayName: "快照",
            byteSize: nil,
            modifiedAt: nil,
            risk: .advanced,
            removalMode: .timeMachine,
            source: "测试",
            isSelected: true
        )
        let token = CancellationToken()
        token.cancel()
        let collector = EventCollector()

        let summary = service.apply(selected: [candidate], allCandidates: [candidate], cancellation: token, emit: { @Sendable event in
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
            category: .routine,
            displayName: "系统缓存",
            byteSize: nil,
            modifiedAt: Date(),
            risk: .safe,
            removalMode: .privilegedPermanent,
            source: "测试",
            isSelected: true
        )

        let summary = failingService.apply(selected: [candidate], allCandidates: [candidate], cancellation: CancellationToken()) { _ in }

        XCTAssertEqual(summary.results.first?.outcome, .cancelled)
    }

    private func createSparseFile(at url: URL, size: UInt64) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seek(toOffset: size)
        try handle.write(contentsOf: Data([0]))
        try handle.close()
    }
}
