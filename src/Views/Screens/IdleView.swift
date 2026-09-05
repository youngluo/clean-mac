import SwiftUI

struct IdleView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.locale) private var locale
    @State private var isHoveringPrimary = false

    var body: some View {
        VStack(spacing: 22) {
            Button {
                viewModel.startQuickClean()
            } label: {
                PrimaryActionCircle(
                    title: L10n.resolve(.idleCleanNow, locale: locale),
                    isWorking: false,
                    isHovering: isHoveringPrimary
                )
                .contentShape(Circle())
            }
            .buttonStyle(CircleActionButtonStyle())
            .onHover { isHoveringPrimary = $0 }
            .pointerCursor()
            .help(L10n.resolve(.idleSafeScanHelp, locale: locale))

            Text(L10n.resolve(.idleSafeScanDescription, locale: locale))
                .font(.system(size: 9))
                .foregroundStyle(Color.theme.textTertiary)
                .padding(.top, 1)

            if viewModel.diskAccessStatus == .limited {
                DiskAccessHintView(viewModel: viewModel)
            }
        }
    }
}

private struct DiskAccessHintView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "lock.open")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.theme.warning)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.resolve(.idleFullDiskAccessRequired, locale: locale))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Text(L10n.resolve(.idleMoreCompleteScanResults, locale: locale))
                    .font(.system(size: 9))
                    .foregroundStyle(Color.theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            HStack(alignment: .center, spacing: 8) {
                Button {
                    viewModel.openFullDiskAccessSettings()
                } label: {
                    Text(L10n.resolve(.idleOpenSettings, locale: locale))
                        .frame(height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.theme.warning)
                .contentShape(Rectangle())
                .pointerCursor()

                Button {
                    viewModel.refreshDiskAccessStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.theme.textSecondary)
                .contentShape(Rectangle())
                .pointerCursor()
                .help(L10n.resolve(.idleCheckDiskAccessAgain, locale: locale))
                .accessibilityLabel(L10n.resolve(.idleCheckDiskAccessAgain, locale: locale))
            }
            .font(.system(size: 9, weight: .medium))
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}
