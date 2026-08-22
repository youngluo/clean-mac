import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        CleanupHomeView(viewModel: viewModel)
            .padding(16)
            .frame(width: 360)
            .background(.ultraThinMaterial)
    }
}

struct CleanupHomeView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 5) {
                Text("CleanMac")
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 5) {
                    Image(systemName: "externaldrive")
                    Text("启动磁盘 · 可用空间 \(viewModel.availableDiskSpace)")
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
                CompletedView(viewModel: viewModel)
            }
        }
    }
}
