import Foundation

private struct CacheRootPolicy {
    let relativePath: String
    let source: String
    let isSelectedByDefault: Bool
}

private final class ScanCounter: @unchecked Sendable {
    private let progressCheckStride = 32
    private let minimumReportIntervalNanoseconds: UInt64 = 150_000_000

    let provider: CleanupProvider
    let category: CleanupCategory
    let emit: @Sendable (CleanupEvent) -> Void
    private(set) var count = 0
    private var hasReported = false
    private var lastReportUptimeNanoseconds = DispatchTime.now().uptimeNanoseconds

    init(
        provider: CleanupProvider,
        category: CleanupCategory,
        emit: @escaping @Sendable (CleanupEvent) -> Void
    ) {
        self.provider = provider
        self.category = category
        self.emit = emit
    }

    func record(stage: String, diagnosticsCount: Int = 0) {
        count += 1
        guard !hasReported || count.isMultiple(of: progressCheckStride) else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        guard !hasReported || now &- lastReportUptimeNanoseconds >= minimumReportIntervalNanoseconds else {
            return
        }
        report(stage: stage, diagnosticsCount: diagnosticsCount, at: now)
    }

    func report(stage: String, diagnosticsCount: Int = 0) {
        report(stage: stage, diagnosticsCount: diagnosticsCount, at: DispatchTime.now().uptimeNanoseconds)
    }

    private func report(stage: String, diagnosticsCount: Int, at now: UInt64) {
        emit(.scanProgress(ScanProgress(
            category: category,
            stage: stage,
            processedEntries: count,
            estimatedEntries: nil,
            diagnosticsCount: diagnosticsCount,
            provider: provider
        )))
        hasReported = true
        lastReportUptimeNanoseconds = now
    }
}

final class CleanerService: @unchecked Sendable {
    private let homeDirectory: URL
    private let startupVolumeURL: URL
    private let fileManager: FileManager
    private let privilegedRunner: (@Sendable (String) throws -> String)?
    private let diskAccessService: DiskAccessService
    private let historyStore: CleanupHistoryStore
    private let exclusionStore: CleanupExclusionStore
    private let staleInterval: TimeInterval = 7 * 24 * 60 * 60
    private let projectStaleInterval: TimeInterval = 30 * 24 * 60 * 60
    private let analysisValidationEntryLimit = 100_000
    private let analysisTimeout: TimeInterval
    private let analysisExcludedComponents: Set<String> = [
        "music.app",
        "photos.app",
        "pictures",
        "music",
        "movies",
        "photos",
        "photo library",
        "music library",
        "photo booth library",
        "itunes library.itl",
        "itunes library.xml"
    ]
    private let analysisExcludedComponentPrefixes = ["com.apple.", "group.com.apple."]
    private let analysisExcludedSuffixes = [".app", ".photoslibrary", ".photolibrary", ".musiclibrary"]

    private var userCachePolicies: [CacheRootPolicy] {
        [
            CacheRootPolicy(relativePath: "Library/Caches/com.apple.Safari", source: "Safari 缓存", isSelectedByDefault: true),
            CacheRootPolicy(relativePath: "Library/Caches/com.apple.dt.Xcode", source: "Xcode 缓存", isSelectedByDefault: true),
            CacheRootPolicy(relativePath: "Library/Caches/pip", source: "pip 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: ".npm/_cacache", source: "npm 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "Library/pnpm/store", source: "pnpm Store", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "Library/Caches/Homebrew", source: "Homebrew 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "Library/Developer/Xcode/DerivedData", source: "Xcode DerivedData", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "Library/Caches/CocoaPods", source: "CocoaPods 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "Library/Caches/org.swift.swiftpm", source: "SwiftPM 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "Library/Caches/Yarn", source: "Yarn 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: ".cache/yarn", source: "Yarn 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: ".yarn/berry/cache", source: "Yarn Berry 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: ".bun/install/cache", source: "Bun 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: ".cargo/registry/cache", source: "Cargo Registry 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: ".cargo/git/db", source: "Cargo Git 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: ".gradle/caches", source: "Gradle 缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "Library/Caches/go-build", source: "Go 构建缓存", isSelectedByDefault: false),
            CacheRootPolicy(relativePath: "go/pkg/mod/cache/download", source: "Go 模块下载缓存", isSelectedByDefault: false)
        ]
    }

    private var projectRoots: [URL] {
        ["Projects", "GitHub", "dev", "Work", "Documents"].map {
            homeDirectory.appendingPathComponent($0, isDirectory: true)
        }
    }

    private var applicationLeftoverRoots: [URL] {
        [
            "Library/Application Support",
            "Library/Preferences",
            "Library/Caches",
            "Library/Containers",
            "Library/Saved Application State",
            "Library/WebKit",
            "Library/HTTPStorages",
            "Library/Application Scripts"
        ].map { homeDirectory.appendingPathComponent($0, isDirectory: true) }
    }

