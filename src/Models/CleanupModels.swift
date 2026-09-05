import Foundation

func formatByteCount(_ bytes: Int64, locale: Locale) -> String {
    guard bytes != 0 else { return L10n.resolve(.appZeroKilobytes, locale: locale) }
    let formatter = MeasurementFormatter()
    formatter.locale = locale
    formatter.unitOptions = .naturalScale
    formatter.numberFormatter.maximumFractionDigits = 1
    return formatter.string(from: Measurement(value: Double(bytes), unit: UnitInformationStorage.bytes))
}

enum CleanupCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case routine
    case analysis
    case developer

    var id: String { rawValue }

    func title(in locale: Locale) -> String {
        switch self {
        case .routine: return L10n.resolve(.categoryRoutineTitle, locale: locale)
        case .analysis: return L10n.resolve(.categoryAnalysisTitle, locale: locale)
        case .developer: return L10n.resolve(.categoryDeveloperTitle, locale: locale)
        }
    }

    func detail(in locale: Locale) -> String {
        switch self {
        case .routine: return L10n.resolve(.categoryRoutineDetail, locale: locale)
        case .analysis: return L10n.resolve(.categoryAnalysisDetail, locale: locale)
        case .developer: return L10n.resolve(.categoryDeveloperDetail, locale: locale)
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

    var titleMessage: LocalizedMessage {
        switch self {
        case .deepCleanup: return .key(.providerDeepCleanupTitle)
        case .applications: return .key(.providerApplicationsTitle)
        case .projectArtifacts: return .key(.providerProjectArtifactsTitle)
        case .spaceAnalysis: return .key(.providerSpaceAnalysisTitle)
        }
    }

    func title(in locale: Locale) -> String {
        switch self {
        case .deepCleanup: return L10n.resolve(.providerDeepCleanupTitle, locale: locale)
        case .applications: return L10n.resolve(.providerApplicationsTitle, locale: locale)
        case .projectArtifacts: return L10n.resolve(.providerProjectArtifactsTitle, locale: locale)
        case .spaceAnalysis: return L10n.resolve(.providerSpaceAnalysisTitle, locale: locale)
        }
    }

    func detail(in locale: Locale) -> String {
        switch self {
        case .deepCleanup: return L10n.resolve(.providerDeepCleanupDetail, locale: locale)
        case .applications: return L10n.resolve(.providerApplicationsDetail, locale: locale)
        case .projectArtifacts: return L10n.resolve(.providerProjectArtifactsDetail, locale: locale)
        case .spaceAnalysis: return L10n.resolve(.providerSpaceAnalysisDetail, locale: locale)
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

    func title(in locale: Locale) -> String {
        switch self {
        case .pending: return L10n.resolve(.providerPending, locale: locale)
        case .running: return L10n.resolve(.providerRunning, locale: locale)
        case .completed: return L10n.resolve(.providerCompleted, locale: locale)
        case .partial: return L10n.resolve(.providerPartial, locale: locale)
        case .skipped: return L10n.resolve(.outcomeSkipped, locale: locale)
        case .failed: return L10n.resolve(.viewFailed, locale: locale)
        }
    }
}

struct CleanupProviderStatus: Identifiable, Codable, Hashable, Sendable {
    let provider: CleanupProvider
    var outcome: CleanupProviderOutcome
    var candidateCount: Int
    var candidateBytes: Int64? = nil
    var message: LocalizedMessage?

    var id: CleanupProvider { provider }
}

enum DiskAccessStatus: String, Equatable, Sendable {
    case full
    case limited

    func title(in locale: Locale) -> String {
        switch self {
        case .full: return L10n.resolve(.diskFullTitle, locale: locale)
        case .limited: return L10n.resolve(.diskLimitedTitle, locale: locale)
        }
    }

    func detail(in locale: Locale) -> String {
        switch self {
        case .full: return L10n.resolve(.diskFullDetail, locale: locale)
        case .limited: return L10n.resolve(.diskLimitedDetail, locale: locale)
        }
    }
}

enum RiskLevel: String, Codable, Hashable, Sendable {
    case safe
    case review
    case advanced
    case protected

    func title(in locale: Locale) -> String {
        switch self {
        case .safe: return L10n.resolve(.riskSafe, locale: locale)
        case .review: return L10n.resolve(.riskReview, locale: locale)
        case .advanced: return L10n.resolve(.riskAdvanced, locale: locale)
        case .protected: return L10n.resolve(.riskProtected, locale: locale)
        }
    }
}

enum RemovalMode: String, Codable, Hashable, Sendable {
    case trash
    case privilegedTrash
    case timeMachine

    func title(in locale: Locale) -> String {
        switch self {
        case .trash: return L10n.resolve(.viewMoveToTrash, locale: locale)
        case .privilegedTrash: return L10n.resolve(.removalPrivilegedTrash, locale: locale)
        case .timeMachine: return L10n.resolve(.removalTimeMachine, locale: locale)
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

    func title(in locale: Locale) -> String {
        switch self {
        case .movedToTrash: return L10n.resolve(.outcomeMovedToTrash, locale: locale)
        case .removed: return L10n.resolve(.viewCleaned, locale: locale)
        case .skipped: return L10n.resolve(.outcomeSkipped, locale: locale)
        case .failed: return L10n.resolve(.viewFailed, locale: locale)
        case .cancelled: return L10n.resolve(.outcomeCancelled, locale: locale)
        }
    }
}

struct FileIdentity: Codable, Hashable, Sendable {
    let value: String
}

struct CleanupCandidate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let url: URL?
    let fileIdentity: FileIdentity?
    let provider: CleanupProvider
    let category: CleanupCategory
    let displayName: String
    let byteSize: Int64?
    let modifiedAt: Date?
    let risk: RiskLevel
    let removalMode: RemovalMode
    let source: LocalizedMessage
    var displayNameMessage: LocalizedMessage?
    var protectionReason: LocalizedMessage?
    var isSelected: Bool
    var outcome: CandidateOutcome?
    var outcomeMessage: LocalizedMessage?

    init(
        id: UUID = UUID(),
        url: URL?,
        fileIdentity: FileIdentity? = nil,
        provider: CleanupProvider,
        category: CleanupCategory,
        displayName: String,
        byteSize: Int64?,
        modifiedAt: Date?,
        risk: RiskLevel,
        removalMode: RemovalMode,
        source: LocalizedMessage,
        displayNameMessage: LocalizedMessage? = nil,
        protectionReason: LocalizedMessage? = nil,
        isSelected: Bool = false,
        outcome: CandidateOutcome? = nil,
        outcomeMessage: LocalizedMessage? = nil
    ) {
        self.id = id
        self.url = url
        self.fileIdentity = fileIdentity
        self.provider = provider
        self.category = category
        self.displayName = displayName
        self.byteSize = byteSize
        self.modifiedAt = modifiedAt
        self.risk = risk
        self.removalMode = removalMode
        self.source = source
        self.displayNameMessage = displayNameMessage
        self.protectionReason = protectionReason
        self.isSelected = isSelected
        self.outcome = outcome
        self.outcomeMessage = outcomeMessage
    }

    var pathDescription: String { url?.path ?? displayName }

    func pathDescription(in locale: Locale) -> String {
        url?.path ?? L10n.resolve(.timeMachineLocalSnapshot, locale: locale)
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
    let message: LocalizedMessage
    var displayNameMessage: LocalizedMessage?
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
    let message: LocalizedMessage
    let isWarning: Bool
}

enum VolumeItemStatus: String, Codable, Hashable, Sendable {
    case measured
    case estimated
    case protected
    case unavailable

    func title(in locale: Locale) -> String {
        switch self {
        case .measured: return L10n.resolve(.volumeMeasured, locale: locale)
        case .estimated: return L10n.resolve(.volumeEstimated, locale: locale)
        case .protected: return L10n.resolve(.volumeProtected, locale: locale)
        case .unavailable: return L10n.resolve(.volumeUnavailable, locale: locale)
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
    let diagnostic: LocalizedMessage?

    init(
        id: UUID = UUID(),
        url: URL,
        displayName: String,
        byteSize: Int64?,
        status: VolumeItemStatus,
        isProtected: Bool = false,
        diagnostic: LocalizedMessage? = nil
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

struct ScanProgress: Equatable, Sendable {
    let category: CleanupCategory
    let stage: LocalizedMessage
    let processedEntries: Int
    let estimatedEntries: Int?
    let diagnosticsCount: Int
    let provider: CleanupProvider?

    init(
        category: CleanupCategory,
        stage: LocalizedMessage,
        processedEntries: Int,
        estimatedEntries: Int?,
        diagnosticsCount: Int,
        provider: CleanupProvider? = nil
    ) {
        self.category = category
        self.stage = stage
        self.processedEntries = processedEntries
        self.estimatedEntries = estimatedEntries
        self.diagnosticsCount = diagnosticsCount
        self.provider = provider
    }
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
    case phase(CleanupPhase, LocalizedMessage)
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
