import SwiftUI

struct IdleView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("CleanMac")
                    .font(.system(size: 15, weight: .semibold))
                Text("先检查，再决定要清理什么")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(CleanupCategory.allCases) { category in
                    Button {
                        viewModel.startScan(category: category)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 15))
                                .foregroundStyle(category == .timeMachine ? Theme.warning : Theme.primary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(category.detail)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if category != CleanupCategory.allCases.last {
                        Divider().padding(.leading, 42)
                    }
                }
            }
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Image(systemName: "externaldrive")
                Text("可用空间 \(viewModel.availableDiskSpace)")
                Spacer()
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }
}
