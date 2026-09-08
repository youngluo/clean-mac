import SwiftUI

struct CandidateReviewSection: View {
    @ObservedObject var viewModel: CleanerViewModel
    @Binding var scrollTarget: CleanupProvider?
    @EnvironmentObject private var panelLayoutState: PanelLayoutState
    @Environment(\.locale) private var locale
    private let candidateGroupTopPadding = LayoutSpacing.anchorTop

    init(
        viewModel: CleanerViewModel,
        scrollTarget: Binding<CleanupProvider?> = .constant(nil)
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._scrollTarget = scrollTarget
    }

    private var maximumHeight: CGFloat {
        max(0, panelLayoutState.candidateReviewMaximumHeight)
    }

    private var listMinimumHeight: CGFloat {
        maximumHeight >= 320 ? 320 : 0
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
                .padding(.horizontal, LayoutSpacing.panelHorizontal)
                .padding(.vertical, LayoutSpacing.headerVertical)

                Divider()
                    .opacity(0.45)

                    ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(reviewGroups) { group in
                                VStack(alignment: .leading, spacing: LayoutSpacing.micro) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(group.title(in: locale))
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Color.theme.textSecondary)
                                        Spacer()
                                        Text(L10n.itemCount(group.candidates.count, locale: locale))
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(Color.theme.textSecondary)
                                    }
                                    .padding(.horizontal, LayoutSpacing.small)

                                    ForEach(group.candidates) { candidate in
                                        CandidateRowView(
                                            candidate: candidate,
                                            toggle: { viewModel.toggleCandidate(candidate.id) },
                                            exclude: { viewModel.addExclusion(for: candidate.id) }
                                        )
                                    }
                                }
                                .padding(.top, candidateGroupTopPadding)
                                .padding(.bottom, LayoutSpacing.tight)
                                .id(group.provider)
                            }
                        }
                        .padding(.horizontal, LayoutSpacing.listGutter)
                        .padding(.bottom, LayoutSpacing.row)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: listMinimumHeight)
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
            .frame(maxWidth: .infinity, maxHeight: maximumHeight, alignment: .top)
            .subtleGlassPanel(cornerRadius: 12)
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
            selectedSize: formatByteCount(viewModel.selectedBytes, locale: locale),
            totalSize: formatByteCount(viewModel.reviewCandidateBytes, locale: locale),
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
        HStack(spacing: LayoutSpacing.small) {
            Button(L10n.resolve(.viewMoveToTrash, locale: locale)) {
                viewModel.executeSelectedCandidates()
            }
            .buttonStyle(ThemeActionButtonStyle())
            .disabled(viewModel.selectedCount == 0 || viewModel.isCleaning)
            .pointerCursor()

            if viewModel.shouldOfferRescan {
                Button(L10n.resolve(.viewRescan, locale: locale)) {
                    viewModel.rescan()
                }
                .buttonStyle(ThemeSecondaryButtonStyle())
                .pointerCursor()
            }

            Button(
                viewModel.appState == .awaitingConfirmation
                    ? L10n.resolve(.viewCancel, locale: locale)
                    : L10n.resolve(.viewDone, locale: locale),
                action: onDone
            )
                .buttonStyle(ThemeSecondaryButtonStyle())
                .disabled(viewModel.isCleaning)
                .pointerCursor()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
