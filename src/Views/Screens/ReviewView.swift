import SwiftUI

struct ReviewView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @State private var showingTimeMachineConfirmation = false

    private var hasTimeMachineSelection: Bool {
        viewModel.selectedCandidates.contains { $0.removalMode == .timeMachine }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                BackToIdleButton(viewModel: viewModel)
                VStack(alignment: .leading, spacing: 3) {
                    Text("检查结果")
                        .font(.system(size: 15, weight: .semibold))
                    Text(viewModel.currentCategory?.title ?? "清理项")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button("全选") { viewModel.toggleAllEligible() }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .disabled(viewModel.candidates.isEmpty)
            }

            if let volumeSummary = viewModel.volumeSummary {
                VolumeSummaryView(summary: volumeSummary, isPartial: viewModel.scanIsPartial)
            } else if viewModel.scanIsPartial {
                Label("扫描部分完成，部分位置无法读取", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.currentCategory == .analysis && viewModel.diskAccessStatus == .limited {
                DiskAccessResultHintView(viewModel: viewModel)
            }

            if !viewModel.diagnostics.isEmpty {
                DiagnosticsPanel(diagnostics: viewModel.diagnostics)
            }

            if viewModel.candidates.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.textPrimary)
                    Text("没有可清理项")
                        .font(.system(size: 12, weight: .medium))
                    Text(viewModel.scanIsPartial ? "本次扫描未发现可清理项，但仍有位置未完成检查" : "本次扫描没有发现符合条件的项目")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
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
                .glassPanel()
            }

            HStack {
                Text("已选择 \(viewModel.selectedCount) 项")
                Spacer()
                Text(formatByteCount(viewModel.selectedBytes))
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                Button("重新扫描") {
                    if let category = viewModel.currentCategory { viewModel.startScan(category: category) }
                }
                .buttonStyle(.bordered)

                Button(hasTimeMachineSelection ? "确认高级维护" : "开始清理") {
                    if hasTimeMachineSelection {
                        showingTimeMachineConfirmation = true
                    } else {
                        viewModel.startCleanup()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.button)
                    .disabled(viewModel.selectedCount == 0)
            }
            .frame(maxWidth: .infinity)
        }
        .alert("确认包含 Time Machine 快照维护？", isPresented: $showingTimeMachineConfirmation) {
            Button("取消", role: .cancel) {}
            Button("继续") { viewModel.startCleanup() }
        } message: {
            Text("此操作需要管理员权限，并可能影响本地快照保留。请确认当前没有正在进行的备份任务。")
        }
    }
}

private struct DiskAccessResultHintView: View {
    @ObservedObject var viewModel: CleanerViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "lock.open")
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 3) {
                Text("本次仅完成可访问位置的分析")
                    .font(.system(size: 10, weight: .medium))
                Text("开启完全磁盘访问权限后重新扫描，可减少无法读取的目录。")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Button("前往系统设置") {
                        viewModel.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.borderless)
                    Button("重新检查") {
                        viewModel.refreshDiskAccessStatus()
                    }
                    .buttonStyle(.borderless)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 7)
    }
}

private struct DiagnosticsPanel: View {
    let diagnostics: [ScanDiagnostic]
    @State private var showingAllDiagnostics = false

    private var visibleDiagnostics: ArraySlice<ScanDiagnostic> {
        showingAllDiagnostics ? diagnostics[...] : diagnostics.prefix(3)
    }

    private var unreadableCount: Int {
        diagnostics.filter { $0.message.hasPrefix("无法读取") }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label("扫描提示", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.warning)
                Text("\(diagnostics.count) 条")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if diagnostics.count > 3 {
                    Button(showingAllDiagnostics ? "收起" : "展开全部") {
                        showingAllDiagnostics.toggle()
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.borderless)
                }
            }

            if unreadableCount > 0 {
                Text("其中 \(unreadableCount) 个位置无法读取，已跳过，不影响其他位置继续扫描")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            ScrollView(.vertical, showsIndicators: showingAllDiagnostics) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(visibleDiagnostics) { diagnostic in
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: diagnostic.isWarning ? "exclamationmark.triangle" : "info.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(diagnostic.isWarning ? Theme.warning : Theme.textSecondary)
                                .frame(width: 12)
                            Text(diagnostic.message)
                                .font(.system(size: 9))
                                .foregroundStyle(diagnostic.isWarning ? Theme.warning : Theme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .frame(maxHeight: showingAllDiagnostics ? 150 : 62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .glassPanel(cornerRadius: 7)
    }
}

private struct VolumeSummaryView: View {
    let summary: VolumeAnalysisSummary
    let isPartial: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(summary.volumeName, systemImage: "internaldrive")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(isPartial ? "部分完成" : "已完成")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isPartial ? Theme.warning : Theme.textPrimary)
            }

            HStack(spacing: 12) {
                volumeValue("总容量", summary.totalBytes)
                volumeValue("可用", summary.availableBytes)
                volumeValue("已测量", summary.measuredBytes)
            }

            if !summary.usageItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("主要占用")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(summary.usageItems.prefix(5)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.isProtected ? "lock" : "folder")
                                .font(.system(size: 9))
                                .foregroundStyle(item.isProtected ? Theme.textSecondary : Theme.textPrimary)
                            Text(item.displayName)
                                .font(.system(size: 9))
                                .lineLimit(1)
                            Spacer()
                            Text(item.byteSize.map(formatByteCount) ?? item.status.title)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func volumeValue(_ title: String, _ bytes: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textSecondary)
            Text(bytes.map(formatByteCount) ?? "未知")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
    }
}
