import SwiftUI

struct CandidateRowView: View {
    let candidate: CleanupCandidate
    let toggle: () -> Void
    let exclude: () -> Void
    @Environment(\.locale) private var locale

    private var sizeText: String {
        guard let byteSize = candidate.byteSize else { return L10n.resolve(.viewUnknownSize, locale: locale) }
        return formatByteCount(byteSize, locale: locale)
    }

    private var outcomeText: String? {
        guard let outcome = candidate.outcome else { return nil }
        guard outcome == .failed,
              let message = candidate.outcomeMessage,
              !message.resolve(in: locale).isEmpty else {
            return outcome.title(in: locale)
        }
        return message.resolve(in: locale)
    }

    private var displayNameText: String {
        candidate.displayNameMessage?.resolve(in: locale) ?? candidate.displayName
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if let outcome = candidate.outcome {
                Image(systemName: outcomeIcon(for: outcome))
                    .font(.system(size: 14))
                    .foregroundStyle(outcomeColor(for: outcome))
                    .frame(width: 17)
            } else {
                Button(action: toggle) {
                    Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(selectionColor)
                        .frame(width: 17)
                }
                .buttonStyle(.plain)
                .disabled(!candidate.isEligible)
                .pointerCursor()
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(displayNameText)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(displayNameText)

                    Text(sizeText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.theme.textSecondary)
                }

                Text(candidate.pathDescription(in: locale))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(candidate.pathDescription(in: locale))

                if let outcome = candidate.outcome,
                   let outcomeText {
                    Text(outcomeText)
                        .font(.system(size: 9))
                        .foregroundStyle(outcomeColor(for: outcome))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(outcomeText)
                }

                if let reason = candidate.protectionReason {
                    Text(reason.resolve(in: locale))
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
                Button(L10n.resolve(.viewAddToExclusions, locale: locale), action: exclude)
            }
        }
    }

    private var selectionColor: Color {
        if !candidate.isEligible { return Color.theme.disabled }
        return candidate.isSelected ? Color.theme.accent : Color.theme.textSecondary
    }

    private func outcomeIcon(for outcome: CandidateOutcome) -> String {
        switch outcome {
        case .movedToTrash, .removed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .skipped: return "minus.circle"
        case .cancelled: return "pause.circle"
        }
    }

    private func outcomeColor(for outcome: CandidateOutcome) -> Color {
        switch outcome {
        case .movedToTrash, .removed: return Color.theme.success
        case .failed: return Color.theme.failure
        case .skipped: return Color.theme.textSecondary
        case .cancelled: return Color.theme.warning
        }
    }

}
