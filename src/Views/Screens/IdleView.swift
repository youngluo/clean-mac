import SwiftUI

struct IdleView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                Text("CleanMac")
                    .font(.system(size: 16, weight: .semibold))
            }

            HStack(spacing: 5) {
                Image(systemName: "externaldrive")
                Text("启动磁盘 · 可用空间 \(viewModel.availableDiskSpace)")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.textSecondary)

            Button {
                viewModel.startQuickClean()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("一键清理")
                            .font(.system(size: 15, weight: .semibold))
                        Text("缓存 · 旧日志 · 开发工具缓存")
                            .font(.system(size: 10))
                            .opacity(0.72)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Theme.actionForeground(for: colorScheme))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.actionBackground(for: colorScheme))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.actionForeground(for: colorScheme).opacity(0.10), lineWidth: 0.5)
                }
            }
            .buttonStyle(.plain)
            .help("自动清理明确安全的缓存、旧日志和开发工具缓存")

            Button {
                viewModel.startScan(category: .analysis)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("空间分析")
                            .font(.system(size: 13, weight: .medium))
                        Text("启动磁盘 · 大文件 · Time Machine")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassPanel()

            if viewModel.diskAccessStatus == .limited {
                DiskAccessHintView(viewModel: viewModel)
            }
        }
    }
}

private struct DiskAccessHintView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "lock.open")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.warning)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("空间分析权限受限")
                    .font(.system(size: 10, weight: .medium))
                Text("未授权时仍可扫描，但部分位置会被 macOS 隐藏")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Button {
                    viewModel.openFullDiskAccessSettings()
                } label: {
                    Label("去设置", systemImage: "arrow.up.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.warning)

                Button {
                    viewModel.refreshDiskAccessStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .help("重新检查磁盘访问权限")
                .accessibilityLabel("重新检查磁盘访问权限")
            }
            .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}
