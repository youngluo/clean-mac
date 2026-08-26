import Foundation
import SwiftUI

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    @Published var candidates: [CleanupCandidate] = []
    @Published var diagnostics: [ScanDiagnostic] = []
    @Published var summary: CleanupSummary?
    @Published var volumeSummary: VolumeAnalysisSummary?
    @Published var scanProgress: ScanProgress?
    @Published var providerStatuses: [CleanupProviderStatus] = []
    @Published var scanIsPartial = false
    @Published private(set) var completedCandidateCount = 0
    @Published private(set) var plannedCandidateCount = 0
    @Published private(set) var diskAccessStatus: DiskAccessStatus
    @Published var history: [CleanupHistoryEntry]
    @Published var isCleaning = false

    var dismissAction: (() -> Void)?

    private let service: CleanerService
    private var worker: Task<Void, Never>?
    private var cancellationToken: CancellationToken?

    init(service: CleanerService = CleanerService()) {
        self.service = service
        self.diskAccessStatus = service.startupVolumeAccessStatus()
        self.history = service.loadHistory()
    }

    var selectedCandidates: [CleanupCandidate] {
        candidates.filter { $0.isSelected && $0.isEligible }
    }

    var selectedCount: Int { selectedCandidates.count }

    var selectedBytes: Int64 {
        selectedCandidates.compactMap(\.byteSize).reduce(0, +)
    }

    var pendingCandidates: [CleanupCandidate] {
        candidates.filter(\.isEligible)
    }

    var reviewCandidates: [CleanupCandidate] {
        candidates.filter { $0.isEligible || $0.outcome != nil }
    }

    var canShowCandidateReview: Bool {
        appState == .awaitingConfirmation || appState == .applying || appState == .completed || appState == .partial
    }

    var totalWorkCount: Int {
        summary?.selectedCount ?? (appState == .applying ? plannedCandidateCount : selectedCount)
    }

    var completedWorkCount: Int {
        guard let summary else { return completedCandidateCount }
        return summary.results.filter { $0.outcome != .skipped }.count
    }

    var progress: Double {
        guard totalWorkCount > 0 else { return 0 }
        return min(Double(completedWorkCount) / Double(totalWorkCount), 1)
    }

    var providerProgress: Double {
        guard !providerStatuses.isEmpty else { return 0 }
        let completed = providerStatuses.filter { status in
            status.outcome == .completed || status.outcome == .partial || status.outcome == .skipped || status.outcome == .failed
        }.count
        return min(Double(completed) / Double(CleanupProvider.allCases.count), 1)
    }

    var availableDiskBytes: Int64? { service.availableDiskBytes }

    func refreshDiskAccessStatus() {
        diskAccessStatus = service.startupVolumeAccessStatus()
    }

    func openFullDiskAccessSettings() {
        service.openFullDiskAccessSettings()
    }

    /// 扫描所有清理 provider。扫描阶段只读，不执行任何清理操作。
    func startQuickClean() {
        guard !isCleaning else { return }
        worker?.cancel()

        let token = CancellationToken()
        cancellationToken = token
        candidates = []
        diagnostics = []
        summary = nil
        volumeSummary = nil
        scanProgress = nil
        providerStatuses = []
        scanIsPartial = false
        completedCandidateCount = 0
        plannedCandidateCount = 0
        isCleaning = true
        appState = .scanning

        let service = self.service
        let stream = AsyncStream<CleanupEvent> { continuation in
            Task.detached(priority: .userInitiated) {
                let unified = service.scanUnified(cancellation: token) { event in
                    continuation.yield(event)
                }
                continuation.yield(.unifiedScanFinished(unified))
                continuation.finish()
            }
        }

        worker = Task { [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                self.handle(event, scanToken: token)
            }
        }
    }

    func executeSelectedCandidates() {
        guard !selectedCandidates.isEmpty else { return }
        executeSelected()
    }

    private func executeSelected() {
        guard !selectedCandidates.isEmpty, !isCleaning else { return }
        let selected = selectedCandidates
        let allCandidates = candidates
        let plan = CleanupPlan(selectedCandidates: selected, allCandidates: allCandidates)
        let token = CancellationToken()
        cancellationToken = token
        isCleaning = true
        appState = .applying
        summary = nil
        completedCandidateCount = 0
        plannedCandidateCount = selected.count

        let service = self.service
        let stream = AsyncStream<CleanupEvent> { continuation in
            Task.detached(priority: .userInitiated) {
                _ = service.execute(plan: plan, cancellation: token) { event in
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }

        worker = Task { [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                self.handle(event)
            }
        }
    }

    func toggleCandidate(_ candidateID: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == candidateID }), candidates[index].isEligible else { return }
        candidates[index].isSelected.toggle()
    }

    func toggleAllEligible() {
        let shouldSelect = candidates.contains { $0.isEligible && !$0.isSelected }
        for index in candidates.indices where candidates[index].isEligible {
            candidates[index].isSelected = shouldSelect
        }
    }

    func addExclusion(for candidateID: UUID) {
        guard let candidate = candidates.first(where: { $0.id == candidateID }), let url = candidate.url else { return }
        service.addExclusion(for: url)
        if let index = candidates.firstIndex(where: { $0.id == candidateID }) {
            candidates[index].isSelected = false
            candidates[index].outcome = .skipped
            candidates[index].protectionReason = .key(.sourceAddedToExclusions)
        }
    }

    func cancelCurrentWork() {
        resetToIdle()
    }

    func resetToIdle() {
        cancellationToken?.cancel()
        worker?.cancel()
        worker = nil
        cancellationToken = nil
        appState = .idle
        isCleaning = false
        candidates = []
        diagnostics = []
        summary = nil
        volumeSummary = nil
        scanProgress = nil
        providerStatuses = []
        scanIsPartial = false
        completedCandidateCount = 0
        plannedCandidateCount = 0
        history = service.loadHistory()
    }

    private func handle(_ event: CleanupEvent, scanToken: CancellationToken? = nil) {
        switch event {
        case .phase, .scanFinished:
            break
        case .candidateDiscovered(let candidate):
            candidates.append(candidate)
            guard let index = providerStatuses.firstIndex(where: { $0.provider == candidate.provider }) else { break }
            providerStatuses[index].candidateCount += 1
            if let byteSize = candidate.byteSize {
                providerStatuses[index].candidateBytes = (providerStatuses[index].candidateBytes ?? 0) + byteSize
            }
        case .scanProgress(let progress):
            if scanProgress != progress {
                scanProgress = progress
            }
        case .diagnostic(let diagnostic):
            if !diagnostics.contains(where: { $0.id == diagnostic.id }) { diagnostics.append(diagnostic) }
        case .providerStatus(let status):
            if let index = providerStatuses.firstIndex(where: { $0.provider == status.provider }) {
                if providerStatuses[index] != status {
                    providerStatuses[index] = status
                }
            } else {
                providerStatuses.append(status)
            }
        case .unifiedScanFinished(let result):
            finishUnifiedScan(result, token: scanToken)
        case .candidateStarted:
            break
        case .candidateCompleted(let result):
            completedCandidateCount += 1
            if let index = candidates.firstIndex(where: { $0.id == result.id }) {
                candidates[index].outcome = result.outcome
                candidates[index].outcomeMessage = result.message
            }
        case .finished(let finalSummary):
            summary = finalSummary
            history = service.loadHistory()
            isCleaning = false
            appState = (finalSummary.isPartial || scanIsPartial) ? .partial : .completed
        }
    }

    private func finishUnifiedScan(_ result: UnifiedScanResult, token: CancellationToken?) {
        guard let token, !token.isCancelled else {
            resetToIdle()
            return
        }
        candidates = result.candidates
        diagnostics = result.diagnostics
        volumeSummary = result.volumeSummary
        providerStatuses = result.providers
        scanProgress = ScanProgress(
            category: .routine,
            stage: .key(.scanCompleteReviewTrashItems),
            processedEntries: result.scannedCount,
            estimatedEntries: result.scannedCount,
            diagnosticsCount: result.diagnostics.count
        )
        scanIsPartial = result.isPartial
        isCleaning = false
        appState = .awaitingConfirmation
    }
}
