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
- [x] 4.24 Rename the candidate section to “可清理项目”, show the selected aggregate size, and place each row’s name and size above its path.
- [x] 4.25 Label the completed provider category list “已扫描完成”.
- [x] 4.26 Align candidate group content margins with the candidate section header.
- [x] 4.27 Set the candidate scroll area to a 320 minimum and 640 maximum height.
- [x] 4.28 Show “大小未知” for space-analysis candidates without measurable size.
- [x] 4.29 Reduce the visual size of candidate selection controls.
- [x] 4.30 Use the confirmed concise provider names and clickable scope explanations.
- [x] 4.31 Synchronize candidate group names with the provider names.
- [x] 4.32 Apply the 30-day project rule without requiring package metadata for `node_modules`.
- [x] 4.33 Show the provider scope explanation directly below each provider name.
- [x] 4.34 Remove the provider explanation icon, tooltip, and click-triggered popover.
- [x] 4.35 Replace scan-flow “检查” UI copy with “扫描” wording while retaining safety-check terminology.
- [x] 4.36 Show provider explanations only while scanning and reserve their row height to prevent layout jitter.
- [x] 4.37 Keep cleanup completion on the main surface, update candidate rows with outcomes, and use the five confirmed circular-button labels.
- [x] 4.38 Remove icons from the circular action and keep only the centered phase wording.
- [x] 4.39 Make provider rows with matching candidate groups clickable and anchor-scroll the candidate list to that group.
- [x] 4.40 Relax idle-state vertical spacing and reduce the visual weight of the helper copy.
- [x] 4.41 Compact completed provider and candidate-group spacing while preserving fixed provider-row height, and use stable provider identities for anchor navigation.
- [x] 4.42 Animate the transition from expanded scanning rows to the compact completed layout, respecting reduced-motion settings.
- [x] 4.43 Remove the redundant stage helper row between the circular action and provider progress panel.

## 5. Verification

- [x] 5.1 Verify a scan never changes the original path or the Trash.
- [x] 5.2 Verify selecting and deselecting candidates only changes selection state.
- [x] 5.3 Verify cancelling confirmation performs no filesystem operation.
- [x] 5.4 Verify confirmation moves user-owned candidates to the Trash and reports outcomes.
- [x] 5.5 Verify privileged candidates use the bounded Trash route and preserve authorization failures.
- [x] 5.6 Run XCTest, Debug build, OpenSpec validation, and launch the new App after closing the old instance.
- [x] 5.7 Verify Apple Music application data is excluded before metadata access.
- [x] 5.8 Verify the optimized traversal still filters protected media paths before metadata access.
- [x] 5.9 Verify the candidate header shows the selected count and aggregate size, and rows use the name-and-size-over-path layout.
- [x] 5.10 Verify the completed-list title, group margins, and candidate scroll height constraints.
- [x] 5.11 Verify the space-analysis size fallback and compact candidate selection control.
- [x] 5.12 Verify provider and candidate group names, explanations, and the 30-day project rule.
- [x] 5.13 Verify each provider row shows its scope explanation below the provider name.
- [x] 5.14 Verify provider explanations no longer depend on hover or click interactions.
- [x] 5.15 Verify scan-flow status, progress, and completion copy uses “扫描”.
- [x] 5.16 Verify provider explanation visibility changes do not change provider row height.
- [x] 5.17 Verify cleanup completion does not render the standalone result summary and updates outcomes in the candidate list.
- [x] 5.18 Verify the circular action renders no icon in any phase.
- [x] 5.19 Verify provider-row navigation targets the matching candidate group and is disabled without a target.
- [x] 5.20 Verify the idle header, disk information, circular action, and helper copy have distinct vertical spacing.
- [x] 5.21 Verify provider rows preserve fixed height while candidate groups use compact spacing.
- [x] 5.22 Verify each provider-row anchor lands on the matching provider-identified candidate group.
- [x] 5.23 Verify the provider layout compacts with animation after scanning without an abrupt height jump.
- [x] 5.24 Verify provider progress remains visible without an extra helper row below the circular action.
