import SwiftUI

struct CleaningView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCircleMoving = false
    @State private var candidateGroupTarget: CleanupProvider?

    private var title: String {
        switch viewModel.appState {
        case .scanning: return "正在扫描"
        case .awaitingConfirmation: return "扫描完成"
        case .applying: return "正在清理"
        case .completed, .partial: return "清理完成"
        default: return "处理中"
        }
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

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.theme.primaryActionForeground)
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

            if !viewModel.providerStatuses.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(providerSectionTitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.theme.textSecondary)
                    }

                    MarqueeText(
                        text: runningProvider?.detail ?? "",
                        isActive: showingScanDetail
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: showingScanDetail ? 13 : 0, alignment: .leading)
                        .opacity(showingScanDetail ? 1 : 0)
                        .clipped()

                    ForEach(viewModel.providerStatuses) { status in
                        ProviderStatusRow(
                            status: status,
                            isNavigable: viewModel.canShowCandidateReview && candidateGroupTitles.contains(status.provider)
                        ) {
                            candidateGroupTarget = status.provider
                        }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel()
            } else {
                Text("正在准备统一扫描")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .glassPanel()
            }

            if viewModel.canShowCandidateReview {
                CandidateReviewSection(viewModel: viewModel, scrollTarget: $candidateGroupTarget)

                if viewModel.appState == .awaitingConfirmation && viewModel.pendingCandidates.isEmpty {
                    Text("没有发现可清理项目")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.theme.textSecondary)
                        .padding(.vertical, 18)
                }

                if viewModel.appState == .awaitingConfirmation {
                    CleanupReviewActions(viewModel: viewModel) {
                        viewModel.resetToIdle()
                    }
                } else if viewModel.appState == .completed || viewModel.appState == .partial {
                    Button("完成") {
                        viewModel.resetToIdle()
                    }
                    .buttonStyle(ThemeSecondaryButtonStyle())
                    .pointerCursor()
                }
            } else {
                Button("取消") { viewModel.cancelCurrentWork() }
                    .buttonStyle(.bordered)
                    .pointerCursor()
            }
        }
        .cleanupConfirmationDialog(viewModel: viewModel)
    }

    private var providerSectionTitle: String {
        switch viewModel.appState {
        case .awaitingConfirmation, .applying, .completed, .partial:
            return "已扫描完成"
        default:
            return "扫描进度"
        }
    }

    private var candidateGroupTitles: Set<CleanupProvider> {
        Set(viewModel.reviewCandidates.map(\.provider))
    }

    private var runningProvider: CleanupProvider? {
        viewModel.providerStatuses.first { $0.outcome == .running }?.provider
    }

    private var showingScanDetail: Bool {
        viewModel.appState == .scanning && runningProvider != nil
    }

    private var scanDetailAnimationKey: String {
        "\(showingScanDetail)-\(runningProvider?.rawValue ?? "none")"
    }
}

private struct ProviderStatusRow: View {
    let status: CleanupProviderStatus
    let isNavigable: Bool
    let action: () -> Void

    var body: some View {
        if isNavigable {
            navigableButton
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    .foregroundStyle(Color.theme.textPrimary)
                Spacer()
                if status.outcome == .running || status.candidateCount > 0 {
                    Text("\(status.candidateCount) 项")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.theme.textSecondary)
                }
                if let candidateBytes = status.candidateBytes, candidateBytes > 0 {
                    Text(formatByteCount(candidateBytes))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.theme.textSecondary)
                } else if status.provider == .spaceAnalysis && status.candidateCount > 0 {
                    Text("大小未知")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.theme.textSecondary)
                }
            }
            .frame(minHeight: 18)
        }
    }

    private var navigableButton: some View {
        Button(action: action) {
            rowContent
        }
        .buttonStyle(.plain)
        .pointerCursor()
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

private struct MarqueeText: View {
    let text: String
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private let gap: CGFloat = 28

    private var shouldScroll: Bool {
        isActive && !reduceMotion && contentWidth > containerWidth + 1
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if shouldScroll {
                    HStack(spacing: gap) {
                        label
                        label
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: offset)
                } else {
                    label
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
            .onAppear {
                containerWidth = proxy.size.width
                restartAnimation()
            }
            .onChange(of: proxy.size.width) { width in
                containerWidth = width
                restartAnimation()
            }
        }
        .frame(height: 13)
        .background {
            label
                .fixedSize(horizontal: true, vertical: false)
                .hidden()
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { contentWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { width in
                                contentWidth = width
                            }
                    }
                }
        }
        .onChange(of: text) { _ in
            offset = 0
            restartAnimation()
        }
        .onChange(of: contentWidth) { _ in
            restartAnimation()
        }
        .onChange(of: isActive) { _ in
            offset = 0
            restartAnimation()
        }
    }

    private var label: some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(Color.theme.textSecondary)
    }

    private func restartAnimation() {
        guard shouldScroll else {
            offset = 0
            return
        }

        let distance = contentWidth + gap
        offset = 0
        withAnimation(.linear(duration: max(6, Double(distance / 28))).repeatForever(autoreverses: false)) {
            offset = -distance
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
