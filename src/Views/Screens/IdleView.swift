import SwiftUI

struct IdleView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var isHoveringPrimary = false

    var body: some View {
        VStack(spacing: 18) {
            Button {
                viewModel.startQuickClean()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.theme.primaryAction)
                        .overlay {
                            Circle()
                                .stroke(Color.theme.primaryActionForeground.opacity(0.22), lineWidth: 0.5)
                        }
                        .shadow(color: Color.theme.primaryAction.opacity(0.24), radius: 12, y: 6)

                    Circle()
                        .stroke(Color.theme.primaryActionForeground.opacity(0.72), lineWidth: 1)
                        .scaleEffect(isHoveringPrimary ? 1.03 : 0.96)
                        .opacity(reduceMotion ? 0 : isHoveringPrimary ? 0.58 : 0)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.28),
                            value: isHoveringPrimary
                        )

                    Text(L10n.resolve(.idleCleanNow, locale: locale))
                        .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.theme.primaryActionForeground)
                }
                .frame(width: 116, height: 116)
                .contentShape(Circle())
                .offset(y: isHoveringPrimary ? -1 : 0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.78),
                    value: isHoveringPrimary
                )
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
