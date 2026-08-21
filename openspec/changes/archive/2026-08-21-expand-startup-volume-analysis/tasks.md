## 1. Analysis result model

- [x] 1.1 Add volume analysis models for startup-volume identity, total/available bytes, measured bytes, top-level usage items, and item status.
- [x] 1.2 Extend scan results and cleanup events with partial state, scan progress, unavailable-location diagnostics, and an optional volume summary.
- [x] 1.3 Update the view model to retain volume summaries, partial diagnostics, empty results, and a stable return-to-idle action without affecting routine or developer flows.

## 2. Startup-volume scanner

- [x] 2.1 Resolve `/` as the local non-removable startup-volume boundary and reject external, network, removable, or cross-volume traversal.
- [x] 2.2 Implement cancellable bounded traversal that skips symlinks and protected runtime paths while recording unreadable locations as diagnostics.
- [x] 2.3 Aggregate root and major-directory usage with measured/estimated status and publish progress events during traversal.
- [x] 2.4 Discover large user-owned files and directories across the startup volume using a fixed threshold and bounded, size-sorted candidate list.
- [x] 2.5 Mark protected, unavailable, timed-out, and partially scanned locations as informational diagnostics rather than cleanup candidates.
- [x] 2.6 Keep routine, developer, and Time Machine providers unchanged except for shared scan result/event plumbing.

## 3. Safe analysis cleanup boundary

- [x] 3.1 Expand analysis-path validation to the current user home while preserving protected prefixes, exclusion rules, absolute-path checks, and symlink rejection.
- [x] 3.2 Route confirmed startup-volume user-owned candidates to Trash only; prevent informational volume items from entering the apply snapshot.
- [x] 3.3 Revalidate candidate existence, size, protection state, and removal mode before applying and report stale candidates without broadening scope.

## 4. Review and navigation UI

- [x] 4.1 Add startup-volume capacity and top-level usage summary presentation to the analysis review screen.
- [x] 4.2 Show scan progress, partial/unavailable diagnostics, cancellation state, and candidate counts while preserving existing Chinese UI conventions.
- [x] 4.3 Update candidate rows to support large directories, measured/estimated sizes, modification age, risk, and Trash removal mode.
- [x] 4.4 Add explicit “返回主界面” and “重新扫描” actions for empty, partial, cancelled, and non-empty review results.
- [x] 4.5 Keep destructive actions disabled until an eligible candidate is selected and keep the popover transient after scan completion.
- [x] 4.6 Add Mole-inspired limited-access guidance with a macOS settings deep link and an explicit permission recheck while keeping scans usable without authorization.
- [x] 4.7 Show cleanup targets that fail a Trash permission preflight as protected and unselected, with an actionable reason.

## 5. Verification

- [x] 5.1 Add fixture tests for startup-volume metadata, top-level aggregation, large-file thresholds, and candidate limits.
- [x] 5.2 Add safety tests for external-volume boundaries, protected paths, symlinks, unreadable locations, exclusions, and stale-size validation.
- [x] 5.3 Add cancellation, timeout/partial diagnostics, empty-result, and ordered scan-event tests.
- [x] 5.4 Add executor tests proving analysis candidates use Trash and informational volume items cannot be permanently removed.
- [x] 5.5 Run OpenSpec strict validation, `git diff --check`, the full XCTest target, and the Xcode Debug build.
- [x] 5.6 Verify the limited-access state remains informational and does not broaden scan or cleanup scope.
- [x] 5.7 Add coverage for cleanup targets that are not deletable by the current user and normalize permission failures for the result view.
