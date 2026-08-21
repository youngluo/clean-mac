import SwiftUI

struct CleaningView: View {
    @ObservedObject var viewModel: CleanerViewModel
    @State private var isSpinning = false

    private var title: String {
        switch viewModel.appState {
        case .scanning: return "正在检查"
        case .applying: return "正在清理"
        default: return "处理中"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                BackToIdleButton(viewModel: viewModel)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inProgress)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isSpinning)
                    .onAppear { isSpinning = true }
            }

            if viewModel.appState == .applying {
                ProgressView(value: viewModel.progress)
                    .tint(Theme.button)
                HStack {
                    Text("已处理 \(viewModel.completedWorkCount)/\(viewModel.totalWorkCount)")
                    Spacer()
                    Text("请保持窗口打开")
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            } else {
                if let progress = viewModel.scanProgress {
                    Text("\(progress.stage) · 已检查 \(progress.processedEntries) 项")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("正在读取启动磁盘，完成后可逐项查看")
                        .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(viewModel.events.suffix(20).enumerated()), id: \.offset) { _, event in
                        EventLineView(event: event, currentCandidateID: viewModel.currentCandidateID)
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 190)
            .glassPanel()

            Button("取消") { viewModel.cancelCurrentWork() }
                .buttonStyle(.bordered)
        }
    }
}

private struct EventLineView: View {
    let event: CleanupEvent
    let currentCandidateID: UUID?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 13)
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(2)
        }
    }

    private var text: String {
        switch event {
        case .phase(_, let message): return message
        case .scanProgress(let progress): return "\(progress.stage) · 已检查 \(progress.processedEntries) 项"
        case .candidateDiscovered(let candidate): return "发现 \(candidate.displayName)"
        case .diagnostic(let diagnostic): return diagnostic.message
        case .scanFinished(let result): return result.isPartial ? "扫描部分完成" : "扫描完成"
        case .candidateStarted(let id): return id == currentCandidateID ? "正在处理清理项" : "开始处理清理项"
        case .candidateCompleted(let result): return "\(result.displayName): \(result.message)"
        case .finished: return "清理结果已生成"
        }
    }

    private var iconName: String {
        switch event {
        case .diagnostic: return "info.circle"
        case .scanFinished: return "checkmark.circle"
        case .candidateCompleted(let result): return result.outcome == .failed ? "xmark.circle" : "checkmark.circle"
        case .finished: return "checkmark.circle.fill"
        default: return "circle"
        }
    }

    private var color: Color {
        switch event {
        case .diagnostic(let diagnostic) where diagnostic.isWarning: return Theme.warning
        case .scanFinished(let result) where result.isPartial: return Theme.warning
        case .candidateCompleted(let result) where result.outcome == .failed: return Theme.failure
        case .candidateCompleted(let result) where result.outcome == .movedToTrash || result.outcome == .removed: return Theme.success
        default: return Theme.textSecondary
        }
    }
}
