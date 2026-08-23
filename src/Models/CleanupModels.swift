import Foundation

func formatByteCount(_ bytes: Int64) -> String {
    guard bytes != 0 else { return "0 KB" }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

enum CleanupCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case routine
    case analysis
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routine: return "安全清理"
        case .analysis: return "大文件扫描"
        case .developer: return "开发清理"
        }
    }

    var detail: String {
        switch self {
        case .routine: return "清理已知安全的缓存和旧日志"
        case .analysis: return "扫描启动磁盘中的文件、目录和本地快照"
        case .developer: return "清理项目构建产物和工具缓存"
        }
    }

    var iconName: String {
        switch self {
        case .routine: return "sparkles"
        case .analysis: return "magnifyingglass"
        case .developer: return "hammer"
        }
    }
}

enum CleanupProvider: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case deepCleanup
    case applications
    case projectArtifacts
    case spaceAnalysis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepCleanup: return "缓存清理"
        case .applications: return "应用残留"
        case .projectArtifacts: return "项目清理"
        case .spaceAnalysis: return "空间分析"
        }
    }

    var detail: String {
        switch self {
        case .deepCleanup: return "正在查找缓存与旧日志。"
        case .applications: return "正在查找已卸载应用留下的数据。"
        case .projectArtifacts: return "正在查找超过 30 天未更新且当前未使用的项目产物和 node_modules。"
        case .spaceAnalysis: return "正在查找安装包、大文件和本地快照。"
        }
    }
}

enum CleanupProviderOutcome: String, Codable, Hashable, Sendable {
    case pending
    case running
    case completed
    case partial
    case skipped
    case failed

    var title: String {
        switch self {
        case .pending: return "待扫描"
        case .running: return "扫描中"
        case .completed: return "已完成"
        case .partial: return "部分完成"
        case .skipped: return "已跳过"
        case .failed: return "失败"
        }
    }
}

struct CleanupProviderStatus: Identifiable, Codable, Hashable, Sendable {
    let provider: CleanupProvider
    var outcome: CleanupProviderOutcome
    var candidateCount: Int
    var candidateBytes: Int64? = nil
    var message: String?

    var id: CleanupProvider { provider }
}

enum DiskAccessStatus: String, Equatable, Sendable {
    case full
    case limited

    var title: String {
        switch self {
        case .full: return "访问权限完整"
        case .limited: return "访问范围受限"
        }
    }

    var detail: String {
        switch self {
        case .full: return "大文件扫描可以读取更多系统目录"
        case .limited: return "仍可扫描，但部分系统和应用数据无法读取"
        }
    }
}

enum RiskLevel: String, Codable, Hashable, Sendable {
    case safe
    case review
    case advanced
    case protected

    var title: String {
        switch self {
        case .safe: return "安全"
        case .review: return "需检查"
        case .advanced: return "高级操作"
        case .protected: return "已保护"
        }
    }
}

enum RemovalMode: String, Codable, Hashable, Sendable {
    case trash
    case privilegedTrash
    case timeMachine

    var title: String {
        switch self {
        case .trash: return "移到废纸篓"
        case .privilegedTrash: return "移到废纸篓（需要权限）"
        case .timeMachine: return "快照维护"
        }
    }

    var isTrash: Bool {
        self == .trash || self == .privilegedTrash
    }
}

enum CandidateOutcome: String, Codable, Hashable, Sendable {
    case movedToTrash
    case removed
    case skipped
    case failed
    case cancelled

    var title: String {
        switch self {
        case .movedToTrash: return "已移到废纸篓"
        case .removed: return "已清理"
        case .skipped: return "已跳过"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}

struct CleanupCandidate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let url: URL?
    let provider: CleanupProvider
    let category: CleanupCategory
    let displayName: String
    let byteSize: Int64?
    let modifiedAt: Date?
    let risk: RiskLevel
    let removalMode: RemovalMode
    let source: String
    var protectionReason: String?
    var isSelected: Bool
    var outcome: CandidateOutcome?

    init(
        id: UUID = UUID(),
        url: URL?,
        provider: CleanupProvider,
        category: CleanupCategory,
        displayName: String,
        byteSize: Int64?,
        modifiedAt: Date?,
        risk: RiskLevel,
        removalMode: RemovalMode,
        source: String,
        protectionReason: String? = nil,
        isSelected: Bool = false,
        outcome: CandidateOutcome? = nil
    ) {
        self.id = id
        self.url = url
        self.provider = provider
        self.category = category
        self.displayName = displayName
        self.byteSize = byteSize
        self.modifiedAt = modifiedAt
        self.risk = risk
        self.removalMode = removalMode
        self.source = source
        self.protectionReason = protectionReason
        self.isSelected = isSelected
        self.outcome = outcome
    }

    var pathDescription: String {
        url?.path ?? "Time Machine 本地快照"
    }

    var isProtected: Bool {
        risk == .protected || protectionReason != nil
    }

    var isEligible: Bool {
        !isProtected && outcome == nil
    }
}

struct CandidateResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let category: CleanupCategory
    let displayName: String
    let path: String
    let byteSize: Int64?
    let removalMode: RemovalMode
    let outcome: CandidateOutcome
    let message: String
    let finishedAt: Date
}

