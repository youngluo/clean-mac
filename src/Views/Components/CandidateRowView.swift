import SwiftUI

struct CandidateRowView: View {
    let candidate: CleanupCandidate
    let toggle: () -> Void
    let exclude: () -> Void

    private var sizeText: String {
        guard let byteSize = candidate.byteSize else { return "大小未知" }
        return ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    private var ageText: String {
        guard let modifiedAt = candidate.modifiedAt else { return "时间未知" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selectionColor)
                    .frame(width: 19)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(candidate.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(candidate.isEligible ? .primary : .secondary)
                            .lineLimit(1)
                        Text(candidate.risk.title)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(riskColor)
                    }
                    Text(candidate.source)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(candidate.pathDescription)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(sizeText)
                        Text(ageText)
                        Text(candidate.removalMode.title)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    if let reason = candidate.protectionReason {
                        Text(reason)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.warning)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!candidate.isEligible)
        .contextMenu {
            if candidate.url != nil && candidate.isEligible {
                Button("加入排除列表", action: exclude)
            }
        }
    }

    private var riskColor: Color {
        switch candidate.risk {
        case .safe: return Theme.primary
        case .review: return Theme.warning
        case .advanced: return .orange
        case .protected: return .secondary
        }
    }

    private var selectionColor: Color {
        if !candidate.isEligible { return .secondary.opacity(0.35) }
        return candidate.isSelected ? Theme.primary : .secondary
    }
}
