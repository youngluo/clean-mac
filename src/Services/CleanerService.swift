import Foundation
import AppKit

final class CleanerService: @unchecked Sendable {
    private let homeDirectory: URL
    private let startupVolumeURL: URL
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let privilegedRunner: (@Sendable (String) throws -> String)?
    private let fullDiskAccessProbeURL: URL
    private let exclusionKey = "CleanMac.excludedCleanupPaths"
    private let historyLimit = 50
    private let staleInterval: TimeInterval = 7 * 24 * 60 * 60
    private let analysisThreshold: Int64 = 200 * 1_000_000
    private let analysisCandidateLimit = 500
    private let analysisValidationEntryLimit = 100_000
    private let analysisTimeout: TimeInterval

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
        self.userDefaults = userDefaults
        self.privilegedRunner = privilegedRunner
        self.analysisTimeout = analysisTimeout
        self.fullDiskAccessProbeURL = fullDiskAccessProbeURL.standardizedFileURL
    }

    // MARK: - Scanning

    func scan(
        category: CleanupCategory,
        cancellation: CancellationToken = CancellationToken(),
        emit: @escaping @Sendable (CleanupEvent) -> Void = { _ in }
    ) -> ScanResult {
        var candidates: [CleanupCandidate] = []
        var diagnostics: [ScanDiagnostic] = []

        guard !cancellation.isCancelled else {
            let diagnostic = ScanDiagnostic(category: category, message: "扫描在开始前已取消", isWarning: true)
            return ScanResult(category: category, candidates: [], diagnostics: [diagnostic], scannedCount: 0, isPartial: true)
        }

        if category == .analysis {
            let volumeResult = scanStartupVolume(cancellation: cancellation, emit: emit)
            var candidates = volumeResult.candidates
            var diagnostics = volumeResult.diagnostics

            // Time Machine 是空间占用的一部分，和大文件分析一起检查，避免用户在两个入口之间做选择。
            if startupVolumeURL.path == "/" && !cancellation.isCancelled {
                scanTimeMachine(into: &candidates, diagnostics: &diagnostics, category: .analysis, cancellation: cancellation)
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
                scannedCount: volumeResult.scannedCount + timeMachineCount,
                isPartial: volumeResult.isPartial,
                volumeSummary: volumeSummary
            )
        }

        switch category {
        case .routine:
            scanRoutine(into: &candidates, diagnostics: &diagnostics, cancellation: cancellation)
        case .analysis:
            break
        case .developer:
            scanDeveloper(into: &candidates, diagnostics: &diagnostics, cancellation: cancellation)
        case .timeMachine:
            scanTimeMachine(into: &candidates, diagnostics: &diagnostics, cancellation: cancellation)
        }

        return ScanResult(
            category: category,
            candidates: candidates.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending },
            diagnostics: diagnostics,
            scannedCount: candidates.count
        )
    }

    private func scanRoutine(
        into candidates: inout [CleanupCandidate],
        diagnostics: inout [ScanDiagnostic],
        cancellation: CancellationToken
    ) {
        let userCacheRoots = [
            homeDirectory.appendingPathComponent("Library/Caches/com.apple.Safari"),
            homeDirectory.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
            homeDirectory.appendingPathComponent("Library/Caches/pip")
        ]

        for root in userCacheRoots {
            guard !cancellation.isCancelled else { return }
            appendExisting(
                root,
                category: .routine,
                risk: .safe,
                removalMode: .trash,
                source: "用户缓存",
                selected: true,
                into: &candidates
            )
        }

        let logRoot = homeDirectory.appendingPathComponent("Library/Logs")
        let cutoff = Date().addingTimeInterval(-staleInterval)
        for file in filesUnder(logRoot, modifiedBefore: cutoff, cancellation: cancellation) {
            appendExisting(
                file,
                category: .routine,
                risk: .safe,
                removalMode: .trash,
                source: "用户旧日志",
                selected: true,
                into: &candidates
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
                for file in filesUnder(root, modifiedBefore: cutoff, cancellation: cancellation) {
                    appendExisting(file, category: .routine, risk: .safe, removalMode: .privilegedPermanent, source: source, selected: false, into: &candidates)
                }
            } else {
                appendExisting(root, category: .routine, risk: .safe, removalMode: .privilegedPermanent, source: source, selected: false, into: &candidates)
            }
        }

        if candidates.isEmpty {
            diagnostics.append(ScanDiagnostic(category: .routine, message: "未发现符合条件的安全清理项", isWarning: false))
        }
    }

    private func scanStartupVolume(
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void
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
        let deadline = Date().addingTimeInterval(analysisTimeout)
        var usageByTopLevel: [String: Int64] = [:]
        var directorySizes: [String: Int64] = [:]
        var directoryDates: [String: Date] = [:]
        var protectedItems: [String: VolumeUsageItem] = [:]
        var unavailableItems: [String: VolumeUsageItem] = [:]
        var processedEntries = 0
        var measuredBytes: Int64 = 0
        var isPartial = false

        emit(.scanProgress(ScanProgress(
            category: .analysis,
            stage: "读取启动磁盘信息",
            processedEntries: 0,
            estimatedEntries: nil,
            diagnosticsCount: diagnostics.count
        )))

        emit(.scanProgress(ScanProgress(
            category: .analysis,
            stage: "遍历启动磁盘目录",
            processedEntries: 0,
            estimatedEntries: nil,
            diagnosticsCount: diagnostics.count
        )))

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
                includingPropertiesForKeys: [],
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

                // 必须在 resourceValues、sizeOfItem 和递归之前判断，避免触碰照片图库包。
                if isAnalysisExcludedPath(url) {
                    continue
                }

                processedEntries += 1
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
                            byteSize: sizeOfItem(url),
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

                    if isEligibleAnalysisCandidate(url), size >= analysisThreshold {
                        candidates.append(makeAnalysisCandidate(
                            url: url,
                            size: size,
                            modifiedAt: values.contentModificationDate,
                            source: "启动磁盘大文件"
                        ))
                    }
                }

                if processedEntries.isMultiple(of: 500) {
                    emit(.scanProgress(ScanProgress(
                        category: .analysis,
                        stage: "遍历启动磁盘目录",
                        processedEntries: processedEntries,
                        estimatedEntries: nil,
                        diagnosticsCount: diagnostics.count
                    )))
                }
            }
        }

        for (path, size) in directorySizes where size >= analysisThreshold {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard isEligibleAnalysisCandidate(url), !isProtectedPath(url), !isStartupProtectedPath(url, root: root) else { continue }
            candidates.append(makeAnalysisCandidate(
                url: url,
                size: size,
                modifiedAt: directoryDates[path],
                source: "启动磁盘大目录"
            ))
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
        if candidates.count > analysisCandidateLimit {
            candidates = Array(candidates.prefix(analysisCandidateLimit))
            isPartial = true
            diagnostics.append(ScanDiagnostic(category: .analysis, message: "可清理候选过多，仅展示占用最大的 (analysisCandidateLimit) 项", isWarning: true))
        }

        if candidates.isEmpty && !isPartial {
            diagnostics.append(ScanDiagnostic(category: .analysis, message: "未发现超过 200 MB 的用户文件或目录", isWarning: false))
        }

        let usageItems = usageByTopLevel.map { name, size in
            VolumeUsageItem(
                url: root.appendingPathComponent(name),
                displayName: name,
                byteSize: size,
                status: .measured
            )
        } + protectedItems.values + unavailableItems.values
        let summary = VolumeAnalysisSummary(
            volumeURL: root,
            volumeName: volumeName,
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            measuredBytes: measuredBytes,
            usageItems: usageItems.sorted { ($0.byteSize ?? 0) > ($1.byteSize ?? 0) },
            processedEntryCount: processedEntries,
            candidateCount: candidates.count,
            isPartial: isPartial
        )
        emit(.scanProgress(ScanProgress(
            category: .analysis,
            stage: isPartial ? "扫描部分完成" : "扫描完成",
            processedEntries: processedEntries,
            estimatedEntries: processedEntries,
            diagnosticsCount: diagnostics.count
        )))

        return ScanResult(
            category: .analysis,
            candidates: candidates,
            diagnostics: diagnostics,
            scannedCount: processedEntries,
            isPartial: isPartial,
            volumeSummary: summary
        )
    }

    private func makeAnalysisCandidate(
        url: URL,
        size: Int64,
        modifiedAt: Date? = nil,
        source: String
    ) -> CleanupCandidate {
        CleanupCandidate(
            url: url.standardizedFileURL,
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

    private func isEligibleAnalysisCandidate(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path
        guard path.hasPrefix(homePath + "/"), path != homePath else { return false }
        let relative = String(path.dropFirst(homePath.count + 1))
        let firstComponent = relative.split(separator: "/", maxSplits: 1).first.map(String.init)
        guard firstComponent != "Library", firstComponent != ".Trash" else { return false }
        return !isProtectedPath(url) && !isSymbolicLink(url) && !isExcluded(url)
    }

    private func isAnalysisExcludedPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let picturesPath = homeDirectory
            .appendingPathComponent("Pictures")
            .standardizedFileURL
            .path
        guard path.hasPrefix(picturesPath + "/") else { return false }

        let relativePath = String(path.dropFirst(picturesPath.count + 1))
        return relativePath.split(separator: "/").contains { component in
            let name = component.lowercased()
            return name.hasSuffix(".photoslibrary")
                || name.hasSuffix(".photolibrary")
                || name == "photo booth library"
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
        cancellation: CancellationToken
    ) {
        let knownCaches = [
            (homeDirectory.appendingPathComponent(".npm/_cacache"), "npm 缓存"),
            (homeDirectory.appendingPathComponent("Library/Caches/Homebrew"), "Homebrew 缓存"),
            (homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData"), "Xcode DerivedData")
        ]
        for (url, source) in knownCaches {
            guard !cancellation.isCancelled else { return }
            let children = directChildren(of: url)
            if children.isEmpty {
                appendExisting(url, category: .developer, risk: .safe, removalMode: .permanent, source: source, selected: true, into: &candidates)
            } else {
                for child in children {
                    appendExisting(child, category: .developer, risk: .safe, removalMode: .permanent, source: source, selected: true, into: &candidates)
                }
            }
        }

        let projectRoots = ["Projects", "GitHub", "dev", "Work", "Documents"].map {
            homeDirectory.appendingPathComponent($0)
        }
        let rebuildableNames: Set<String> = ["node_modules", "target", ".build", "build", "dist", ".venv", "venv"]
        let recentCutoff = Date().addingTimeInterval(-staleInterval)

        for root in projectRoots where fileManager.fileExists(atPath: root.path) {
            for directory in directoriesUnder(root, cancellation: cancellation) {
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
                    category: .developer,
                    risk: .review,
                    removalMode: .permanent,
                    source: "项目构建产物",
                    selected: false,
                    into: &candidates
                )
            }
        }

        if candidates.isEmpty {
            diagnostics.append(ScanDiagnostic(category: .developer, message: "未发现已识别的开发缓存或旧构建产物", isWarning: false))
        }
    }

    private func scanTimeMachine(
        into candidates: inout [CleanupCandidate],
        diagnostics: inout [ScanDiagnostic],
        category: CleanupCategory = .timeMachine,
        cancellation: CancellationToken
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
        candidates.append(CleanupCandidate(
            url: nil,
            category: category,
            displayName: "Time Machine 本地快照",
            byteSize: nil,
            modifiedAt: nil,
            risk: .advanced,
            removalMode: .timeMachine,
            source: "空间分析 · Time Machine",
            protectionReason: "快照维护需要管理员权限",
            isSelected: false
        ))
    }

    private func appendExisting(
        _ url: URL,
        category: CleanupCategory,
        risk: RiskLevel,
        removalMode: RemovalMode,
        source: String,
        selected: Bool,
        into candidates: inout [CleanupCandidate]
    ) {
        guard fileManager.fileExists(atPath: url.path), !isSymbolicLink(url) else { return }
        let canTrash = removalMode != .trash || canMoveToTrash(url)
        let protectionReason = canTrash ? nil : "当前没有权限移到废纸篓"
        candidates.append(CleanupCandidate(
            url: url.standardizedFileURL,
            category: category,
            displayName: url.lastPathComponent,
            byteSize: sizeOfItem(url),
            modifiedAt: modificationDate(for: url),
            risk: canTrash ? risk : .protected,
            removalMode: removalMode,
            source: source,
            protectionReason: protectionReason,
            isSelected: selected && canTrash && !isExcluded(url)
        ))
    }

    private func canMoveToTrash(_ url: URL) -> Bool {
        guard fileManager.isDeletableFile(atPath: url.path) else { return false }
        return fileManager.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }

    // MARK: - Applying

    func apply(
        selected candidates: [CleanupCandidate],
        allCandidates: [CleanupCandidate],
        cancellation: CancellationToken,
        emit: @escaping @Sendable (CleanupEvent) -> Void
    ) -> CleanupSummary {
        let startedAt = Date()
        let before = availableDiskBytes
        emit(.phase(.applying, "正在重新检查清理项"))

        var results: [CandidateResult] = []
        let privileged = candidates.filter { $0.isSelected && ($0.removalMode == .privilegedPermanent || $0.removalMode == .timeMachine) }
        let userOwned = candidates.filter { $0.isSelected && $0.removalMode != .privilegedPermanent && $0.removalMode != .timeMachine }

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

        for candidate in candidates where !candidate.isSelected {
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
            case .permanent:
                guard isBoundedPermanentCandidate(candidate, url: url) else {
                    throw CleanerError.invalidPath(url.path)
                }
                try fileManager.removeItem(at: url)
                return result(for: candidate, outcome: .removed, message: "已永久删除")
            case .privilegedPermanent, .timeMachine:
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
                    return result(for: candidate, outcome: candidate.removalMode == .timeMachine ? .removed : .removed, message: "管理员操作完成")
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
        case .privilegedPermanent:
            guard let url = candidate.url else { return nil }
            guard (try? validate(candidate: candidate, url: url)) != nil else { return nil }
            let path = shellQuote(url.path)
            return "if /bin/rm -rf -- \(path); then printf '__CLEANMAC_OK__|\(candidate.id.uuidString)\\n'; else printf '__CLEANMAC_FAIL__|\(candidate.id.uuidString)\\n'; fi"
        case .trash, .permanent:
            return nil
        }
    }

    // MARK: - Safety and history

    func addExclusion(for url: URL) {
        var paths = Set(userDefaults.stringArray(forKey: exclusionKey) ?? [])
        paths.insert(url.standardizedFileURL.path)
        userDefaults.set(Array(paths).sorted(), forKey: exclusionKey)
    }

    func removeExclusion(for url: URL) {
        var paths = Set(userDefaults.stringArray(forKey: exclusionKey) ?? [])
        paths.remove(url.standardizedFileURL.path)
        userDefaults.set(Array(paths).sorted(), forKey: exclusionKey)
    }

    func loadHistory() -> [CleanupHistoryEntry] {
        let url = historyURL
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([CleanupHistoryEntry].self, from: data) else { return [] }
        return entries.sorted { $0.finishedAt > $1.finishedAt }
    }

    func saveHistory(_ summary: CleanupSummary, categories: [CleanupCategory]) {
        var entries = loadHistory()
        entries.insert(CleanupHistoryEntry(id: UUID(), finishedAt: summary.finishedAt, categories: categories, summary: summary), at: 0)
        entries = Array(entries.prefix(historyLimit))
        guard let data = try? JSONEncoder().encode(entries) else { return }
        do {
            try fileManager.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // History is best-effort and must never make a cleanup fail.
        }
    }

    private func validate(candidate: CleanupCandidate, url: URL) throws {
        let standardized = url.standardizedFileURL
        guard standardized.isFileURL, standardized.path.hasPrefix("/") else {
            throw CleanerError.invalidPath(url.path)
        }
        guard isAllowedPath(standardized, for: candidate.category) else {
            throw CleanerError.invalidPath(standardized.path)
        }
        guard !isProtectedPath(standardized), !isExcluded(standardized), !isSymbolicLink(standardized) else {
            throw CleanerError.invalidPath(standardized.path)
        }
        if candidate.category == .analysis, candidate.removalMode != .trash {
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

    private func isAllowedPath(_ url: URL, for category: CleanupCategory) -> Bool {
        let roots: [URL]
        switch category {
        case .routine:
            roots = [
                homeDirectory.appendingPathComponent("Library/Caches"),
                homeDirectory.appendingPathComponent("Library/Logs"),
                URL(fileURLWithPath: "/Library/Caches/com.apple.Safari"),
                URL(fileURLWithPath: "/Library/Caches/com.apple.dt.Xcode"),
                URL(fileURLWithPath: "/private/var/log")
            ]
        case .analysis:
            roots = [homeDirectory]
        case .developer:
            roots = [
                homeDirectory.appendingPathComponent(".npm"),
                homeDirectory.appendingPathComponent("Library/Caches"),
                homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                homeDirectory.appendingPathComponent("Projects"),
                homeDirectory.appendingPathComponent("GitHub"),
                homeDirectory.appendingPathComponent("dev"),
                homeDirectory.appendingPathComponent("Work"),
                homeDirectory.appendingPathComponent("Documents")
            ]
        case .timeMachine:
            return false
        }
        let path = url.standardizedFileURL.path
        let isWithinRoot = roots.contains { root in
            let rootPath = root.standardizedFileURL.path
            return path == rootPath || path.hasPrefix(rootPath + "/")
        }
        guard isWithinRoot else { return false }
        if category == .analysis {
            let homePath = homeDirectory.standardizedFileURL.path
            guard path != homePath, path.hasPrefix(homePath + "/") else { return false }
            let relative = String(path.dropFirst(homePath.count + 1))
            let firstComponent = relative.split(separator: "/", maxSplits: 1).first.map(String.init)
            guard firstComponent != "Library", firstComponent != ".Trash" else { return false }
        }
        return true
    }

    private func isBoundedPermanentCandidate(_ candidate: CleanupCandidate, url: URL) -> Bool {
        guard candidate.category == .developer else { return false }
        let components = Set(url.standardizedFileURL.pathComponents)
        let rebuildable = ["node_modules", "target", ".build", "build", "dist", ".venv", "venv", "DerivedData"]
        if components.contains(where: { rebuildable.contains($0) }) { return true }
        return url.path.hasSuffix("/.npm/_cacache") || url.path.hasSuffix("/Library/Caches/Homebrew")
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
        let path = url.standardizedFileURL.path
        return (userDefaults.stringArray(forKey: exclusionKey) ?? []).contains {
            path == $0 || path.hasPrefix($0 + "/")
        }
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
        let url = URL(fileURLWithPath: "/")
        return try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }

    func formattedAvailableDiskSpace() -> String {
        guard let bytes = availableDiskBytes else { return "?" }
        return formatByteCount(bytes)
    }

    func startupVolumeAccessStatus() -> DiskAccessStatus {
        guard fileManager.fileExists(atPath: fullDiskAccessProbeURL.path) else { return .limited }
        do {
            _ = try Data(contentsOf: fullDiskAccessProbeURL, options: [.mappedIfSafe])
            return .full
        } catch {
            return .limited
        }
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }

    private var historyURL: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/CleanMac/operations.json")
    }

    private func directChildren(of directory: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return [] }
        return contents.filter { !isSymbolicLink($0) }
    }

    private func filesUnder(_ root: URL, modifiedBefore: Date? = nil, cancellation: CancellationToken) -> [URL] {
        guard fileManager.fileExists(atPath: root.path), !isSymbolicLink(root) else { return [] }
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { return [] }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if cancellation.isCancelled { break }
            if isSymbolicLink(url) {
                enumerator.skipDescendants()
                continue
            }
            guard !isDirectory(url) else { continue }
            if let modifiedBefore, let modifiedAt = modificationDate(for: url), modifiedAt >= modifiedBefore { continue }
            files.append(url.standardizedFileURL)
            if files.count >= 2_000 { break }
        }
        return files
    }

    private func directoriesUnder(_ root: URL, cancellation: CancellationToken) -> [URL] {
        guard fileManager.fileExists(atPath: root.path), !isSymbolicLink(root) else { return [] }
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: []) else { return [] }
        var directories: [URL] = []
        for case let url as URL in enumerator {
            if cancellation.isCancelled { break }
            if isSymbolicLink(url) {
                enumerator.skipDescendants()
                continue
            }
            if isDirectory(url) { directories.append(url.standardizedFileURL) }
            if directories.count >= 5_000 { break }
        }
        return directories
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else { return false }
        return type == .typeSymbolicLink
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
        guard candidate.category == .analysis, isDirectory(url) else {
            return sizeOfItem(url)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: []
        ) else { return nil }
        var total: Int64 = 0
        var count = 0
        for case let child as URL in enumerator {
            count += 1
            guard count <= analysisValidationEntryLimit else { return nil }
            if isSymbolicLink(child) {
                enumerator.skipDescendants()
                continue
            }
            guard !isDirectory(child), let size = sizeOfItem(child) else { continue }
            total += size
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
