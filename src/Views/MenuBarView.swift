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
    }
}
