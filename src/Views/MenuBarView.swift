import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @ObservedObject var languageStore: LocalizationStore

    var body: some View {
        CleanupHomeView(viewModel: viewModel)
            .padding(LayoutSpacing.popoverInset)
            .frame(width: 360)
            // Keep the root transparent so NSPopover owns the same outer
            // surface behind both the content and its arrow.
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
