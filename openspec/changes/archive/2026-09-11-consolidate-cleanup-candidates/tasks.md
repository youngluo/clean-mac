## 1. OpenSpec and domain model

- [x] 1.1 Add the cleanup target model and candidate-group metadata while preserving single-target candidates.
- [x] 1.2 Record the candidate-group and log-exclusion behavior in the main scan and cleanup models.
- [x] 1.3 Reconcile global installer/archive ownership with Library, diagnostic-log, protected-path, and exclusion boundaries.

## 2. Scan and execution

- [x] 2.1 Stop discovering user and system old logs in routine cleanup.
- [x] 2.2 Aggregate eligible temporary files by configured temporary root and keep them unselected by default.
- [x] 2.3 Revalidate and trash temporary targets one by one without deleting their root directories.
- [x] 2.4 Report complete, partial, failed, skipped, and cancelled outcomes for grouped candidates.
- [x] 2.5 Enforce conservative temporary timestamps and unknown aggregate sizes, and include partial moved bytes in summaries.
- [x] 2.6 Protect installed application components and ambiguous application data from leftover candidates.

## 3. UI and localization

- [x] 3.1 Show grouped temporary candidates with target count and aggregate size.
- [x] 3.2 Add localized temporary-file and partially-completed outcome labels.
- [x] 3.3 Keep space-analysis diagnostics internal without adding a diagnostic panel to the candidate review UI.
- [x] 3.4 Remove the manual rescan button and its unused review action/localization entry.

## 4. Tests and verification

- [x] 4.1 Update temporary-directory scanning tests for grouped targets.
- [x] 4.2 Add coverage for log exclusion and grouped cleanup safety.
- [x] 4.3 Run formatting checks, tests/build, and the required Debug app verification.
- [x] 4.4 Add coverage for Library installers, exclusion boundaries, partial bytes, and conservative temporary snapshots.
- [x] 4.5 Add regression coverage for installed app prefixes, nested components, launch items, and ambiguous leftover roots.
- [x] 4.6 Verify the candidate review action area has no rescan entry and the project still builds cleanly.

> Verification note: `git diff --check`, strict OpenSpec validation, JSON localization validation, static rescan-entry check, and Debug build passed. The latest app relaunch was blocked by the host disk reaching critically low free space; the build still reports the pre-existing malformed project-group warnings.