    init(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        startupVolumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true),
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        privilegedRunner: (@Sendable (String) throws -> String)? = nil,
        analysisTimeout: TimeInterval = 180,
        fullDiskAccessProbeURL: URL = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
    ) {
        self.homeDirectory = homeDirectory.standardizedFileURL
        self.startupVolumeURL = startupVolumeURL.standardizedFileURL
        self.fileManager = fileManager
        self.privilegedRunner = privilegedRunner
        self.analysisTimeout = analysisTimeout
        self.diskAccessService = DiskAccessService(
            startupVolumeURL: startupVolumeURL,
            fileManager: fileManager,
            fullDiskAccessProbeURL: fullDiskAccessProbeURL
        )
        self.historyStore = CleanupHistoryStore(homeDirectory: homeDirectory, fileManager: fileManager)
        self.exclusionStore = CleanupExclusionStore(userDefaults: userDefaults)
    }

    // MARK: - Scanning

    func scanProvider(
        category: CleanupCategory,
        cancellation: CancellationToken = CancellationToken(),
        emit: @escaping @Sendable (CleanupEvent) -> Void = { _ in },
        provider: CleanupProvider? = nil
    ) -> ScanResult {
        let resolvedProvider: CleanupProvider
        switch category {
        case .routine:
            resolvedProvider = provider ?? .deepCleanup
        case .analysis:
            resolvedProvider = provider ?? .spaceAnalysis
        case .developer:
            resolvedProvider = provider ?? .projectArtifacts
        }
        let scanCounter = ScanCounter(provider: resolvedProvider, category: category, emit: emit)
        return scanProvider(
            category: category,
            cancellation: cancellation,
            emit: emit,
            scanCounter: scanCounter
        )
    }

    private func scanProvider(
        category: CleanupCategory,
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void,
        scanCounter: ScanCounter
    ) -> ScanResult {
        var candidates: [CleanupCandidate] = []
        var diagnostics: [ScanDiagnostic] = []

        guard !cancellation.isCancelled else {
            let diagnostic = ScanDiagnostic(category: category, message: "扫描在开始前已取消", isWarning: true)
            return ScanResult(category: category, candidates: [], diagnostics: [diagnostic], scannedCount: 0, isPartial: true)
        }

        if category == .analysis {
            let volumeResult = scanStartupVolume(cancellation: cancellation, emit: emit, scanCounter: scanCounter)
            var candidates = volumeResult.candidates
            var diagnostics = volumeResult.diagnostics

            // Time Machine 是大文件扫描的一部分，和启动磁盘分析一起检查，避免用户在两个入口之间做选择。
            if startupVolumeURL.path == "/" && !cancellation.isCancelled {
                scanTimeMachine(into: &candidates, diagnostics: &diagnostics, category: .analysis, cancellation: cancellation, emit: emit)
            }

            let timeMachineCount = candidates.count - volumeResult.candidates.count
            let volumeSummary = volumeResult.volumeSummary.map { summary in
                VolumeAnalysisSummary(
                    volumeURL: summary.volumeURL,
                    volumeName: summary.volumeName,
                    totalBytes: summary.totalBytes,
                    availableBytes: summary.availableBytes,
                    measuredBytes: summary.measuredBytes,
                    usageItems: summary.usageItems,
                    processedEntryCount: summary.processedEntryCount,
                    candidateCount: summary.candidateCount + timeMachineCount,
                    isPartial: summary.isPartial
                )
            }

            return ScanResult(
                category: .analysis,
                candidates: candidates,
                diagnostics: diagnostics,
                scannedCount: scanCounter.count,
                isPartial: volumeResult.isPartial,
                volumeSummary: volumeSummary
            )
        }

        switch category {
        case .routine:
            scanRoutine(into: &candidates, diagnostics: &diagnostics, cancellation: cancellation, emit: emit, scanCounter: scanCounter)
        case .analysis:
            break
        case .developer:
            scanDeveloper(into: &candidates, diagnostics: &diagnostics, cancellation: cancellation, emit: emit, scanCounter: scanCounter)
        }

        scanCounter.report(stage: "扫描完成", diagnosticsCount: diagnostics.count)

        return ScanResult(
            category: category,
            candidates: candidates.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending },
            diagnostics: diagnostics,
            scannedCount: scanCounter.count
        )
    }

    func scanUnified(
        cancellation: CancellationToken = CancellationToken(),
        emit: @escaping @Sendable (CleanupEvent) -> Void = { _ in }
    ) -> UnifiedScanResult {
        // 扫描期间候选列表不可见，逐项发送候选事件只会增加 AsyncStream 和主线程刷新压力。
        // 统一扫描完成时通过 unifiedScanFinished 一次性提交完整候选集合。
        let emitProviderEvent: @Sendable (CleanupEvent) -> Void = { event in
            if case .candidateDiscovered = event { return }
            emit(event)
        }
        var candidates: [CleanupCandidate] = []
        var diagnostics: [ScanDiagnostic] = []
        var providers: [CleanupProviderStatus] = []
        var volumeSummary: VolumeAnalysisSummary?
        var isPartial = false
        var scannedCount = 0

        func append(_ provider: CleanupProvider, _ result: ScanResult) {
            candidates.append(contentsOf: result.candidates)
            diagnostics.append(contentsOf: result.diagnostics)
            scannedCount += result.scannedCount
            isPartial = isPartial || result.isPartial
            volumeSummary = result.volumeSummary ?? volumeSummary
            let status = CleanupProviderStatus(
                provider: provider,
                outcome: result.isPartial ? .partial : .completed,
                candidateCount: result.candidates.count,
                candidateBytes: result.candidates.compactMap(\.byteSize).reduce(0, +),
                message: result.isPartial ? "部分完成" : nil
            )
            providers.append(status)
            emit(.providerStatus(status))
            emit(.scanProgress(ScanProgress(
                category: result.category,
                stage: provider.title,
                processedEntries: scannedCount,
                estimatedEntries: nil,
                diagnosticsCount: diagnostics.count,
                provider: provider
            )))
        }

        func startProvider(_ provider: CleanupProvider, category: CleanupCategory) {
            emit(.providerStatus(CleanupProviderStatus(provider: provider, outcome: .running, candidateCount: 0, message: nil)))
            emit(.scanProgress(ScanProgress(
                category: category,
                stage: provider.title,
                processedEntries: 0,
                estimatedEntries: nil,
                diagnosticsCount: diagnostics.count,
                provider: provider
            )))
        }

        guard !cancellation.isCancelled else {
            let diagnostic = ScanDiagnostic(category: .routine, message: "扫描在开始前已取消", isWarning: true)
            return UnifiedScanResult(candidates: [], diagnostics: [diagnostic], scannedCount: 0, isPartial: true, volumeSummary: nil, providers: [])
        }

        emit(.phase(.scanning, "正在扫描深度清理"))
        startProvider(.deepCleanup, category: .routine)
        append(.deepCleanup, scanProvider(category: .routine, cancellation: cancellation, emit: emitProviderEvent))

        guard !cancellation.isCancelled else {
            isPartial = true
            return UnifiedScanResult(candidates: candidates, diagnostics: diagnostics, scannedCount: scannedCount, isPartial: true, volumeSummary: volumeSummary, providers: providers)
        }

        emit(.phase(.scanning, "正在扫描项目构建产物"))
        startProvider(.projectArtifacts, category: .developer)
        append(.projectArtifacts, scanProvider(category: .developer, cancellation: cancellation, emit: emitProviderEvent))

        emit(.phase(.scanning, "正在扫描应用残留"))
        startProvider(.applications, category: .analysis)
        let applicationCounter = ScanCounter(provider: .applications, category: .analysis, emit: emitProviderEvent)
        append(.applications, scanApplicationLeftovers(cancellation: cancellation, emit: emitProviderEvent, scanCounter: applicationCounter))

        emit(.phase(.scanning, "正在进行大文件扫描"))
        startProvider(.spaceAnalysis, category: .analysis)
        append(.spaceAnalysis, scanSpaceAnalysis(cancellation: cancellation, emit: emitProviderEvent))

        let sortedCandidates = candidates.sorted {
            let leftSize = $0.byteSize ?? 0
            let rightSize = $1.byteSize ?? 0
            if leftSize != rightSize { return leftSize > rightSize }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
        return UnifiedScanResult(
            candidates: sortedCandidates,
            diagnostics: diagnostics,
            scannedCount: scannedCount,
            isPartial: isPartial || cancellation.isCancelled,
            volumeSummary: volumeSummary,
            providers: providers
        )
    }

    private func scanApplicationLeftovers(
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void,
        scanCounter: ScanCounter
    ) -> ScanResult {
        var candidates: [CleanupCandidate] = []
        var diagnostics: [ScanDiagnostic] = []
        let applicationRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
        var installedBundleIDs = Set<String>()

        for root in applicationRoots where fileManager.fileExists(atPath: root.path) {
            for appURL in directChildren(of: root, applyAnalysisExclusions: false, onItem: {
                scanCounter.record(stage: "查找已安装应用")
            }) where appURL.pathExtension == "app" {
                guard !cancellation.isCancelled else { break }
                guard let bundle = Bundle(url: appURL),
                      let bundleID = bundle.bundleIdentifier,
                      !bundleID.hasPrefix("com.apple.") else { continue }
                installedBundleIDs.insert(bundleID)
            }
        }

        for root in applicationLeftoverRoots where fileManager.fileExists(atPath: root.path) {
            for item in directChildren(of: root, onItem: {
                scanCounter.record(stage: "查找应用残留")
            }) {
                guard !cancellation.isCancelled else { break }
                guard let bundleID = leftoverBundleIdentifier(for: item) else { continue }
                guard !bundleID.hasPrefix("com.apple.") else { continue }
                guard !installedBundleIDs.contains(bundleID) else { continue }
                appendExisting(
                    item,
                    provider: .applications,
                    category: .analysis,
                    risk: .review,
                    removalMode: .trash,
                    source: "应用残留",
                    selected: false,
                    into: &candidates,
                    byteSize: isDirectory(item) ? aggregateDirectorySize(item, cancellation: cancellation, onItem: {
                        scanCounter.record(stage: "计算应用残留体积")
                    }) : nil,
                    emit: emit
                )
            }
        }

        if candidates.isEmpty {
            diagnostics.append(ScanDiagnostic(category: .analysis, message: "未发现已卸载的应用残留", isWarning: false))
        }
        scanCounter.report(stage: "扫描完成", diagnosticsCount: diagnostics.count)
        return ScanResult(category: .analysis, candidates: candidates, diagnostics: diagnostics, scannedCount: scanCounter.count)
    }

    private func scanInstallers(
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void,
        scanCounter: ScanCounter
    ) -> ScanResult {
        var candidates: [CleanupCandidate] = []
        var diagnostics: [ScanDiagnostic] = []
        let roots = [
            homeDirectory.appendingPathComponent("Downloads"),
            homeDirectory.appendingPathComponent("Desktop"),
            homeDirectory.appendingPathComponent("Documents")
        ]
        let extensions = Set(["dmg", "pkg", "mpkg", "xip", "ipsw"])
        for root in roots where fileManager.fileExists(atPath: root.path) {
            for file in filesUnder(root, cancellation: cancellation, onItem: {
                scanCounter.record(stage: "查找安装包")
            }) where extensions.contains(file.pathExtension.lowercased()) {
                guard !cancellation.isCancelled else { break }
                appendExisting(
                    file,
                    provider: .spaceAnalysis,
                    category: .analysis,
                    risk: .review,
                    removalMode: .trash,
                    source: "安装包",
                    selected: false,
                    into: &candidates,
                    emit: emit
                )
            }
        }
        if candidates.isEmpty {
            diagnostics.append(ScanDiagnostic(category: .analysis, message: "未发现可确认的安装包", isWarning: false))
        }
        return ScanResult(category: .analysis, candidates: candidates, diagnostics: diagnostics, scannedCount: scanCounter.count)
    }

    private func scanSpaceAnalysis(
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void
    ) -> ScanResult {
        emit(.phase(.scanning, "正在查找安装包"))
        let scanCounter = ScanCounter(provider: .spaceAnalysis, category: .analysis, emit: emit)
        let installerResult = scanInstallers(cancellation: cancellation, emit: emit, scanCounter: scanCounter)

        emit(.phase(.scanning, "正在分析启动磁盘和 Time Machine"))
        let volumeResult = scanProvider(category: .analysis, cancellation: cancellation, emit: emit, scanCounter: scanCounter)
        let candidates = (installerResult.candidates + volumeResult.candidates).sorted {
            if $0.byteSize != $1.byteSize { return ($0.byteSize ?? 0) > ($1.byteSize ?? 0) }
            return $0.pathDescription.localizedStandardCompare($1.pathDescription) == .orderedAscending
        }
        let volumeSummary = volumeResult.volumeSummary.map { summary in
            VolumeAnalysisSummary(
                volumeURL: summary.volumeURL,
                volumeName: summary.volumeName,
                totalBytes: summary.totalBytes,
                availableBytes: summary.availableBytes,
                measuredBytes: summary.measuredBytes,
                usageItems: summary.usageItems,
                processedEntryCount: summary.processedEntryCount,
                candidateCount: summary.candidateCount + installerResult.candidates.count,
                isPartial: summary.isPartial || installerResult.isPartial
            )
        }
        return ScanResult(
            category: .analysis,
            candidates: candidates,
            diagnostics: installerResult.diagnostics + volumeResult.diagnostics,
            scannedCount: scanCounter.count,
            isPartial: installerResult.isPartial || volumeResult.isPartial,
            volumeSummary: volumeSummary
        )
    }

    private func looksLikeBundleIdentifier(_ name: String) -> Bool {
        let components = name.split(separator: ".")
        return components.count >= 2 && components.allSatisfy { !$0.isEmpty }
    }

    private func leftoverBundleIdentifier(for item: URL) -> String? {
        var name = item.lastPathComponent
        for suffix in [".savedState", ".plist"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
            break
        }
        return looksLikeBundleIdentifier(name) ? name : nil
    }

    private func scanRoutine(
        into candidates: inout [CleanupCandidate],
        diagnostics: inout [ScanDiagnostic],
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void,
        scanCounter: ScanCounter
    ) {
        for policy in userCachePolicies {
            guard !cancellation.isCancelled else { return }
            let root = homeDirectory.appendingPathComponent(policy.relativePath, isDirectory: true)
            guard fileManager.fileExists(atPath: root.path) else { continue }
            let byteSize = aggregateDirectorySize(root, cancellation: cancellation, applyAnalysisExclusions: false, onItem: {
                scanCounter.record(stage: "查找缓存与旧日志")
            })
            appendExisting(
                root,
                provider: .deepCleanup,
                category: .routine,
                risk: policy.isSelectedByDefault ? .safe : .review,
                removalMode: .trash,
                source: policy.source,
                selected: policy.isSelectedByDefault,
                into: &candidates,
                byteSize: byteSize,
                emit: emit
            )
        }

        let logRoot = homeDirectory.appendingPathComponent("Library/Logs")
        let cutoff = Date().addingTimeInterval(-staleInterval)
        for file in filesUnder(logRoot, modifiedBefore: cutoff, cancellation: cancellation, onItem: {
            scanCounter.record(stage: "查找缓存与旧日志")
        }) {
            appendExisting(
                file,
                provider: .deepCleanup,
                category: .routine,
                risk: .safe,
                removalMode: .trash,
                source: "用户旧日志",
                selected: true,
                into: &candidates,
                emit: emit
            )
        }

        let privilegedRoots = [
            (URL(fileURLWithPath: "/Library/Caches/com.apple.Safari"), "系统 Safari 缓存"),
            (URL(fileURLWithPath: "/Library/Caches/com.apple.dt.Xcode"), "系统 Xcode 缓存"),
            (URL(fileURLWithPath: "/private/var/log"), "系统旧日志")
        ]
        for (root, source) in privilegedRoots where fileManager.fileExists(atPath: root.path) {
            guard !cancellation.isCancelled else { return }
            if root.path == "/private/var/log" {
                for file in filesUnder(root, modifiedBefore: cutoff, cancellation: cancellation, onItem: {
                    scanCounter.record(stage: "查找缓存与旧日志")
                }) {
                    appendExisting(file, provider: .deepCleanup, category: .routine, risk: .safe, removalMode: .privilegedTrash, source: source, selected: false, into: &candidates, emit: emit)
                }
            } else {
                let byteSize = aggregateDirectorySize(root, cancellation: cancellation, applyAnalysisExclusions: false, onItem: {
                    scanCounter.record(stage: "查找缓存与旧日志")
                })
                appendExisting(root, provider: .deepCleanup, category: .routine, risk: .safe, removalMode: .privilegedTrash, source: source, selected: false, into: &candidates, byteSize: byteSize, emit: emit)
            }
        }

        diagnostics.append(ScanDiagnostic(category: .routine, message: "已扫描缓存与可安全刷新服务", isWarning: false))

        if candidates.isEmpty {
            diagnostics.append(ScanDiagnostic(category: .routine, message: "未发现符合条件的安全清理项", isWarning: false))
        }
    }

    private func scanStartupVolume(
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void,
        scanCounter: ScanCounter
    ) -> ScanResult {
        var candidates: [CleanupCandidate] = []
        var diagnostics: [ScanDiagnostic] = []
        let volumeKeys: Set<URLResourceKey> = [
            .volumeIsLocalKey,
            .volumeIsRemovableKey,
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]

        guard let values = try? startupVolumeURL.resourceValues(forKeys: volumeKeys),
              values.volumeIsLocal == true,
              values.volumeIsRemovable == false else {
            diagnostics.append(ScanDiagnostic(
                category: .analysis,
                message: "无法确认当前路径是本地、不可移除的启动磁盘",
                isWarning: true
            ))
            return ScanResult(
                category: .analysis,
                candidates: [],
                diagnostics: diagnostics,
                scannedCount: 0,
                isPartial: true
            )
        }

        let root = startupVolumeURL
        let totalBytes: Int64? = values.volumeTotalCapacity.map { Int64($0) }
        let availableBytes: Int64? = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map { Int64($0) }
        let volumeName = values.volumeName?.isEmpty == false ? values.volumeName! : "启动磁盘"
        let volumeStartCount = scanCounter.count
        let deadline = Date().addingTimeInterval(analysisTimeout)
        var usageByTopLevel: [String: Int64] = [:]
        var directorySizes: [String: Int64] = [:]
        var directoryDates: [String: Date] = [:]
        var protectedItems: [String: VolumeUsageItem] = [:]
        var unavailableItems: [String: VolumeUsageItem] = [:]
        var entriesSinceCheckpoint = 0
        var measuredBytes: Int64 = 0
        var isPartial = false

        scanCounter.report(stage: "读取启动磁盘信息", diagnosticsCount: diagnostics.count)
        scanCounter.report(stage: "遍历启动磁盘目录", diagnosticsCount: diagnostics.count)

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]
        var directoriesToVisit = [root]

        // 不使用从根目录递归的 FileManager.enumerator。它可能在路径过滤前
        // 触碰受 TCC 保护的 Photos Library，从而弹出照片权限请求。
        scanLoop: while let directory = directoriesToVisit.popLast() {
            // 目录入栈后再次检查，保证所有目录读取都经过同一条隐私边界。
            guard !isAnalysisExcludedPath(directory) else { continue }

            if cancellation.isCancelled {
                isPartial = true
                diagnostics.append(ScanDiagnostic(category: .analysis, message: "扫描已取消，已保留当前可读取结果", isWarning: true))
                break
            }
            if Date() > deadline {
                isPartial = true
                diagnostics.append(ScanDiagnostic(category: .analysis, message: "启动磁盘扫描达到时间上限，结果可能不完整", isWarning: true))
                break
            }

            guard let children = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: []
            ) else {
                isPartial = true
                let path = directory.standardizedFileURL.path
                if unavailableItems[path] == nil {
                    unavailableItems[path] = VolumeUsageItem(
                        url: directory.standardizedFileURL,
                        displayName: directory.lastPathComponent,
                        byteSize: nil,
                        status: .unavailable,
                        diagnostic: "无法读取目录"
                    )
                }
                if diagnostics.count < 100 {
                    diagnostics.append(ScanDiagnostic(
                        category: .analysis,
                        message: "无法读取 \(directory.path)",
                        isWarning: true
                    ))
                }
                continue
            }

            for url in children {
                entriesSinceCheckpoint += 1
                if entriesSinceCheckpoint >= 256 {
                    entriesSinceCheckpoint = 0
                    if cancellation.isCancelled {
                        isPartial = true
                        diagnostics.append(ScanDiagnostic(category: .analysis, message: "扫描已取消，已保留当前可读取结果", isWarning: true))
                        break scanLoop
                    }
                    if Date() > deadline {
                        isPartial = true
                        diagnostics.append(ScanDiagnostic(category: .analysis, message: "启动磁盘扫描达到时间上限，结果可能不完整", isWarning: true))
                        break scanLoop
                    }
                }

                // 必须在 resourceValues、sizeOfItem 和递归之前判断，避免触碰照片图库包。
                if isAnalysisExcludedPath(url) {
                    continue
                }

                guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
                    continue
                }

                if values.isSymbolicLink == true || !isOnVolume(url, root: root) {
                    continue
                }

                if isProtectedPath(url) || isStartupProtectedPath(url, root: root) {
                    let path = url.standardizedFileURL.path
                    if protectedItems[path] == nil {
                        protectedItems[path] = VolumeUsageItem(
                            url: url.standardizedFileURL,
                            displayName: url.lastPathComponent,
                            byteSize: values.fileSize.map { Int64($0) },
                            status: .protected,
                            isProtected: true,
                            diagnostic: "受保护路径，仅用于空间概览"
                        )
                    }
                    continue
                }

                let isDirectory = values.isDirectory == true
                if isDirectory {
                    directoriesToVisit.append(url)
                    continue
                }

                scanCounter.record(stage: "遍历启动磁盘目录", diagnosticsCount: diagnostics.count)
                if let size = values.fileSize.map({ Int64($0) }) {
                    measuredBytes += size
                    if let topLevel = topLevelComponent(for: url, root: root) {
                        usageByTopLevel[topLevel, default: 0] += size
                    }
                    accumulateDirectorySizes(
                        for: url.deletingLastPathComponent(),
                        size: size,
                        root: root,
                        directorySizes: &directorySizes,
                        directoryDates: &directoryDates
                    )

                    if isEligibleAnalysisCandidate(url, symbolicLink: values.isSymbolicLink), size > 0 {
                        let candidate = makeAnalysisCandidate(
                            url: url,
                            size: size,
                            modifiedAt: values.contentModificationDate,
                            provider: .spaceAnalysis,
                            source: "启动磁盘大文件"
                        )
                        candidates.append(candidate)
                        emit(.candidateDiscovered(candidate))
                    }
                }

            }
        }

        for (path, size) in directorySizes where size > 0 {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard isEligibleAnalysisCandidate(url), !isProtectedPath(url), !isStartupProtectedPath(url, root: root) else { continue }
            let candidate = makeAnalysisCandidate(
                url: url,
                size: size,
                modifiedAt: directoryDates[path],
                provider: .spaceAnalysis,
                source: "启动磁盘大目录"
            )
            candidates.append(candidate)
            emit(.candidateDiscovered(candidate))
        }

        var uniqueCandidates: [String: CleanupCandidate] = [:]
        for candidate in candidates {
            guard let path = candidate.url?.standardizedFileURL.path else { continue }
            if uniqueCandidates[path] == nil || (uniqueCandidates[path]?.byteSize ?? 0) < (candidate.byteSize ?? 0) {
                uniqueCandidates[path] = candidate
            }
        }
        candidates = uniqueCandidates.values.sorted {
            if $0.byteSize != $1.byteSize { return ($0.byteSize ?? 0) > ($1.byteSize ?? 0) }
            return $0.pathDescription.localizedStandardCompare($1.pathDescription) == .orderedAscending
        }
        if candidates.isEmpty && !isPartial {
            diagnostics.append(ScanDiagnostic(category: .analysis, message: "未发现可测量的用户文件或目录", isWarning: false))
        }

        let usageItems = usageByTopLevel.map { name, size in
            VolumeUsageItem(
                url: root.appendingPathComponent(name),
                displayName: name,
                byteSize: size,
                status: .measured
            )
        } + protectedItems.values + unavailableItems.values
        let volumeScannedCount = scanCounter.count - volumeStartCount
        let summary = VolumeAnalysisSummary(
            volumeURL: root,
            volumeName: volumeName,
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            measuredBytes: measuredBytes,
            usageItems: usageItems.sorted { ($0.byteSize ?? 0) > ($1.byteSize ?? 0) },
            processedEntryCount: volumeScannedCount,
            candidateCount: candidates.count,
            isPartial: isPartial
        )
        scanCounter.report(stage: isPartial ? "扫描部分完成" : "扫描完成", diagnosticsCount: diagnostics.count)

        return ScanResult(
            category: .analysis,
            candidates: candidates,
            diagnostics: diagnostics,
            scannedCount: volumeScannedCount,
            isPartial: isPartial,
            volumeSummary: summary
        )
    }

    private func makeAnalysisCandidate(
        url: URL,
        size: Int64,
        modifiedAt: Date? = nil,
        provider: CleanupProvider,
        source: String
    ) -> CleanupCandidate {
        CleanupCandidate(
            url: url.standardizedFileURL,
            provider: provider,
            category: .analysis,
            displayName: url.lastPathComponent,
            byteSize: size,
            modifiedAt: modifiedAt ?? modificationDate(for: url),
            risk: .review,
            removalMode: .trash,
            source: source,
            isSelected: false
        )
    }

    private func accumulateDirectorySizes(
        for directory: URL,
        size: Int64,
        root: URL,
        directorySizes: inout [String: Int64],
        directoryDates: inout [String: Date]
    ) {
        var current = directory.standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path
        guard current.path == homePath || current.path.hasPrefix(homePath + "/") else { return }
        var depth = 0
        while current.path != rootPath,
              current.path.hasPrefix(rootPath + "/"),
              depth < 12 {
            let path = current.path
            directorySizes[path, default: 0] += size
            if directoryDates[path] == nil, let date = modificationDate(for: current) {
                directoryDates[path] = date
            }
            current.deleteLastPathComponent()
            depth += 1
        }
    }

    private func topLevelComponent(for url: URL, root: URL) -> String? {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return nil }
        let relative = String(path.dropFirst(rootPath.count + 1))
        return relative.split(separator: "/", maxSplits: 1).first.map(String.init)
    }

    private func isOnVolume(_ url: URL, root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if rootPath != "/" {
            guard path.hasPrefix(rootPath + "/") else { return true }
            let relative = String(path.dropFirst(rootPath.count + 1))
            let firstComponent = relative.split(separator: "/", maxSplits: 1).first.map(String.init)
            return firstComponent != "Volumes" && firstComponent != "Network"
        }
        return path != "/Volumes" && !path.hasPrefix("/Volumes/")
            && path != "/Network" && !path.hasPrefix("/Network/")
    }

    private func isEligibleAnalysisCandidate(_ url: URL, symbolicLink: Bool? = nil) -> Bool {
        let path = url.standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path
        guard path.hasPrefix(homePath + "/"), path != homePath else { return false }
        let relative = String(path.dropFirst(homePath.count + 1))
        let firstComponent = relative.split(separator: "/", maxSplits: 1).first.map(String.init)
        guard firstComponent != "Library", firstComponent != ".Trash" else { return false }
        return !isProtectedPath(url) && !(symbolicLink ?? isSymbolicLink(url)) && !isExcluded(url)
    }

    private func isAnalysisExcludedPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.split(separator: "/").contains { component in
            let name = component.lowercased()
            return analysisExcludedComponents.contains(name)
                || analysisExcludedComponentPrefixes.contains(where: name.hasPrefix)
                || analysisExcludedSuffixes.contains(where: name.hasSuffix)
        }
    }

    private func isStartupProtectedPath(_ url: URL, root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard rootPath != "/", path.hasPrefix(rootPath + "/") else { return false }
        let relative = String(path.dropFirst(rootPath.count + 1))
        let firstComponent = relative.split(separator: "/", maxSplits: 1).first.map(String.init)
        return ["System", "bin", "sbin", "usr", "etc", "Volumes", "Network"].contains(firstComponent)
    }

    private func scanDeveloper(
        into candidates: inout [CleanupCandidate],
        diagnostics: inout [ScanDiagnostic],
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void,
        scanCounter: ScanCounter
    ) {
        let rebuildableNames: Set<String> = [
            "node_modules", "target", ".build", "build", "dist", ".venv", "venv",
            ".next", ".turbo", ".parcel-cache", ".vite", "coverage",
            ".pytest_cache", ".mypy_cache", ".ruff_cache"
        ]
        let recentCutoff = Date().addingTimeInterval(-projectStaleInterval)

        for root in projectRoots where fileManager.fileExists(atPath: root.path) {
            for directory in directoriesUnder(root, stoppingAtDirectoryNames: rebuildableNames, cancellation: cancellation, onItem: {
                scanCounter.record(stage: "查找项目产物")
            }) {
                guard !cancellation.isCancelled else { return }
                guard rebuildableNames.contains(directory.lastPathComponent) else { continue }
                let parent = directory.deletingLastPathComponent()
                if let parentDate = modificationDate(for: parent), parentDate > recentCutoff {
                    continue
                }
                if isInUse(directory) {
                    diagnostics.append(ScanDiagnostic(category: .developer, message: "已跳过正在使用的 \(directory.lastPathComponent)", isWarning: true))
                    continue
                }
                appendExisting(
                    directory,
                    provider: .projectArtifacts,
                    category: .developer,
                    risk: .review,
                    removalMode: .trash,
                    source: "项目构建产物",
                    selected: false,
                    into: &candidates,
                    byteSize: aggregateDirectorySize(directory, cancellation: cancellation, onItem: {
                        scanCounter.record(stage: "计算项目产物体积")
                    }),
                    emit: emit
                )
            }
        }

        if candidates.isEmpty {
            diagnostics.append(ScanDiagnostic(category: .developer, message: "未发现符合条件的旧项目产物", isWarning: false))
        }
    }

    private func aggregateDirectorySize(
        _ directory: URL,
        cancellation: CancellationToken,
        applyAnalysisExclusions: Bool = true,
        onItem: (() -> Void)? = nil
    ) -> Int64? {
        guard !applyAnalysisExclusions || !isAnalysisExcludedPath(directory) else { return nil }
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        var total: Int64 = 0
        var directories = [directory]
        while let current = directories.popLast() {
            guard !cancellation.isCancelled else { return nil }
            if applyAnalysisExclusions, isAnalysisExcludedPath(current) { return nil }
            guard let children = try? fileManager.contentsOfDirectory(at: current, includingPropertiesForKeys: Array(resourceKeys), options: []) else { continue }
            for child in children {
                guard !cancellation.isCancelled else { return nil }
                if applyAnalysisExclusions, isAnalysisExcludedPath(child) { continue }
                guard let values = try? child.resourceValues(forKeys: resourceKeys) else { continue }
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true {
                    directories.append(child)
                } else {
                    onItem?()
                    if let size = values.fileSize {
                        total += Int64(size)
                    }
                }
            }
        }
        return total
    }

    private func scanTimeMachine(
        into candidates: inout [CleanupCandidate],
        diagnostics: inout [ScanDiagnostic],
        category: CleanupCategory = .analysis,
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void
    ) {
        guard fileManager.isExecutableFile(atPath: "/usr/bin/tmutil") else {
            diagnostics.append(ScanDiagnostic(category: category, message: "当前系统未提供 tmutil", isWarning: true))
            return
        }
        let status = runProcess(URL(fileURLWithPath: "/usr/bin/tmutil"), arguments: ["status"])
        if status.timedOut {
            diagnostics.append(ScanDiagnostic(category: category, message: "读取 Time Machine 状态超时", isWarning: true))
            return
        }
        guard status.exitCode == 0 else {
            diagnostics.append(ScanDiagnostic(category: category, message: status.stderr.isEmpty ? "无法读取 Time Machine 状态" : status.stderr, isWarning: true))
            return
        }
        if status.stdout.localizedCaseInsensitiveContains("Running = 1") {
            diagnostics.append(ScanDiagnostic(category: category, message: "Time Machine 正在运行，已跳过本次维护", isWarning: true))
            return
        }
        guard !cancellation.isCancelled else { return }

        let snapshots = runProcess(URL(fileURLWithPath: "/usr/bin/tmutil"), arguments: ["listlocalsnapshots", "/"])
        if snapshots.timedOut {
            diagnostics.append(ScanDiagnostic(category: category, message: "读取本地快照超时", isWarning: true))
            return
        }
        guard snapshots.exitCode == 0 else {
            diagnostics.append(ScanDiagnostic(category: category, message: snapshots.stderr.isEmpty ? "无法读取本地快照" : snapshots.stderr, isWarning: true))
            return
        }
        guard !snapshots.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            diagnostics.append(ScanDiagnostic(category: category, message: "未发现本地快照", isWarning: false))
            return
        }
        let candidate = CleanupCandidate(
            url: nil,
            provider: .spaceAnalysis,
            category: category,
            displayName: "Time Machine 本地快照",
            byteSize: nil,
            modifiedAt: nil,
            risk: .advanced,
            removalMode: .timeMachine,
            source: "大文件扫描 · Time Machine",
            isSelected: false
        )
        candidates.append(candidate)
        emit(.candidateDiscovered(candidate))
    }

    private func appendExisting(
        _ url: URL,
        provider: CleanupProvider,
        category: CleanupCategory,
        risk: RiskLevel,
        removalMode: RemovalMode,
        source: String,
        selected: Bool,
        into candidates: inout [CleanupCandidate],
        byteSize: Int64? = nil,
        emit: @escaping @Sendable (CleanupEvent) -> Void = { _ in }
    ) {
        guard fileManager.fileExists(atPath: url.path), !isSymbolicLink(url) else { return }
        let canTrash = removalMode != .trash || canMoveToTrash(url)
        let protectionReason = canTrash ? nil : "当前没有权限移到废纸篓"
        let candidate = CleanupCandidate(
            url: url.standardizedFileURL,
            provider: provider,
            category: category,
            displayName: url.lastPathComponent,
            byteSize: byteSize ?? sizeOfItem(url),
            modifiedAt: modificationDate(for: url),
            risk: canTrash ? risk : .protected,
            removalMode: removalMode,
            source: source,
            protectionReason: protectionReason,
            isSelected: selected && canTrash && !isExcluded(url)
        )
        candidates.append(candidate)
        emit(.candidateDiscovered(candidate))
    }

    private func canMoveToTrash(_ url: URL) -> Bool {
        guard fileManager.isDeletableFile(atPath: url.path) else { return false }
        return fileManager.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }

    // MARK: - Applying

    func execute(
        plan: CleanupPlan,
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void
    ) -> CleanupSummary {
        let candidates = plan.selectedCandidates
        let allCandidates = plan.allCandidates
        let startedAt = Date()
        let before = availableDiskBytes
        emit(.phase(.applying, "正在重新检查清理项"))

        var results: [CandidateResult] = []
        let privileged = candidates.filter { $0.removalMode == .privilegedTrash || $0.removalMode == .timeMachine }
        let userOwned = candidates.filter { $0.removalMode != .privilegedTrash && $0.removalMode != .timeMachine }

        for candidate in userOwned {
            guard !cancellation.isCancelled else {
                results.append(cancelledResult(for: candidate))
                continue
            }
            emit(.candidateStarted(candidate.id))
            let result = applyUserCandidate(candidate)
            results.append(result)
            emit(.candidateCompleted(result))
        }

        if !privileged.isEmpty {
            if cancellation.isCancelled {
                for candidate in privileged {
                    let result = cancelledResult(for: candidate)
                    results.append(result)
                    emit(.candidateCompleted(result))
                }
            } else {
                for candidate in privileged { emit(.candidateStarted(candidate.id)) }
                let privilegedResults = applyPrivilegedCandidates(privileged, cancellation: cancellation)
                results.append(contentsOf: privilegedResults)
                privilegedResults.forEach { emit(.candidateCompleted($0)) }
            }
        }

        let selectedIDs = Set(candidates.map(\.id))
        for candidate in allCandidates where !selectedIDs.contains(candidate.id) {
            let result = CandidateResult(
                id: candidate.id,
                category: candidate.category,
                displayName: candidate.displayName,
                path: candidate.pathDescription,
                byteSize: candidate.byteSize,
                removalMode: candidate.removalMode,
                outcome: .skipped,
                message: "未选择",
                finishedAt: Date()
            )
            results.append(result)
        }

        let summary = makeSummary(
            startedAt: startedAt,
            before: before,
            after: availableDiskBytes,
            results: results,
            allCandidates: allCandidates
        )
        saveHistory(summary, categories: Array(Set(allCandidates.map(\.category))).sorted { $0.rawValue < $1.rawValue })
        emit(.finished(summary))
        return summary
    }

    private func applyUserCandidate(_ candidate: CleanupCandidate) -> CandidateResult {
        guard let url = candidate.url else { return failedResult(for: candidate, message: "缺少文件路径") }
        do {
            try validate(candidate: candidate, url: url)
            switch candidate.removalMode {
            case .trash:
                var trashedURL: NSURL?
                try fileManager.trashItem(at: url, resultingItemURL: &trashedURL)
                return result(for: candidate, outcome: .movedToTrash, message: "已移到废纸篓")
            case .privilegedTrash, .timeMachine:
                return failedResult(for: candidate, message: "需要管理员权限")
            }
        } catch {
            return failedResult(for: candidate, message: cleanupErrorMessage(error))
        }
    }

    private func cleanupErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        let lowercased = message.lowercased()
        if lowercased.contains("permission") || message.contains("权限") || message.contains("拒绝") {
            return "当前没有权限移到废纸篓，请开启完全磁盘访问权限后重试"
        }
        return message
    }

    private func applyPrivilegedCandidates(_ candidates: [CleanupCandidate], cancellation: CancellationToken) -> [CandidateResult] {
        var commands: [String] = []
        var commandIDs: [UUID] = []
        for candidate in candidates {
            guard let command = privilegedCommand(for: candidate) else {
                continue
            }
            commands.append(command)
            commandIDs.append(candidate.id)
        }

        guard commands.count == candidates.count else {
            return candidates.map { failedResult(for: $0, message: "路径未通过管理员操作校验") }
        }
        guard !cancellation.isCancelled else { return candidates.map(cancelledResult) }

        do {
            let command = commands.joined(separator: "; ")
            let output = if let privilegedRunner {
                try privilegedRunner(command)
            } else {
                try runPrivileged(command)
            }
            let lines = output.split(separator: "\n").map(String.init)
            return candidates.enumerated().map { index, candidate in
                let marker = lines.first { $0.contains(commandIDs[index].uuidString) }
                if marker?.contains("__CLEANMAC_OK__") == true {
                    let outcome: CandidateOutcome = candidate.removalMode == .privilegedTrash ? .movedToTrash : .removed
                    let message = candidate.removalMode == .privilegedTrash ? "已移到废纸篓" : "管理员操作完成"
                    return result(for: candidate, outcome: outcome, message: message)
                }
                return failedResult(for: candidate, message: "管理员操作失败")
            }
        } catch CleanerError.userCancelled {
            return candidates.map(cancelledResult)
        } catch {
            return candidates.map { failedResult(for: $0, message: error.localizedDescription) }
        }
    }

    private func privilegedCommand(for candidate: CleanupCandidate) -> String? {
        switch candidate.removalMode {
        case .timeMachine:
            return "if /usr/bin/tmutil thinlocalsnapshots / 1000000000000 4 2>/dev/null; then printf '__CLEANMAC_OK__|\(candidate.id.uuidString)\\n'; else printf '__CLEANMAC_FAIL__|\(candidate.id.uuidString)\\n'; fi"
        case .privilegedTrash:
            guard let url = candidate.url else { return nil }
            guard (try? validate(candidate: candidate, url: url)) != nil else { return nil }
            let sourcePath = shellQuote(url.path)
            let trashDirectory = shellQuote(homeDirectory.appendingPathComponent(".Trash", isDirectory: true).path)
            let destination = shellQuote(homeDirectory.appendingPathComponent(".Trash", isDirectory: true).appendingPathComponent("CleanMac-\(candidate.id.uuidString)-\(url.lastPathComponent)").path)
            return "if /bin/mkdir -p -- \(trashDirectory) && /bin/mv -- \(sourcePath) \(destination); then printf '__CLEANMAC_OK__|\(candidate.id.uuidString)\\n'; else printf '__CLEANMAC_FAIL__|\(candidate.id.uuidString)\\n'; fi"
        case .trash:
            return nil
        }
    }

    // MARK: - Safety and history

    func addExclusion(for url: URL) {
        exclusionStore.add(url)
    }

    func removeExclusion(for url: URL) {
        exclusionStore.remove(url)
    }

    func loadHistory() -> [CleanupHistoryEntry] {
        historyStore.load()
    }

    func saveHistory(_ summary: CleanupSummary, categories: [CleanupCategory]) {
        historyStore.save(summary, categories: categories)
    }

    private func validate(candidate: CleanupCandidate, url: URL) throws {
        let standardized = url.standardizedFileURL
        guard standardized.isFileURL, standardized.path.hasPrefix("/") else {
            throw CleanerError.invalidPath(url.path)
        }
        guard isAllowedPath(standardized, for: candidate.category, provider: candidate.provider) else {
            throw CleanerError.invalidPath(standardized.path)
        }
        let isApprovedRoutinePath = candidate.category == .routine && candidate.provider == .deepCleanup
        guard (!isProtectedPath(standardized) || isApprovedRoutinePath), !isExcluded(standardized), !isSymbolicLink(standardized) else {
            throw CleanerError.invalidPath(standardized.path)
        }
        if candidate.category == .analysis, !candidate.removalMode.isTrash {
            throw CleanerError.invalidPath(standardized.path)
        }
        guard fileManager.fileExists(atPath: standardized.path) else {
            throw CleanerError.invalidPath(standardized.path)
        }
        if let expectedSize = candidate.byteSize,
           let currentSize = currentSize(for: candidate, url: standardized),
           expectedSize != currentSize {
            throw CleanerError.invalidPath(standardized.path)
        }
    }

    private func isAllowedPath(_ url: URL, for category: CleanupCategory, provider: CleanupProvider) -> Bool {
        let roots: [URL]
        switch category {
        case .routine:
            roots = userCachePolicies.map { homeDirectory.appendingPathComponent($0.relativePath, isDirectory: true) } + [
                homeDirectory.appendingPathComponent("Library/Logs"),
                URL(fileURLWithPath: "/Library/Caches/com.apple.Safari"),
                URL(fileURLWithPath: "/Library/Caches/com.apple.dt.Xcode"),
                URL(fileURLWithPath: "/private/var/log")
            ]
        case .analysis:
            if provider == .applications {
                roots = applicationLeftoverRoots
            } else {
                roots = [homeDirectory]
            }
        case .developer:
            roots = projectRoots
        }
        let path = url.standardizedFileURL.path
        let isWithinRoot = roots.contains { root in
            let rootPath = root.standardizedFileURL.path
            return path == rootPath || path.hasPrefix(rootPath + "/")
        }
        guard isWithinRoot else { return false }
        if category == .analysis && provider != .applications {
            let homePath = homeDirectory.standardizedFileURL.path
            guard path != homePath, path.hasPrefix(homePath + "/") else { return false }
            let relative = String(path.dropFirst(homePath.count + 1))
            let firstComponent = relative.split(separator: "/", maxSplits: 1).first.map(String.init)
            guard firstComponent != "Library", firstComponent != ".Trash" else { return false }
        }
        return true
    }

    private func isProtectedPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let protectedPrefixes = [
            "/System",
            "/bin",
            "/sbin",
            "/usr",
            "/etc",
            "/Library/Extensions",
            "/Library/Keychains",
            "/private/var/vm",
            "/private/var/db",
            "/private/var/log",
            "/private/var/folders"
        ]
        let userProtected = [
            homeDirectory.appendingPathComponent("Library/Keychains").path,
            homeDirectory.appendingPathComponent("Library/Messages").path,
            homeDirectory.appendingPathComponent("Library/Mobile Documents").path,
            homeDirectory.appendingPathComponent("Library/Safari/History.db").path,
            homeDirectory.appendingPathComponent("Pictures/Photos Library.photoslibrary").path
        ]
        return protectedPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
            || userProtected.contains { path == $0 || path.hasPrefix($0 + "/") }
            || isAnalysisExcludedPath(url)
    }

    private func isExcluded(_ url: URL) -> Bool {
        exclusionStore.contains(url)
    }

    // MARK: - Results

    private func makeSummary(
        startedAt: Date,
        before: Int64?,
        after: Int64?,
        results: [CandidateResult],
        allCandidates: [CleanupCandidate]
    ) -> CleanupSummary {
        let categories = CleanupCategory.allCases.compactMap { category -> CategorySummary? in
            let scanned = allCandidates.filter { $0.category == category }.count
            let categoryResults = results.filter { $0.category == category }
            guard scanned > 0 || !categoryResults.isEmpty else { return nil }
            return CategorySummary(
                category: category,
                scannedCount: scanned,
                selectedCount: categoryResults.filter { $0.outcome != .skipped }.count,
                movedToTrashCount: categoryResults.filter { $0.outcome == .movedToTrash }.count,
                removedCount: categoryResults.filter { $0.outcome == .removed }.count,
                skippedCount: categoryResults.filter { $0.outcome == .skipped }.count,
                failedCount: categoryResults.filter { $0.outcome == .failed }.count,
                cancelledCount: categoryResults.filter { $0.outcome == .cancelled }.count,
                affectedBytes: categoryResults.filter { $0.outcome == .movedToTrash || $0.outcome == .removed }.compactMap(\.byteSize).reduce(0, +)
            )
        }
        return CleanupSummary(
            startedAt: startedAt,
            finishedAt: Date(),
            beforeAvailableBytes: before,
            afterAvailableBytes: after,
            scannedCount: allCandidates.count,
            selectedCount: results.filter { $0.outcome != .skipped }.count,
            results: results,
            categories: categories
        )
    }

    private func result(for candidate: CleanupCandidate, outcome: CandidateOutcome, message: String) -> CandidateResult {
        CandidateResult(id: candidate.id, category: candidate.category, displayName: candidate.displayName, path: candidate.pathDescription, byteSize: candidate.byteSize, removalMode: candidate.removalMode, outcome: outcome, message: message, finishedAt: Date())
    }

    private func failedResult(for candidate: CleanupCandidate, message: String) -> CandidateResult {
        result(for: candidate, outcome: .failed, message: message)
    }

    private func cancelledResult(for candidate: CleanupCandidate) -> CandidateResult {
        result(for: candidate, outcome: .cancelled, message: "已取消")
    }

    // MARK: - File and process helpers

    var availableDiskBytes: Int64? {
        diskAccessService.availableBytes
    }

    func formattedAvailableDiskSpace() -> String {
        diskAccessService.formattedAvailableSpace
    }

    func startupVolumeAccessStatus() -> DiskAccessStatus {
        diskAccessService.accessStatus
    }

    func openFullDiskAccessSettings() {
        diskAccessService.openSettings()
    }

    private func directChildren(
        of directory: URL,
        applyAnalysisExclusions: Bool = true,
        onItem: (() -> Void)? = nil
    ) -> [URL] {
        guard !isAnalysisExcludedPath(directory),
              let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
              ) else { return [] }
        return contents.compactMap { url in
            guard !applyAnalysisExclusions || !isAnalysisExcludedPath(url) else { return nil }
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true else { return nil }
            if values.isDirectory != true {
                onItem?()
            }
            return url
        }
    }

    private func filesUnder(
        _ root: URL,
        modifiedBefore: Date? = nil,
        cancellation: CancellationToken,
        onItem: (() -> Void)? = nil
    ) -> [URL] {
        guard fileManager.fileExists(atPath: root.path), !isAnalysisExcludedPath(root), !isSymbolicLink(root) else { return [] }
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey]
        var files: [URL] = []
        var directories = [root]
        while let current = directories.popLast() {
            guard !cancellation.isCancelled, !isAnalysisExcludedPath(current) else { continue }
            guard let children = try? fileManager.contentsOfDirectory(at: current, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles]) else { continue }
            for url in children {
                guard !cancellation.isCancelled else { break }
                if isAnalysisExcludedPath(url) { continue }
                guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true {
                    directories.append(url)
                } else {
                    onItem?()
                    if let modifiedBefore, let modifiedAt = values.contentModificationDate, modifiedAt >= modifiedBefore { continue }
                    files.append(url.standardizedFileURL)
                }
            }
        }
        return files
    }

    private func directoriesUnder(
        _ root: URL,
        stoppingAtDirectoryNames: Set<String> = [],
        cancellation: CancellationToken,
        onItem: (() -> Void)? = nil
    ) -> [URL] {
        guard fileManager.fileExists(atPath: root.path), !isAnalysisExcludedPath(root), !isSymbolicLink(root) else { return [] }
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        var directories: [URL] = []
        var pending = [root]
        while let current = pending.popLast() {
            guard !cancellation.isCancelled, !isAnalysisExcludedPath(current) else { continue }
            guard let children = try? fileManager.contentsOfDirectory(at: current, includingPropertiesForKeys: Array(resourceKeys), options: []) else { continue }
            for url in children {
                guard !cancellation.isCancelled else { break }
                if isAnalysisExcludedPath(url) { continue }
                guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
                if values.isSymbolicLink == true { continue }
                guard values.isDirectory == true else {
                    onItem?()
                    continue
                }
                let normalizedURL = url.standardizedFileURL
                directories.append(normalizedURL)
                if !stoppingAtDirectoryNames.contains(url.lastPathComponent) {
                    pending.append(url)
                }
            }
        }
        return directories
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]) else { return false }
        return values.isSymbolicLink == true
    }

    private func isInUse(_ url: URL) -> Bool {
        let lsof = URL(fileURLWithPath: "/usr/sbin/lsof")
        guard fileManager.isExecutableFile(atPath: lsof.path) else { return false }
        let result = runProcess(lsof, arguments: ["-t", "--", url.path], timeout: 2)
        if result.timedOut { return true }
        if result.exitCode == 0 { return true }
        if result.exitCode == 1 { return false }
        return true
    }

    private func sizeOfItem(_ url: URL) -> Int64? {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize { return Int64(size) }
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path), let size = attributes[.size] as? NSNumber else { return nil }
        return size.int64Value
    }

    private func currentSize(for candidate: CleanupCandidate, url: URL) -> Int64? {
        let applyAnalysisExclusions = candidate.category != .routine
        guard !applyAnalysisExclusions || !isAnalysisExcludedPath(url) else { return nil }
        guard isDirectory(url) else {
            return sizeOfItem(url)
        }
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        var total: Int64 = 0
        var count = 0
        var directories = [url]
        while let current = directories.popLast() {
            if applyAnalysisExclusions, isAnalysisExcludedPath(current) { return nil }
            guard let children = try? fileManager.contentsOfDirectory(at: current, includingPropertiesForKeys: Array(resourceKeys), options: []) else { continue }
            for child in children {
                if applyAnalysisExclusions, isAnalysisExcludedPath(child) { continue }
                count += 1
                guard count <= analysisValidationEntryLimit else { return nil }
                guard let values = try? child.resourceValues(forKeys: resourceKeys) else { continue }
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true {
                    directories.append(child)
                } else if let size = values.fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    private func modificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
    }

    private struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let timedOut: Bool
    }

    private func runProcess(_ executable: URL, arguments: [String], timeout: TimeInterval = 10) -> ProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            let timedOut = process.isRunning
            if timedOut { process.terminate() }
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout: String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                stderr: String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                timedOut: timedOut
            )
        } catch {
            return ProcessResult(exitCode: -1, stdout: "", stderr: error.localizedDescription, timedOut: false)
        }
    }

    private func runPrivileged(_ command: String) throws -> String {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            if errorMessage.contains("User canceled") || errorMessage.contains("-128") { throw CleanerError.userCancelled }
            throw CleanerError.taskFailed(errorMessage)
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
