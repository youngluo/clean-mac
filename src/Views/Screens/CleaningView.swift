import SwiftUI

struct CleaningView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCircleMoving = false

    private var title: String {
        switch viewModel.appState {
        case .scanning: return "正在检查"
        case .awaitingConfirmation: return "检查完成"
        case .applying: return "正在清理"
        default: return "处理中"
        }
    }

    private var iconName: String {
        viewModel.appState == .awaitingConfirmation ? "checkmark" : "eraser"
    }

    private var isWorking: Bool {
        viewModel.appState == .scanning || viewModel.appState == .applying
    }

    private var circleAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return isCircleMoving
            ? .easeInOut(duration: 1.25).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.22)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.theme.primaryAction)
                    .overlay {
                        Circle()
                            .stroke(Color.theme.primaryActionForeground.opacity(0.22), lineWidth: 0.5)
                    }
                    .shadow(
                        color: Color.theme.primaryAction.opacity(isCircleMoving ? 0.32 : 0.18),
                        radius: isCircleMoving ? 16 : 11,
                        y: isCircleMoving ? 8 : 5
                    )

                VStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.theme.primaryActionForeground.opacity(0.92))

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.theme.primaryActionForeground)
                }
            }
            .frame(width: 116, height: 116)
            .scaleEffect(isCircleMoving ? 1.045 : 1)
            .rotationEffect(.degrees(isCircleMoving ? 0.6 : 0))
            .offset(y: isCircleMoving ? -2.5 : 0)
            .animation(circleAnimation, value: isCircleMoving)
            .onAppear {
                isCircleMoving = !reduceMotion && isWorking
            }
            .onChange(of: viewModel.appState) { _ in
                isCircleMoving = !reduceMotion && isWorking
            }

            if viewModel.appState == .applying {
                HStack {
                    Text("已处理 \(viewModel.completedWorkCount)/\(viewModel.totalWorkCount) · \(Int(viewModel.progress * 100))%")
                    Spacer()
                    Text("请保持窗口打开")
                }
                .font(.system(size: 10))
                .foregroundStyle(Color.theme.textSecondary)
            } else if viewModel.appState == .scanning {
                if let progress = viewModel.scanProgress {
                    Text("\(progress.stage) · 已检查 \(progress.processedEntries) 项")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.theme.textSecondary)
                } else {
                    Text("正在读取启动磁盘，完成后可逐项查看")
                        .font(.system(size: 10))
                    .foregroundStyle(Color.theme.textSecondary)
                }
            }

            if !viewModel.providerStatuses.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(viewModel.providerStatuses) { status in
                        ProviderStatusRow(status: status)
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel()
            } else {
                Text("正在准备统一检查")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .glassPanel()
            }

            if viewModel.appState == .awaitingConfirmation {
                CandidateReviewSection(viewModel: viewModel)

                if viewModel.pendingCandidates.isEmpty {
                    Text("没有发现可清理项目")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.theme.textSecondary)
                        .padding(.vertical, 18)
                }

                CleanupReviewActions(viewModel: viewModel) {
                    viewModel.resetToIdle()
                }
            } else {
                Button("取消") { viewModel.cancelCurrentWork() }
                    .buttonStyle(.bordered)
                    .pointerCursor()
            }
        }
        .cleanupConfirmationDialog(viewModel: viewModel)
    }
}

private struct ProviderStatusRow: View {
    let status: CleanupProviderStatus

    var body: some View {
        HStack(spacing: 7) {
            if status.outcome == .running {
                RunningProviderIcon(color: color)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 14)
            }
            Text(status.provider.title)
                .font(.system(size: 10, weight: status.outcome == .running ? .medium : .regular))
            Spacer()
            if status.candidateCount > 0 {
                Text("\(status.candidateCount) 项")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.theme.textSecondary)
            }
            if let candidateBytes = status.candidateBytes, candidateBytes > 0 {
                Text(formatByteCount(candidateBytes))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.theme.textSecondary)
            }
            Text(status.outcome.title)
                .font(.system(size: 9))
                .foregroundStyle(color)
        }
    }

    private var iconName: String {
        switch status.outcome {
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark"
        case .partial: return "exclamationmark.triangle"
        case .failed: return "xmark"
        case .skipped: return "minus"
        case .pending: return "circle"
        }
    }

    private var color: Color {
        switch status.outcome {
        case .running: return Color.theme.inProgress
        case .completed: return Color.theme.success
        case .partial, .failed: return Color.theme.warning
        case .skipped, .pending: return Color.theme.textSecondary
        }
    }
}

private struct RunningProviderIcon: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 14)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                reduceMotion ? nil : .linear(duration: 1.1).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = !reduceMotion
            }
    }
}
