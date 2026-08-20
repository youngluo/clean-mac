import Foundation
import SwiftUI

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    @Published var candidates: [CleanupCandidate] = []
    @Published var diagnostics: [ScanDiagnostic] = []
    @Published var events: [CleanupEvent] = []
    @Published var summary: CleanupSummary?
    @Published var history: [CleanupHistoryEntry]
    @Published var currentCategory: CleanupCategory?
    @Published var currentCandidateID: UUID?
    @Published var isCleaning = false

    var dismissAction: (() -> Void)?
    var refocusAction: (() -> Void)?

    private let service: CleanerService
    private var worker: Task<Void, Never>?
    private var cancellationToken: CancellationToken?

    init(service: CleanerService = CleanerService()) {
        self.service = service
        self.history = service.loadHistory()
    }

    var selectedCandidates: [CleanupCandidate] {
        candidates.filter { $0.isSelected && $0.isEligible }
    }

    var selectedCount: Int { selectedCandidates.count }

    var selectedBytes: Int64 {
        selectedCandidates.compactMap(\.byteSize).reduce(0, +)
    }

    var totalWorkCount: Int {
        summary?.selectedCount ?? selectedCount
    }

    var completedWorkCount: Int {
        guard let summary else { return events.compactMap { event in
            if case .candidateCompleted = event { return 1 }
            return nil
        }.count }
        return summary.results.filter { $0.outcome != .skipped }.count
    }

    var progress: Double {
        guard totalWorkCount > 0 else { return 0 }
        return min(Double(completedWorkCount) / Double(totalWorkCount), 1)
    }

    var availableDiskSpace: String { service.formattedAvailableDiskSpace() }

    func startScan(category: CleanupCategory) {
        guard !isCleaning else { return }
        worker?.cancel()
        let token = CancellationToken()
        cancellationToken = token
        currentCategory = category
        candidates = []
        diagnostics = []
        events = [.phase(.scanning, "正在扫描\(category.title)")]
        summary = nil
        isCleaning = true
        appState = .scanning(category)

        let service = self.service
        worker = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                service.scan(category: category, cancellation: token)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.finishScan(result, token: token)
        }
    }

    func startCleanup() {
        applySelected()
    }

    func applySelected() {
        guard !selectedCandidates.isEmpty, !isCleaning else { return }
        let selected = selectedCandidates
        let allCandidates = candidates
        let token = CancellationToken()
        cancellationToken = token
        isCleaning = true
        appState = .applying
        summary = nil
        events.append(.phase(.applying, "正在准备清理"))

        let service = self.service
        let stream = AsyncStream<CleanupEvent> { continuation in
            Task.detached(priority: .userInitiated) {
                _ = service.apply(selected: selected, allCandidates: allCandidates, cancellation: token) { event in
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
            candidates[index].protectionReason = "已加入排除列表"
        }
    }

    func cancelCurrentWork() {
        cancellationToken?.cancel()
        worker?.cancel()
        worker = nil
        isCleaning = false
        appState = .cancelled
        currentCandidateID = nil
    }

    func returnToReview() {
        guard !candidates.isEmpty else {
            resetToIdle()
            return
        }
        summary = nil
        isCleaning = false
        appState = .review
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
        events = []
        summary = nil
        currentCategory = nil
        currentCandidateID = nil
        history = service.loadHistory()
    }

    private func finishScan(_ result: ScanResult, token: CancellationToken) {
        guard !token.isCancelled else {
            isCleaning = false
            appState = .cancelled
            return
        }
        candidates = result.candidates
        diagnostics = result.diagnostics
        events.append(contentsOf: result.candidates.map { .candidateDiscovered($0) })
        events.append(contentsOf: result.diagnostics.map { .diagnostic($0) })
        isCleaning = false
        appState = .review
        refocusAction?()
    }

    private func handle(_ event: CleanupEvent) {
        events.append(event)
        switch event {
        case .phase:
            break
        case .candidateDiscovered(let candidate):
            if !candidates.contains(where: { $0.id == candidate.id }) { candidates.append(candidate) }
        case .diagnostic(let diagnostic):
            if !diagnostics.contains(where: { $0.id == diagnostic.id }) { diagnostics.append(diagnostic) }
        case .candidateStarted(let id):
            currentCandidateID = id
            refocusAction?()
        case .candidateCompleted(let result):
            if let index = candidates.firstIndex(where: { $0.id == result.id }) {
                candidates[index].outcome = result.outcome
            }
            currentCandidateID = nil
        case .finished(let finalSummary):
            summary = finalSummary
            history = service.loadHistory()
            isCleaning = false
            currentCandidateID = nil
            appState = finalSummary.isPartial ? .partial : .completed
            refocusAction?()
        }
    }
}
