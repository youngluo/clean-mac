import SwiftUI

struct CandidateReviewSection: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Binding var scrollTarget: CleanupProvider?
    @Environment(\.locale) private var locale
    private let candidateGroupTopPadding: CGFloat = 13

    init(viewModel: CleanerViewModel, scrollTarget: Binding<CleanupProvider?> = .constant(nil)) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._scrollTarget = scrollTarget
    }

    private var reviewGroups: [ReviewCandidateGroup] {
        let grouped = Dictionary(grouping: viewModel.reviewCandidates) { candidate in
            candidate.provider
        }
        return grouped
            .map { ReviewCandidateGroup(provider: $0.key, candidates: $0.value) }
            .sorted { providerRank($0.provider) < providerRank($1.provider) }
    }

    var body: some View {
        if !viewModel.reviewCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.resolve(.viewCleanupItems, locale: locale))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(headerSummary)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.theme.textSecondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)

                Divider()
                    .opacity(0.45)

                    ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(reviewGroups) { group in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(group.title(in: locale))
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Color.theme.textSecondary)
                                        Spacer()
                                        Text(L10n.itemCount(group.candidates.count, locale: locale))
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(Color.theme.textSecondary)
                                    }
                                    .padding(.horizontal, 8)

                                    ForEach(group.candidates) { candidate in
                                        CandidateRowView(
                                            candidate: candidate,
                                            toggle: { viewModel.toggleCandidate(candidate.id) },
                                            exclude: { viewModel.addExclusion(for: candidate.id) }
                                        )
                                    }
                                }
                                .padding(.top, candidateGroupTopPadding)
                                .padding(.bottom, 5)
                                .id(group.provider)
                            }
                        }
                        .padding(.horizontal, 3)
                        .padding(.bottom, 7)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 320, maxHeight: 720)
                    .onAppear {
                        guard let target = scrollTarget else { return }
                        scheduleScroll(to: target, using: proxy)
                    }
                    .onChange(of: scrollTarget) { target in
                        guard let target else { return }
                        scheduleScroll(to: target, using: proxy)
                    }
                }
            }
            .glassPanel(cornerRadius: 12)
        }
    }

    private func providerRank(_ provider: CleanupProvider) -> Int {
        let order: [CleanupProvider] = [.deepCleanup, .projectArtifacts, .applications, .spaceAnalysis]
        return order.firstIndex(of: provider) ?? order.count
    }

    private func scheduleScroll(to target: CleanupProvider, using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            guard scrollTarget == target else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(target, anchor: .top)
            }
            scrollTarget = nil
        }
    }

    private var headerSummary: String {
        L10n.selectedSummary(
            selectedCount: viewModel.selectedCount,
            totalCount: viewModel.reviewCandidates.count,
            size: formatByteCount(viewModel.selectedBytes, locale: locale),
            locale: locale
        )
    }
}

private struct ReviewCandidateGroup: Identifiable {
    let provider: CleanupProvider
    let candidates: [CleanupCandidate]

    var id: CleanupProvider { provider }
    func title(in locale: Locale) -> String { provider.title(in: locale) }
}

struct CleanupReviewActions: View {
    @ObservedObject var viewModel: CleanerViewModel
    let onDone: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 8) {
            Button(L10n.resolve(.viewMoveToTrash, locale: locale)) {
                viewModel.executeSelectedCandidates()
            }
            .buttonStyle(ThemeActionButtonStyle())
            .disabled(viewModel.selectedCount == 0 || viewModel.isCleaning)
            .pointerCursor()

            Button(
                viewModel.appState == .awaitingConfirmation
                    ? L10n.resolve(.viewCancel, locale: locale)
                    : L10n.resolve(.viewDone, locale: locale),
                action: onDone
            )
                .buttonStyle(ThemeSecondaryButtonStyle())
                .pointerCursor()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
