## Why

The current CleanMac design treats cleanup as four immediately executable checkboxes, including broad cache deletion and privileged maintenance. That model gives users too little visibility into what will be removed and makes a successful-looking run unreliable when individual operations fail. Before implementing more cleanup targets, CleanMac needs a review-first workflow with bounded targets, explicit protection, and category-level results.

Mole's `clean`, `analyze`, and `purge` capabilities provide a useful product reference: discovery, review, safe execution, and results are separate concerns. CleanMac should adopt those principles while keeping a smaller native menu bar scope.

## What Changes

- **BREAKING** Replace the four-task one-click cleanup model with a scan → review → clean → results workflow.
- **BREAKING** Stop treating the entire user cache directory and Time Machine snapshot thinning as routine default cleanup.
- Add cleanup candidates with category, path, size, age, risk, source, and protection state.
- Add preview/dry-run behavior before destructive operations.
- Add protected paths, symlink/path validation, persistent exclusions, and fail-closed behavior when a candidate cannot be verified safely.
- Prefer moving user-owned files to the Trash; reserve permanent deletion for bounded, known-rebuildable cleanup targets.
- Split regular cleanup, disk analysis, and developer project-artifact cleanup into distinct user flows.
- Add per-category totals, per-item outcomes, skipped/failed counts, and an operation summary.
- Move Time Machine cleanup to an explicit advanced maintenance action with state checks and confirmation.
- Keep the menu bar shell, native SwiftUI presentation, and single authorization prompt where a confirmed run contains multiple privileged candidates.

## Capabilities

### New Capabilities

<!-- No separate capability is introduced; the redesign changes the existing CleanMac app contract. -->

### Modified Capabilities

- `cleanmac-app`: Replace immediate task execution with review-first cleanup, safe candidate handling, separated analysis/developer flows, advanced maintenance confirmation, and detailed results.

## Impact

- `openspec/specs/cleanmac-app/spec.md`: its cleanup, selection, privilege, progress, error, and completion requirements will need a delta update.
- `src/Models/CleanTask.swift`: likely replaced or extended with candidate/category/risk/result models.
- `src/Services/CleanerService.swift`: scanning, sizing, path validation, protected targets, Trash routing, and structured operation results.
- `src/ViewModels/CleanerViewModel.swift`: scan/review/apply state machine, selection persistence, cancellation, and ordered events.
- `src/Views/`: new scan/review/result states and item-level selection controls.
- Tests: service and model tests for path safety, candidate sizing, protected targets, dry-run behavior, and result aggregation.
- No new runtime dependency is required by this proposal.
