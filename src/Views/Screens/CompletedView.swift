import SwiftUI

struct CompletedView: View {
    @ObservedObject var viewModel: CleanerViewModel

    private var title: String {
        switch viewModel.appState {
        case .partial: return "清理部分完成"
        case .cancelled: return "操作已取消"
        default: return "清理完成"
        }
    }

    private var icon: String {
        switch viewModel.appState {
        case .partial: return "exclamationmark.circle.fill"
        case .cancelled: return "pause.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                BackToIdleButton(viewModel: viewModel)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(statusColor)
            }

            if let summary = viewModel.summary {
                HStack(spacing: 0) {
                    SpaceView(title: "清理前", value: formatBytes(summary.beforeAvailableBytes), color: Theme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    SpaceView(title: "清理后", value: formatBytes(summary.afterAvailableBytes), color: Theme.textPrimary)
                }
                .padding(.vertical, 10)
                .glassPanel()

                HStack(spacing: 12) {
                    SummaryMetric(title: "移到废纸篓", value: summary.movedToTrashCount, color: Theme.success)
                    SummaryMetric(title: "已清理", value: summary.removedCount, color: Theme.success)
                    SummaryMetric(title: "失败", value: summary.failedCount, color: Theme.failure)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(summary.results) { result in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: resultIcon(for: result.outcome))
                                    .foregroundStyle(resultColor(for: result.outcome))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                    Text(result.message)
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 170)
                .glassPanel()
            } else {
                Text("清理尚未开始，已保留当前扫描结果")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 24)
            }

            HStack(spacing: 8) {
                if viewModel.appState == .cancelled && !viewModel.candidates.isEmpty {
                    Button("返回检查") { viewModel.returnToReview() }
                        .buttonStyle(.bordered)
                }
                Button("完成") {
                    viewModel.resetToIdle()
                    viewModel.dismissAction?()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.button)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "?" }
        return formatByteCount(bytes)
    }

    private var statusColor: Color {
        switch viewModel.appState {
        case .completed: return Theme.success
        case .partial: return Theme.failure
        default: return Theme.warning
        }
    }

    private func resultIcon(for outcome: CandidateOutcome) -> String {
        switch outcome {
        case .failed: return "xmark.circle"
        case .cancelled: return "pause.circle"
        case .skipped: return "minus.circle"
        case .movedToTrash, .removed: return "checkmark.circle"
        }
    }

    private func resultColor(for outcome: CandidateOutcome) -> Color {
        switch outcome {
        case .failed: return Theme.failure
        case .cancelled: return Theme.warning
        case .skipped: return Theme.textSecondary
        case .movedToTrash, .removed: return Theme.success
        }
    }
}

private struct SpaceView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
