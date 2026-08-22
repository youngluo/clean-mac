## 1. Read-only unified scan

- [x] 1.1 Keep the unified provider order and startup-volume/media privacy boundaries.
- [x] 1.2 Remove the automatic apply call from the scan session; scanning must not mutate files.
- [x] 1.3 Keep all eligible candidates in the result collection after selection changes.
- [x] 1.4 Add an awaiting-confirmation phase after a successful or partial scan.
- [x] 1.5 Reduce repeated metadata reads and per-entry cancellation overhead without changing scan boundaries.

## 2. Confirmation plan

- [x] 2.1 Replace automatic/review execution split with one selectable candidate collection.
- [x] 2.2 Add an immutable `CleanupPlan` containing the confirmed candidate snapshot.
- [x] 2.3 Add a confirmation prompt showing item count, aggregate size, and Trash destination.
- [x] 2.4 Make cancelling the prompt side-effect free.

## 3. Trash execution

- [x] 3.1 Expose cleanup execution only through a confirmed plan.
- [x] 3.2 Revalidate every confirmed candidate immediately before moving it to the Trash.
- [x] 3.3 Preserve per-item moved, skipped, failed, cancelled, and privileged outcomes.
- [x] 3.4 Keep Time Machine maintenance explicit and separate from ordinary file deletion.

## 4. Single-surface UI

- [x] 4.1 Render scan results and candidate selection in the existing main surface.
- [x] 4.2 Keep selected candidates visible and show a clear “确认移到废纸篓” action.
- [x] 4.3 Show applying progress only after confirmation and keep cancellation available.
- [x] 4.4 Show confirmed results and remaining candidates without introducing another page.
- [x] 4.5 Put candidate paths above item details, keep them on one line with middle truncation, and show the full path on hover without making the path clickable.
- [x] 4.6 Place confirmation and cancellation actions side by side below the candidate list.
- [x] 4.7 Use concise one-line wording for the full-disk-access hint.
- [x] 4.8 Align the permission hint actions as a compact fixed-height group.
- [x] 4.9 Keep the full-disk-access action text-only.
- [x] 4.10 Add a shared hand cursor for enabled clickable controls.
- [x] 4.11 Add restrained hover, press, and progress feedback to the circular primary action.
- [x] 4.12 Refine the circular action icon and accent treatment toward a monochrome tool-button style.
- [x] 4.13 Remove the in-circle loading indicator and animate the whole circle during work.
- [x] 4.14 Rotate the running provider status icon continuously during the scanning phase only.
- [x] 4.15 Route every recursive scan helper through manual traversal so media exclusions are checked before directory access.
- [x] 4.16 Keep the completed-scan confirmation state inside the main surface, with the static result circle, provider log, and candidate list in order.
- [x] 4.17 Give the integrated candidate list an explicit visible scroll area so rows remain visible below the provider log.
- [x] 4.18 Recheck the shared media exclusion before every directory read, including queued startup-volume directories.
- [x] 4.19 Exclude all application bundles from space candidates while keeping Bundle ID lookup isolated to application-leftover attribution.
- [x] 4.20 Simplify candidate rows to path and size, reduce nested list decoration, and distinguish primary confirmation from secondary cancellation.
- [x] 4.21 Show measurable provider space usage above the candidate list and let the concrete list grow naturally up to a reasonable maximum height.
- [x] 4.22 Separate the candidate toolbar from the scroll content and use neutral surfaces with accent color reserved for interaction.
- [x] 4.23 Keep the candidate header and rows in a stable vertical flow, cap only overflow height, and center the two review actions as a compact group.

## 5. Verification

- [x] 5.1 Verify a scan never changes the original path or the Trash.
- [x] 5.2 Verify selecting and deselecting candidates only changes selection state.
- [x] 5.3 Verify cancelling confirmation performs no filesystem operation.
- [x] 5.4 Verify confirmation moves user-owned candidates to the Trash and reports outcomes.
- [x] 5.5 Verify privileged candidates use the bounded Trash route and preserve authorization failures.
- [x] 5.6 Run XCTest, Debug build, OpenSpec validation, and launch the new App after closing the old instance.
- [x] 5.7 Verify Apple Music application data is excluded before metadata access.
- [x] 5.8 Verify the optimized traversal still filters protected media paths before metadata access.
