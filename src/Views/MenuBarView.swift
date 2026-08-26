import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @ObservedObject var languageStore: LocalizationStore

    var body: some View {
        CleanupHomeView(viewModel: viewModel)
            .padding(16)
            .frame(width: 360)
            .background(.ultraThinMaterial)
            .environment(\.locale, languageStore.locale)
    }
}

struct CleanupHomeView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: viewModel.appState == .idle ? 18 : 14) {
            VStack(spacing: 7) {
                Text("CleanMac")
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 5) {
                    Image(systemName: "externaldrive")
                    Text(L10n.startupDiskHeader(
                        availableSpace: viewModel.availableDiskBytes.map { formatByteCount($0, locale: locale) }
                            ?? L10n.resolve(.appUnknownValue, locale: locale),
                        locale: locale
                    ))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.theme.textSecondary)
            }

            switch viewModel.appState {
            case .idle:
                IdleView(viewModel: viewModel)
            case .scanning, .awaitingConfirmation, .applying:
                CleaningView(viewModel: viewModel)
            case .completed, .partial:
                CleaningView(viewModel: viewModel)
            }
        }
    }
}
