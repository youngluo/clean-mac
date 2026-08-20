## Context

The existing app combines discovery, deletion, authorization, logging, and UI state in `CleanerService` and `CleanerViewModel`. The current task model is a fixed list of four booleans, and privileged shell commands are assembled before the UI has shown the user the concrete targets. See `proposal.md` for the motivation and `specs/cleanmac-app/spec.md` for the revised behavior contract.

The design must keep CleanMac a lightweight native menu bar app while making cleanup reviewable and fail-closed. It should take inspiration from Mole's separation of cleanup, analysis, and project-artifact workflows without copying Mole's broader CLI scope or implementation.

## Goals / Non-Goals

**Goals:**

- Model cleanup as a scan → review → apply → result state machine.
- Separate candidate discovery from destructive execution.
- Make every candidate bounded, measurable, reviewable, and revalidated before action.
- Prefer reversible removal for user-owned files and provide category-level results.
- Preserve one authorization prompt for a confirmed run containing multiple privileged operations.
- Keep the menu bar shell and SwiftUI presentation lightweight and dependency-free.

**Non-Goals:**

- Implementing a full disk visualizer comparable to Mole's `analyze` command.
- Implementing app uninstall, application leftover discovery, system optimization, or live hardware monitoring in this change.
- Adding a privileged helper, background daemon, telemetry, or a third-party runtime dependency.
- Treating Time Machine snapshot thinning as part of routine quick cleanup.

## Decisions

### 1. Use a candidate-based domain model

Replace the current task-only execution model with domain objects that represent what can be acted on:

- `CleanupCategory`: routine cache/logs, disk analysis, developer artifacts, and advanced maintenance.
- `CleanupCandidate`: stable identifier, URL, category, display name, byte size, modification date, risk level, removal mode, and protection reason.
- `CandidateState`: discovered, selected, protected, movedToTrash, removed, skipped, failed, or cancelled.
- `CleanupRun`: scan metadata, confirmed candidate snapshot, event stream, and aggregated result counts.

The UI can still group candidates by category, but it must not infer a deletion target from a category name or reconstruct shell paths from display strings.

### 2. Separate scanners from executors

Each category provider first returns candidates and diagnostics. A separate executor revalidates the candidate immediately before applying it and performs the chosen removal mode. This prevents a failed or stale scan from silently widening the deletion scope.

The initial providers are:

- **Routine cleanup**: a small allowlist of rebuildable caches and age-bounded logs.
- **Disk analysis**: configured user-owned locations, starting with Downloads and selected home subdirectories.
- **Developer artifacts**: configured project roots and recognized artifact names such as `node_modules`, `target`, `.build`, `build`, `dist`, virtual environments, Xcode build data, and tool caches.
- **Advanced Time Machine**: a state-aware provider that remains unavailable when backup state is active or ambiguous.

No provider scans the entire home directory or recursively deletes an entire cache root by default.

### 3. Make the UI state explicit

The view model state becomes:

```text
idle
  → scanning
  → review
  → applying
  → completed | partial | cancelled
```

Scanning and applying use cancellable structured tasks retained by the view model. The review state owns the candidate selection; applying receives an immutable snapshot so later UI changes cannot alter the active run.

### 4. Use bounded removal modes

- User-owned analysis and large-file candidates use the macOS Trash API.
- Rebuildable cache and project-artifact candidates may use permanent removal only after explicit confirmation and path validation.
- Every removal path passes validation for absolute paths, allowed roots, protected prefixes, path traversal, and symlink behavior.
- Unreadable or ambiguous state fails closed and produces a visible skipped/failed result.

User exclusions are stored per user and applied during candidate presentation. The exclusion file or preference is written as the invoking user even when a later apply operation uses administrator authorization.

### 5. Authorize only the confirmed privileged set

The scan phase remains unprivileged. After confirmation, the executor partitions the immutable candidate snapshot into user-space and privileged operations. If privileged candidates exist, one administrator authorization request covers that run.

The privileged command protocol must preserve per-operation outcomes. It must not append `|| true`, discard stderr, or treat a successful authorization as proof that every command succeeded. User cancellation leaves privileged candidates untouched and returns a reviewable cancelled result.

### 6. Stream structured events

The service publishes ordered `CleanupEvent` values for scan progress, candidate discovery, apply start, output, terminal result, and diagnostics. The view model consumes the stream on the main actor and transitions to a terminal state only after all events have been processed.

Process stdout and stderr are handled independently and drained before waiting for termination. Filesystem operations report their own result instead of emitting success text from the caller.

### 7. Aggregate results from operations, not disk guesses

Each candidate records its measured size when known and its terminal result. The completed view derives category totals from those results and may additionally show before/after volume availability as an informational comparison. Files moved to Trash are reported separately because they may not immediately increase available volume space.

Operation history stores a local, user-readable record containing timestamp, categories, selected and terminal counts, byte totals, and error summaries. Reading history is strictly read-only.

### 8. Keep the first release smaller than Mole

CleanMac will borrow the review-first and safety-first model, not Mole's entire feature set. App uninstall, orphaned app records, installer discovery, external-volume analysis, and system optimization remain future capabilities with separate specifications.

## Risks / Trade-offs

- **[Scan cost]** Candidate sizing and project scans may be slow on large workspaces → use configured roots, bounded traversal, progress events, and timeouts that return partial results.
- **[Stale candidates]** A file can change or disappear between scan and apply → revalidate identity, path, size, and protection state immediately before action; report changes as skipped.
- **[Trash semantics]** Moving files to Trash does not guarantee immediate free space → distinguish moved bytes from reclaimed volume bytes in the result UI.
- **[Privileged batching]** One authorization prompt makes the flow simpler but groups privileged operations → show the full confirmed privileged set before authorization and retain per-operation outcomes.
- **[Scope creep]** Adding every Mole category would make the menu bar popover unwieldy → keep the first redesign to safe cleanup, analysis, developer artifacts, and an explicitly separated Time Machine action.
- **[Compatibility]** macOS permissions and TCC may make some locations unreadable → do not request broader access implicitly; surface unavailable categories and continue with confirmed safe candidates.

## Migration Plan

1. Introduce candidate, result, event, and category models alongside the existing task model.
2. Implement read-only scanners and a review screen without enabling destructive execution.
3. Implement path protection, exclusions, Trash routing, and structured executor results.
4. Replace the current direct `startCleanup()` flow with the state machine and migrate progress/log rendering.
5. Add focused tests and run the existing Debug build before enabling each cleanup provider.
6. Remove the old broad task execution path only after the new flow produces equivalent or safer results for the supported categories.

Rollback is to disable the new apply entry point and retain scan-only behavior; no persistent user data migration is required beyond optional exclusion and history files.
