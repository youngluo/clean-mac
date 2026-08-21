import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        Group {
            switch viewModel.appState {
            case .idle:
                IdleView(viewModel: viewModel)
            case .scanning, .applying:
                CleaningView(viewModel: viewModel)
            case .review:
                ReviewView(viewModel: viewModel)
            case .completed, .partial, .cancelled:
                CompletedView(viewModel: viewModel)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(.ultraThinMaterial)
    }
}

struct BackToIdleButton: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        Button {
            viewModel.resetToIdle()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textSecondary)
        .contentShape(Rectangle())
        .help("返回主界面")
        .accessibilityLabel("返回主界面")
    }
}
