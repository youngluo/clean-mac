import SwiftUI

struct IdleView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.locale) private var locale
    @State private var isHoveringPrimary = false

    var body: some View {
        VStack(spacing: LayoutSpacing.heroSection) {
            Button {
                viewModel.startQuickClean()
            } label: {
                PrimaryActionCircle(
                    title: L10n.resolve(.idleCleanNow, locale: locale),
                    isBreathing: false,
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
                .padding(.top, LayoutSpacing.optical)

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
        HStack(alignment: .center, spacing: LayoutSpacing.small) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: LayoutSpacing.micro) {
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

            Button {
                viewModel.openFullDiskAccessSettings()
            } label: {
                Text(L10n.resolve(.idleOpenSettings, locale: locale))
                    .frame(height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.theme.accent)
            .contentShape(Rectangle())
            .pointerCursor()
            .font(.system(size: 9, weight: .medium))
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, LayoutSpacing.hintHorizontal)
        .padding(.vertical, LayoutSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .subtleGlassPanel()
    }
}