struct CategorySummary: Identifiable, Codable, Hashable, Sendable {
    let category: CleanupCategory
    let scannedCount: Int
    let selectedCount: Int
    let movedToTrashCount: Int
    let removedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let cancelledCount: Int
    let affectedBytes: Int64

    var id: CleanupCategory { category }
}

struct CleanupSummary: Codable, Hashable, Sendable {
    let startedAt: Date
    let finishedAt: Date
    let beforeAvailableBytes: Int64?
    let afterAvailableBytes: Int64?
    let scannedCount: Int
    let selectedCount: Int
    let results: [CandidateResult]
    let categories: [CategorySummary]

    var movedToTrashCount: Int {
        results.filter { $0.outcome == .movedToTrash }.count
    }

    var removedCount: Int {
        results.filter { $0.outcome == .removed }.count
    }

    var failedCount: Int {
        results.filter { $0.outcome == .failed }.count
    }

    var skippedCount: Int {
        results.filter { $0.outcome == .skipped }.count
    }

    var cancelledCount: Int {
        results.filter { $0.outcome == .cancelled }.count
    }

    var isPartial: Bool {
        failedCount > 0 || cancelledCount > 0
    }
}

struct ScanDiagnostic: Identifiable, Hashable, Sendable {
    let id = UUID()
    let category: CleanupCategory
    let message: String
    let isWarning: Bool
}

enum VolumeItemStatus: String, Codable, Hashable, Sendable {
    case measured
    case estimated
    case protected
    case unavailable

    var title: String {
        switch self {
        case .measured: return "已测量"
        case .estimated: return "估算"
        case .protected: return "受保护"
        case .unavailable: return "不可读取"
        }
    }
}

struct VolumeUsageItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let displayName: String
    let byteSize: Int64?
    let status: VolumeItemStatus
    let isProtected: Bool
    let diagnostic: String?

    init(
        id: UUID = UUID(),
        url: URL,
        displayName: String,
        byteSize: Int64?,
        status: VolumeItemStatus,
        isProtected: Bool = false,
        diagnostic: String? = nil
    ) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.byteSize = byteSize
        self.status = status
        self.isProtected = isProtected
        self.diagnostic = diagnostic
    }
}

struct VolumeAnalysisSummary: Codable, Hashable, Sendable {
    let volumeURL: URL
    let volumeName: String
    let totalBytes: Int64?
    let availableBytes: Int64?
    let measuredBytes: Int64
    let usageItems: [VolumeUsageItem]
    let processedEntryCount: Int
    let candidateCount: Int
    let isPartial: Bool
}

struct ScanProgress: Sendable {
    let category: CleanupCategory
    let stage: String
    let processedEntries: Int
    let estimatedEntries: Int?
    let diagnosticsCount: Int
}

struct ScanResult: Sendable {
    let category: CleanupCategory
    let candidates: [CleanupCandidate]
    let diagnostics: [ScanDiagnostic]
    let scannedCount: Int
    let isPartial: Bool
    let volumeSummary: VolumeAnalysisSummary?

    init(
        category: CleanupCategory,
        candidates: [CleanupCandidate],
        diagnostics: [ScanDiagnostic],
        scannedCount: Int,
        isPartial: Bool = false,
        volumeSummary: VolumeAnalysisSummary? = nil
    ) {
        self.category = category
        self.candidates = candidates
        self.diagnostics = diagnostics
        self.scannedCount = scannedCount
        self.isPartial = isPartial
        self.volumeSummary = volumeSummary
    }
}

enum CleanupPhase: String, Sendable {
    case scanning
    case applying
    case completed
}

enum CleanupEvent: Sendable {
    case phase(CleanupPhase, String)
    case scanProgress(ScanProgress)
    case candidateDiscovered(CleanupCandidate)
    case diagnostic(ScanDiagnostic)
    case providerStatus(CleanupProviderStatus)
    case scanFinished(ScanResult)
    case unifiedScanFinished(UnifiedScanResult)
    case candidateStarted(UUID)
    case candidateCompleted(CandidateResult)
    case finished(CleanupSummary)
}

struct UnifiedScanResult: Sendable {
    let candidates: [CleanupCandidate]
    let diagnostics: [ScanDiagnostic]
    let scannedCount: Int
    let isPartial: Bool
    let volumeSummary: VolumeAnalysisSummary?
    let providers: [CleanupProviderStatus]

    var eligibleCandidates: [CleanupCandidate] {
        candidates.filter(\.isEligible)
    }
}

struct CleanupPlan: Sendable {
    let selectedCandidates: [CleanupCandidate]
    let allCandidates: [CleanupCandidate]
    let confirmedAt: Date

    init(
        selectedCandidates: [CleanupCandidate],
        allCandidates: [CleanupCandidate],
        confirmedAt: Date = Date()
    ) {
        self.selectedCandidates = selectedCandidates
        self.allCandidates = allCandidates
        self.confirmedAt = confirmedAt
    }
}

struct CleanupHistoryEntry: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let finishedAt: Date
    let categories: [CleanupCategory]
    let summary: CleanupSummary
}

final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
