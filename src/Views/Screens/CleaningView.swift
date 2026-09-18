import SwiftUI

struct CleaningView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.locale) private var locale
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

    private var isBreathing: Bool {
        viewModel.appState == .scanning
    }

    var body: some View {
        VStack(spacing: LayoutSpacing.section) {
            VStack(spacing: LayoutSpacing.heroSection) {
                PrimaryActionCircle(title: title, isBreathing: isBreathing)

                if showingScanProgressPrompt {
                    ScanProgressPromptView(text: scanProgressPrompt)
                }
            }
            .padding(
                .bottom,
                showingScanProgressPrompt
                    ? LayoutSpacing.heroSection - LayoutSpacing.section
                    : LayoutSpacing.heroClearance
            )

            if !viewModel.providerStatuses.isEmpty {
                VStack(alignment: .leading, spacing: LayoutSpacing.tight) {
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
                .padding(.horizontal, LayoutSpacing.panelHorizontal)
                .padding(.vertical, LayoutSpacing.panelVertical)
                .frame(maxWidth: .infinity, alignment: .leading)
                .subtleGlassPanel()
            }

            if viewModel.canShowCandidateReview {
                CandidateReviewSection(viewModel: viewModel, scrollTarget: $candidateGroupTarget)

                if viewModel.appState == .awaitingConfirmation && viewModel.pendingCandidates.isEmpty {
                    Text(L10n.resolve(.viewNoCleanupItems, locale: locale))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.theme.textSecondary)
                        .padding(.vertical, LayoutSpacing.emptyStateVertical)
                }

                if viewModel.appState == .awaitingConfirmation || viewModel.appState == .applying || viewModel.appState == .completed || viewModel.appState == .partial {
                    CleanupReviewActions(viewModel: viewModel) {
                        viewModel.resetToIdle()
                    }
                }
            } else {
                Button(L10n.resolve(.viewCancel, locale: locale)) { viewModel.cancelCurrentWork() }
                    .buttonStyle(ThemeSecondaryButtonStyle())
                    .pointerCursor()
            }
        }
    }

    private var candidateGroupTitles: Set<CleanupProvider> {
        Set(viewModel.reviewCandidates.map(\.provider))
    }

    private var runningProvider: CleanupProvider? {
        viewModel.providerStatuses.first { $0.outcome == .running }?.provider
    }

    private var showingScanProgressPrompt: Bool {
        viewModel.appState == .scanning
    }

    private var scanProgressPrompt: String {
        guard let progress = viewModel.scanProgress else {
            return runningProvider?.detail(in: locale)
                ?? L10n.resolve(.viewPreparingUnifiedScan, locale: locale)
        }
        if progress.provider == nil {
            return progress.stage.resolve(in: locale)
        }
        guard let provider = runningProvider, progress.provider == provider else {
            return runningProvider?.detail(in: locale)
                ?? progress.stage.resolve(in: locale)
        }
        if progress.stage == provider.titleMessage {
            return provider.detail(in: locale)
        }
        return progress.stage.resolve(in: locale)
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
            HStack(spacing: LayoutSpacing.inline) {
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
        case .partial where status.provider == .spaceAnalysis && status.candidateCount > 0: return "checkmark"
        case .partial where status.candidateCount == 0: return "checkmark"
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
        case .partial where status.provider == .spaceAnalysis && status.candidateCount > 0: return Color.theme.success
        case .partial where status.candidateCount == 0: return Color.theme.success
        case .partial: return Color.theme.textSecondary
        case .failed: return Color.theme.failure
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
