import SwiftUI

@MainActor
final class PanelLayoutState: ObservableObject {
    static let defaultCandidateReviewMaximumHeight: CGFloat = 640
    static let minimumCandidateReviewMaximumHeight: CGFloat = 160

    @Published var candidateReviewMaximumHeight = defaultCandidateReviewMaximumHeight

    func resetCandidateReviewHeight() {
        guard candidateReviewMaximumHeight != Self.defaultCandidateReviewMaximumHeight else { return }
        candidateReviewMaximumHeight = Self.defaultCandidateReviewMaximumHeight
    }
}

struct MenuBarView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @ObservedObject var languageStore: LocalizationStore

    var body: some View {
        CleanupHomeView(viewModel: viewModel)
            .padding(LayoutSpacing.popoverInset)
            .frame(width: 360)
            // Let the native panel material provide the single root surface.
            // The hosting view itself stays transparent.
            .background(Color.clear)
            .environment(\.locale, languageStore.locale)
    }
}

struct CleanupHomeView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: LayoutSpacing.heroSection) {
            HStack(spacing: LayoutSpacing.tight) {
                Image(systemName: "externaldrive")
                Text(L10n.startupDiskHeader(
                    availableSpace: viewModel.availableDiskBytes.map { formatByteCount($0, locale: locale) }
                        ?? L10n.resolve(.appUnknownValue, locale: locale),
                    locale: locale
                ))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.theme.textSecondary)

            switch viewModel.appState {
            case .idle:
                IdleView(viewModel: viewModel)
            case .scanning, .awaitingConfirmation, .applying, .completed, .partial:
                CleaningView(viewModel: viewModel)
            }
        }
    }
}
