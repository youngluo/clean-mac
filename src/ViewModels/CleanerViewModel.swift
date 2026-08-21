import Foundation
import SwiftUI

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var appState: AppState = .idle
    @Published var candidates: [CleanupCandidate] = []
    @Published var diagnostics: [ScanDiagnostic] = []
    @Published var events: [CleanupEvent] = []
    @Published var summary: CleanupSummary?
    @Published var volumeSummary: VolumeAnalysisSummary?
    @Published var scanProgress: ScanProgress?
    @Published var scanIsPartial = false
    @Published private(set) var diskAccessStatus: DiskAccessStatus
    @Published var history: [CleanupHistoryEntry]
    @Published var currentCategory: CleanupCategory?
    @Published var currentCandidateID: UUID?
    @Published var isCleaning = false

    var dismissAction: (() -> Void)?
    var refocusAction: (() -> Void)?

    private let service: CleanerService
    private var worker: Task<Void, Never>?
    private var cancellationToken: CancellationToken?
    private var quickCleanInProgress = false

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

    func refreshDiskAccessStatus() {
        diskAccessStatus = service.startupVolumeAccessStatus()
    }

    func openFullDiskAccessSettings() {
        service.openFullDiskAccessSettings()
    }

    func startScan(category: CleanupCategory) {
        guard !isCleaning else { return }
        worker?.cancel()
        quickCleanInProgress = false
        if category == .analysis {
            refreshDiskAccessStatus()
        }
        let token = CancellationToken()
        cancellationToken = token
        currentCategory = category
        candidates = []
        diagnostics = []
        events = [.phase(.scanning, "正在扫描\(category.title)")]
        summary = nil
        volumeSummary = nil
        scanProgress = nil
        scanIsPartial = false
        isCleaning = true
        appState = .scanning(category)

        let service = self.service
        let stream = AsyncStream<CleanupEvent> { continuation in
            Task.detached(priority: .userInitiated) {
                let result = service.scan(category: category, cancellation: token) { event in
                    continuation.yield(event)
                }
                result.candidates.forEach { continuation.yield(.candidateDiscovered($0)) }
                result.diagnostics.forEach { continuation.yield(.diagnostic($0)) }
                continuation.yield(.scanFinished(result))
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

    /// 扫描并自动清理明确安全的缓存、旧日志和开发工具缓存。
    /// 需要用户判断的大文件、项目产物和 Time Machine 快照仍保留在手动分析流程中。
    func startQuickClean() {
        guard !isCleaning else { return }
        worker?.cancel()

        let token = CancellationToken()
        cancellationToken = token
        quickCleanInProgress = true
        currentCategory = nil
        candidates = []
        diagnostics = []
        events = [.phase(.scanning, "正在准备一键清理")]
        summary = nil
        volumeSummary = nil
        scanProgress = nil
        scanIsPartial = false
        isCleaning = true
        appState = .scanning(.routine)

        let service = self.service
        let stream = AsyncStream<CleanupEvent> { continuation in
            Task.detached(priority: .userInitiated) {
                continuation.yield(.phase(.scanning, "正在检查安全缓存和旧日志"))
                let routine = service.scan(category: .routine, cancellation: token) { event in
                    continuation.yield(event)
                }

                guard !token.isCancelled else {
                    continuation.yield(.scanFinished(routine))
                    continuation.finish()
                    return
                }

                continuation.yield(.phase(.scanning, "正在检查开发工具缓存"))
                let developer = service.scan(category: .developer, cancellation: token) { event in
                    continuation.yield(event)
                }
                let combined = ScanResult(
                    category: .routine,
                    candidates: routine.candidates + developer.candidates,
                    diagnostics: routine.diagnostics + developer.diagnostics,
                    scannedCount: routine.scannedCount + developer.scannedCount,
                    isPartial: routine.isPartial || developer.isPartial
                )
                continuation.yield(.scanFinished(combined))

                let selected = combined.candidates.filter { $0.isSelected && $0.isEligible }
                _ = service.apply(
                    selected: selected,
                    allCandidates: combined.candidates,
                    cancellation: token
                ) { event in
                    continuation.yield(event)
                }
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
        quickCleanInProgress = false
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
        quickCleanInProgress = false
        appState = .idle
        isCleaning = false
        candidates = []
        diagnostics = []
        events = []
        summary = nil
        volumeSummary = nil
        scanProgress = nil
        scanIsPartial = false
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
        volumeSummary = result.volumeSummary
        scanIsPartial = result.isPartial
        if quickCleanInProgress {
            // 一键清理继续直接进入执行阶段，不中断成“扫描结果”页面。
            appState = .applying
        } else {
            isCleaning = false
            appState = .review
            refocusAction?()
        }
    }

    private func handle(_ event: CleanupEvent, scanToken: CancellationToken? = nil) {
        switch event {
        case .phase:
            events.append(event)
            break
        case .scanProgress(let progress):
            scanProgress = progress
            if let index = events.lastIndex(where: { event in
                if case .scanProgress = event { return true }
                return false
            }) {
                events[index] = event
            } else {
                events.append(event)
            }
        case .candidateDiscovered(let candidate):
            events.append(event)
            if !candidates.contains(where: { $0.id == candidate.id }) { candidates.append(candidate) }
        case .diagnostic(let diagnostic):
            events.append(event)
            if !diagnostics.contains(where: { $0.id == diagnostic.id }) { diagnostics.append(diagnostic) }
        case .scanFinished(let result):
            events.append(event)
            guard let scanToken else { return }
            finishScan(result, token: scanToken)
        case .candidateStarted(let id):
            events.append(event)
            currentCandidateID = id
            refocusAction?()
        case .candidateCompleted(let result):
            events.append(event)
            if let index = candidates.firstIndex(where: { $0.id == result.id }) {
                candidates[index].outcome = result.outcome
            }
            currentCandidateID = nil
        case .finished(let finalSummary):
            events.append(event)
            summary = finalSummary
            history = service.loadHistory()
            isCleaning = false
            quickCleanInProgress = false
            currentCandidateID = nil
            appState = finalSummary.isPartial ? .partial : .completed
            refocusAction?()
        }
    }
}
