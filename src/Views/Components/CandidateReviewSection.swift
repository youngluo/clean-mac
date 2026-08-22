import SwiftUI

struct CandidateReviewSection: View {
    @ObservedObject var viewModel: CleanerViewModel

    private var reviewGroups: [ReviewCandidateGroup] {
        let grouped = Dictionary(grouping: viewModel.pendingCandidates) { candidate in
            groupTitle(for: candidate)
        }
        return grouped
            .map { ReviewCandidateGroup(title: $0.key, candidates: $0.value) }
            .sorted { groupRank($0.title) < groupRank($1.title) }
    }

    var body: some View {
        if !viewModel.pendingCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("清理项目")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("已选 \(viewModel.selectedCount) / \(viewModel.pendingCandidates.count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.theme.textSecondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)

                Divider()
                    .opacity(0.45)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(reviewGroups.enumerated()), id: \.element.id) { index, group in
                            if index > 0 {
                                Divider()
                                    .padding(.vertical, 6)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(group.title)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(Color.theme.textSecondary)
                                    Spacer()
                                    Text("\(group.candidates.count) 项")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(Color.theme.textSecondary)
                                }

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
                .frame(minHeight: 96, maxHeight: 360)
            }
            .glassPanel(cornerRadius: 12)
        }
    }

    private func groupTitle(for candidate: CleanupCandidate) -> String {
        switch candidate.source {
        case "已卸载应用残留": return "应用残留"
        case "安装包", "启动磁盘大文件", "启动磁盘大目录": return "安装包与大文件"
        case "项目构建产物", "npm 缓存", "Homebrew 缓存", "Xcode DerivedData": return "项目与开发缓存"
        case "大文件扫描 · Time Machine": return "Time Machine"
        default: return candidate.category.title
        }
    }

    private func groupRank(_ title: String) -> Int {
        switch title {
        case "应用残留": return 0
        case "安装包与大文件": return 1
        case "项目与开发缓存": return 2
        case "Time Machine": return 3
        default: return 5
        }
    }
}

private struct ReviewCandidateGroup: Identifiable {
    let title: String
    let candidates: [CleanupCandidate]

    var id: String { title }
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
