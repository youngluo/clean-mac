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
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(viewModel.appState == .completed ? Theme.primary : Theme.warning)
            }

            if let summary = viewModel.summary {
                HStack(spacing: 0) {
                    SpaceView(title: "清理前", value: formatBytes(summary.beforeAvailableBytes), color: .secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                    SpaceView(title: "清理后", value: formatBytes(summary.afterAvailableBytes), color: Theme.primary)
                }
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 12) {
                    SummaryMetric(title: "移到废纸篓", value: summary.movedToTrashCount)
                    SummaryMetric(title: "已清理", value: summary.removedCount)
                    SummaryMetric(title: "失败", value: summary.failedCount)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(summary.results) { result in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: result.outcome == .failed ? "xmark.circle" : "checkmark.circle")
                                    .foregroundStyle(result.outcome == .failed ? Theme.warning : Theme.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                    Text(result.message)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 170)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("清理尚未开始，已保留当前扫描结果")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
                .tint(Theme.primary)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "?" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
                .foregroundStyle(.secondary)
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

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
