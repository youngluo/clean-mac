import SwiftUI

struct CleaningView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var isCircleMoving = false
    @State private var candidateGroupTarget: CleanupProvider?

    private var title: String {
        switch viewModel.appState {
        case .scanning: return L10n.resolve(.viewScanning, locale: locale)
        case .awaitingConfirmation: return L10n.resolve(.viewScanComplete, locale: locale)
        case .applying: return L10n.resolve(.viewCleaning, locale: locale)
        case .completed, .partial: return L10n.resolve(.viewCleanupComplete, locale: locale)
        default: return L10n.resolve(.viewProcessing, locale: locale)
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
                        text: runningProvider?.detail(in: locale) ?? "",
                        isActive: showingScanDetail
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: showingScanDetail ? 13 : 0, alignment: .leading)
                        .opacity(showingScanDetail ? 1 : 0)
                        .clipped()

                    ForEach(viewModel.providerStatuses) { status in
                        ProviderStatusRow(
                            status: status,
                            liveScannedCount: liveScannedCount(for: status),
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
                Text(L10n.resolve(.viewPreparingUnifiedScan, locale: locale))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .glassPanel()
            }

            if viewModel.canShowCandidateReview {
                CandidateReviewSection(viewModel: viewModel, scrollTarget: $candidateGroupTarget)

                if viewModel.appState == .awaitingConfirmation && viewModel.pendingCandidates.isEmpty {
                    Text(L10n.resolve(.viewNoCleanupItems, locale: locale))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.theme.textSecondary)
                        .padding(.vertical, 18)
                }

                if viewModel.appState == .awaitingConfirmation || viewModel.appState == .completed || viewModel.appState == .partial {
                    CleanupReviewActions(viewModel: viewModel) {
                        viewModel.resetToIdle()
                    }
                }
            } else {
                Button(L10n.resolve(.viewCancel, locale: locale)) { viewModel.cancelCurrentWork() }
                    .buttonStyle(.bordered)
                    .pointerCursor()
            }
        }
    }

    private var providerSectionTitle: String {
        switch viewModel.appState {
        case .awaitingConfirmation, .applying, .completed, .partial:
            return L10n.resolve(.viewScannedComplete, locale: locale)
        default:
            return L10n.resolve(.viewScanProgress, locale: locale)
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

    private func liveScannedCount(for status: CleanupProviderStatus) -> Int? {
        guard status.outcome == .running else { return nil }
        guard viewModel.scanProgress?.provider == status.provider else { return 0 }
        return viewModel.scanProgress?.processedEntries ?? 0
    }
}

private struct ProviderStatusRow: View {
    let status: CleanupProviderStatus
    let liveScannedCount: Int?
    let isNavigable: Bool
    let action: () -> Void
    @Environment(\.locale) private var locale

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
                Text(status.provider.title(in: locale))
                    .font(.system(size: 10, weight: status.outcome == .running ? .medium : .regular))
                    .foregroundStyle(Color.theme.textPrimary)
                Spacer()
                if status.outcome == .running {
                    Text(L10n.scannedItems(liveScannedCount ?? 0, locale: locale))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.theme.textSecondary)
                } else if status.outcome == .completed || status.outcome == .partial || status.outcome == .failed || status.outcome == .skipped {
                    Text(L10n.itemCount(status.candidateCount, locale: locale))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.theme.textSecondary)
                }
                if status.outcome != .running {
                    if let candidateBytes = status.candidateBytes, candidateBytes > 0 {
                        Text(formatByteCount(candidateBytes, locale: locale))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.theme.textSecondary)
                    } else if status.provider == .spaceAnalysis && status.candidateCount > 0 {
                        Text(L10n.resolve(.viewUnknownSize, locale: locale))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.theme.textSecondary)
                    }
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
