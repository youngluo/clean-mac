import SwiftUI

struct CandidateReviewSection: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Binding var scrollTarget: CleanupProvider?

    init(viewModel: CleanerViewModel, scrollTarget: Binding<CleanupProvider?> = .constant(nil)) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._scrollTarget = scrollTarget
    }

    private var reviewGroups: [ReviewCandidateGroup] {
        let grouped = Dictionary(grouping: viewModel.reviewCandidates) { candidate in
            candidate.provider
        }
        return grouped
            .map { ReviewCandidateGroup(provider: $0.key, candidates: $0.value) }
            .sorted { providerRank($0.provider) < providerRank($1.provider) }
    }

    var body: some View {
        if !viewModel.reviewCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("可清理项目")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(headerSummary)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.theme.textSecondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)

                Divider()
                    .opacity(0.45)

                    ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(reviewGroups.enumerated()), id: \.element.id) { index, group in
                                VStack(alignment: .leading, spacing: 2) {
                                    if index > 0 {
                                        Divider()
                                            .padding(.vertical, 6)
                                    }

                                    HStack(alignment: .firstTextBaseline) {
                                        Text(group.title)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Color.theme.textSecondary)
                                        Spacer()
                                        Text("\(group.candidates.count) 项")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(Color.theme.textSecondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .id(group.provider)

                                    ForEach(group.candidates) { candidate in
                                        CandidateRowView(
                                            candidate: candidate,
                                            toggle: { viewModel.toggleCandidate(candidate.id) },
                                            exclude: { viewModel.addExclusion(for: candidate.id) }
                                        )
                                    }
                                }
                                .padding(.bottom, 5)
                            }
                        }
                        .padding(.horizontal, 3)
                        .padding(.vertical, 7)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 320, maxHeight: 720)
                    .onAppear {
                        guard let target = scrollTarget else { return }
                        scheduleScroll(to: target, using: proxy)
                    }
                    .onChange(of: scrollTarget) { target in
                        guard let target else { return }
                        scheduleScroll(to: target, using: proxy)
                    }
                }
            }
            .glassPanel(cornerRadius: 12)
        }
    }

    private func providerRank(_ provider: CleanupProvider) -> Int {
        let order: [CleanupProvider] = [.deepCleanup, .projectArtifacts, .applications, .spaceAnalysis]
        return order.firstIndex(of: provider) ?? order.count
    }

    private func scheduleScroll(to target: CleanupProvider, using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            guard scrollTarget == target else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(target, anchor: .top)
            }
            scrollTarget = nil
        }
    }

    private var headerSummary: String {
        switch viewModel.appState {
        case .completed, .partial:
            if let summary = viewModel.summary {
                return "已处理 \(summary.results.count) 项"
            }
            return "清理完成"
        default:
            return "已选 \(viewModel.selectedCount) / \(viewModel.reviewCandidates.count) · \(formatByteCount(viewModel.selectedBytes))"
        }
    }
}

private struct ReviewCandidateGroup: Identifiable {
    let provider: CleanupProvider
    let candidates: [CleanupCandidate]

    var id: CleanupProvider { provider }
    var title: String { provider.title }
}

struct CleanupReviewActions: View {
    @ObservedObject var viewModel: CleanerViewModel
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("确认移到废纸篓") {
                viewModel.requestCleanupConfirmation()
            }
            .buttonStyle(ThemeActionButtonStyle())
            .disabled(viewModel.selectedCount == 0 || viewModel.appState != .awaitingConfirmation && viewModel.summary == nil)
            .pointerCursor()

            Button(viewModel.appState == .awaitingConfirmation ? "取消" : "完成", action: onDone)
                .buttonStyle(ThemeSecondaryButtonStyle())
                .pointerCursor()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct CleanupConfirmationDialogModifier: ViewModifier {
    @ObservedObject var viewModel: CleanerViewModel

    private var selectedIncludesTimeMachine: Bool {
        viewModel.selectedCandidates.contains { $0.removalMode == .timeMachine }
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "确认移到废纸篓？",
                isPresented: $viewModel.isConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("移到废纸篓", role: .destructive) {
                    viewModel.confirmCleanup()
                }
                .pointerCursor()
                Button("取消", role: .cancel) {
                    viewModel.cancelCleanupConfirmation()
                }
                .pointerCursor()
            } message: {
                if selectedIncludesTimeMachine {
                    Text("将处理 \(viewModel.selectedCount) 项，共 \(formatByteCount(viewModel.selectedBytes))。文件和目录会进入 macOS 废纸篓，Time Machine 快照将通过系统维护命令处理。")
                } else {
                    Text("将处理 \(viewModel.selectedCount) 项，共 \(formatByteCount(viewModel.selectedBytes))。文件和目录会进入 macOS 废纸篓。")
                }
            }
    }
}

extension View {
    func cleanupConfirmationDialog(viewModel: CleanerViewModel) -> some View {
        modifier(CleanupConfirmationDialogModifier(viewModel: viewModel))
    }
}
