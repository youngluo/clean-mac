import SwiftUI

struct CandidateRowView: View {
    let candidate: CleanupCandidate
    let toggle: () -> Void
    let exclude: () -> Void

    private var sizeText: String {
        guard let byteSize = candidate.byteSize else { return "大小未知" }
        return formatByteCount(byteSize)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Button(action: toggle) {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selectionColor)
                    .frame(width: 19)
            }
            .buttonStyle(.plain)
            .disabled(!candidate.isEligible)
            .pointerCursor()

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.pathDescription)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .help(candidate.pathDescription)

                HStack(spacing: 7) {
                    Text(sizeText)
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(Color.theme.textSecondary)

                if let reason = candidate.protectionReason {
                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.theme.warning)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .contextMenu {
            if candidate.url != nil && candidate.isEligible {
                Button("加入排除列表", action: exclude)
            }
        }
    }

    private var selectionColor: Color {
        if !candidate.isEligible { return Color.theme.disabled }
        return candidate.isSelected ? Color.theme.accent : Color.theme.textSecondary
    }

}
