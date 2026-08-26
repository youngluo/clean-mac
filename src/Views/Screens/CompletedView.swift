import SwiftUI

struct CompletedView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var completionIconScale = 0.82

    private var title: String {
        switch viewModel.appState {
        case .partial: return L10n.resolve(.viewCleanupPartiallyComplete, locale: locale)
        default: return L10n.resolve(.viewCleanupComplete, locale: locale)
        }
    }

    private var icon: String {
        switch viewModel.appState {
        case .partial: return "exclamationmark.circle.fill"
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
                    .foregroundStyle(statusColor)
                    .scaleEffect(completionIconScale)
            }

            if let summary = viewModel.summary {
                HStack(spacing: 0) {
                    SpaceView(title: L10n.resolve(.viewBeforeCleanup, locale: locale), value: formatBytes(summary.beforeAvailableBytes), color: Color.theme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.theme.textPrimary)
                    SpaceView(title: L10n.resolve(.viewAfterCleanup, locale: locale), value: formatBytes(summary.afterAvailableBytes), color: Color.theme.textPrimary)
                }
                .padding(.vertical, 10)
                .glassPanel()

                HStack(spacing: 12) {
                    SummaryMetric(title: L10n.resolve(.viewMoveToTrash, locale: locale), value: summary.movedToTrashCount, color: Color.theme.success)
                    SummaryMetric(title: L10n.resolve(.viewCleaned, locale: locale), value: summary.removedCount, color: Color.theme.success)
                    SummaryMetric(title: L10n.resolve(.viewFailed, locale: locale), value: summary.failedCount, color: Color.theme.failure)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(summary.results) { result in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: resultIcon(for: result.outcome))
                                    .foregroundStyle(resultColor(for: result.outcome))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.displayNameMessage?.resolve(in: locale) ?? result.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                    Text(result.message.resolve(in: locale))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.theme.textSecondary)
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
                Text(L10n.resolve(.viewNoCleanupResults, locale: locale))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.theme.textSecondary)
                    .padding(.vertical, 24)
            }

            if !viewModel.pendingCandidates.isEmpty {
                CandidateReviewSection(viewModel: viewModel)
            }

            CleanupReviewActions(viewModel: viewModel) {
                viewModel.resetToIdle()
                viewModel.dismissAction?()
            }
        }
        .onAppear {
            guard !reduceMotion else {
                completionIconScale = 1
                return
            }
            withAnimation(.easeOut(duration: 0.25)) {
                completionIconScale = 1
            }
        }
    }

    private func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return L10n.resolve(.appUnknownValue, locale: locale) }
        return formatByteCount(bytes, locale: locale)
    }

    private var statusColor: Color {
        switch viewModel.appState {
        case .completed: return Color.theme.success
        case .partial: return Color.theme.failure
        default: return Color.theme.warning
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
        case .failed: return Color.theme.failure
        case .cancelled: return Color.theme.warning
        case .skipped: return Color.theme.textSecondary
        case .movedToTrash, .removed: return Color.theme.success
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
                .foregroundStyle(Color.theme.textSecondary)
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
                .foregroundStyle(Color.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
