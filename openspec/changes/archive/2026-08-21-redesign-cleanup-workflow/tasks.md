## 1. Candidate and run model

- [x] 1.1 Define cleanup categories, candidate metadata, risk levels, removal modes, protection reasons, and terminal result states.
- [x] 1.2 Define ordered cleanup events and aggregated run results, including scanned, selected, moved, removed, skipped, failed, and cancelled counts.
- [x] 1.3 Replace the direct cleanup state flags with the idle → scanning → review → applying → terminal-state flow and retain cancellable scan/apply tasks.

## 2. Scanning and safety boundaries

- [x] 2.1 Implement path validation for absolute paths, allowed roots, traversal, protected prefixes, and unsafe symlinks; fail closed on ambiguous state.
- [x] 2.2 Add per-user exclusions and local operation-history persistence without writing user-controlled files as root.
- [x] 2.3 Implement bounded routine scanners for explicitly allowlisted rebuildable caches and age-bounded logs.
- [x] 2.4 Implement user-owned disk analysis for configured home and Downloads locations with large-file candidates and measured sizes.
- [x] 2.5 Implement developer-artifact scanning for configured project roots, recognized artifact names, recent-project protection, and in-use skips.
- [x] 2.6 Implement an advanced Time Machine scanner that reports unavailable or ambiguous backup state without proposing snapshot thinning.

## 3. Review and selection UI

- [x] 3.1 Add scan entry points and separate scanning, review, applying, partial-result, cancelled, and completed views.
- [x] 3.2 Add category and item-level candidate rows showing path, size, age, risk, protection state, and removal mode.
- [x] 3.3 Add category selection, item selection, selected count, estimated size, and confirmation controls; keep recent, protected, and ambiguous candidates unselected.
- [x] 3.4 Add scan/apply cancellation, timeout, unavailable-category, and partial-result presentation.
- [x] 3.5 Add the explicit confirmation flow for advanced Time Machine maintenance after state checks.

## 4. Safe execution and result reporting

- [x] 4.1 Revalidate candidate identity, path, size, protection state, and removal mode immediately before applying each candidate.
- [x] 4.2 Route user-owned analysis and large-file candidates to the macOS Trash and record moved results separately from permanent removal.
- [x] 4.3 Implement bounded permanent removal for confirmed rebuildable caches and project artifacts, with no recursive whole-cache deletion.
- [x] 4.4 Refactor privileged execution to process only the confirmed privileged snapshot, preserve per-operation stderr and exit results, and share one authorization request.
- [x] 4.5 Stream ordered scan and apply events without marking a run terminal before pending events are delivered.
- [x] 4.6 Aggregate category-level bytes and result counts, show before/after volume availability as informational data, and persist the operation history entry.

## 5. Application integration

- [x] 5.1 Replace the current direct `startCleanup()` path and fixed task loop with the candidate scan/review/apply flow.
- [x] 5.2 Remove broad cache deletion, silent command success logging, swallowed operation errors, and the split between privileged execution and task reporting.
- [x] 5.3 Preserve menu bar icon rotation, popover behavior, authorization refocus, right-click Exit, and the existing Chinese UI conventions.
- [x] 5.4 Keep app uninstall, external-volume analysis, installer discovery, system optimization, and live monitoring outside this change.

## 6. Verification

- [x] 6.1 Add model tests for candidate selection, protection states, terminal result aggregation, and immutable confirmed snapshots.
- [x] 6.2 Add scanner tests using temporary fixtures for allowlisted roots, recent artifacts, missing paths, permission failures, and large-file thresholds.
- [x] 6.3 Add safety tests for traversal, protected prefixes, symlink targets, exclusion rules, Trash routing, and fail-closed behavior.
- [x] 6.4 Add executor tests for success, partial failure, cancellation, timeout, privileged authorization failure, and ordered event delivery.
- [x] 6.5 Run `openspec validate --changes --strict`, `git diff --check`, and the Xcode Debug build before enabling destructive providers.
