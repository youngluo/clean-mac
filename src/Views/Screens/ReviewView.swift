import SwiftUI

struct ReviewView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @State private var showingTimeMachineConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("检查结果")
                        .font(.system(size: 15, weight: .semibold))
                    Text(viewModel.currentCategory?.title ?? "清理项")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("全选") { viewModel.toggleAllEligible() }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
            }

            if !viewModel.diagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.diagnostics) { diagnostic in
                        Label(diagnostic.message, systemImage: diagnostic.isWarning ? "exclamationmark.triangle" : "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(diagnostic.isWarning ? Theme.warning : .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            if viewModel.candidates.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.primary)
                    Text("没有可清理项")
                        .font(.system(size: 12, weight: .medium))
                    Text("本次扫描没有发现符合条件的项目")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                    .frame(height: 130)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.candidates) { candidate in
                            CandidateRowView(
                                candidate: candidate,
                                toggle: { viewModel.toggleCandidate(candidate.id) },
                                exclude: { viewModel.addExclusion(for: candidate.id) }
                            )
                            if candidate.id != viewModel.candidates.last?.id {
                                Divider().padding(.leading, 37)
                            }
                        }
                    }
                }
                .frame(maxHeight: 245)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Text("已选择 \(viewModel.selectedCount) 项")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: viewModel.selectedBytes, countStyle: .file))
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("重新扫描") {
                    if let category = viewModel.currentCategory { viewModel.startScan(category: category) }
                }
                .buttonStyle(.bordered)

                Button(viewModel.currentCategory == .timeMachine ? "确认高级维护" : "开始清理") {
                    if viewModel.currentCategory == .timeMachine {
                        showingTimeMachineConfirmation = true
                    } else {
                        viewModel.startCleanup()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .disabled(viewModel.selectedCount == 0)
            }
            .frame(maxWidth: .infinity)
        }
        .alert("确认 Time Machine 高级维护？", isPresented: $showingTimeMachineConfirmation) {
            Button("取消", role: .cancel) {}
            Button("继续") { viewModel.startCleanup() }
        } message: {
            Text("此操作需要管理员权限，并可能影响本地快照保留。请确认当前没有正在进行的备份任务。")
        }
    }
}
