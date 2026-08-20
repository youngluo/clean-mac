## ADDED Requirements

### Requirement: Review-first cleanup workflow

The application SHALL separate discovery, review, and destructive execution. Scanning SHALL be read-only, and no cleanup operation SHALL begin until the user confirms the reviewed selection.

#### Scenario: Scan without mutation

- **WHEN** the user starts a cleanup scan
- **THEN** the application discovers eligible candidates without deleting or moving files
- **AND** it reports each candidate's category, path, size, age, and risk state when available

#### Scenario: Confirm reviewed candidates

- **WHEN** the user reviews the scan results and confirms a non-empty selection
- **THEN** the application starts cleanup only for the confirmed candidates
- **AND** it records the selection as the immutable input for that cleanup run

#### Scenario: Empty or unreviewed selection

- **WHEN** no eligible candidate is selected or the scan has not completed
- **THEN** the destructive cleanup action is disabled

### Requirement: Protected cleanup candidates

The application SHALL use bounded, known-safe cleanup roots and SHALL fail closed when a candidate cannot be validated. It SHALL not treat broad cache-directory deletion as a safe default.

#### Scenario: Protected path

- **WHEN** a discovered path is a system root, credential store, keychain, browser history or cookie store, iCloud-synced data, active Time Machine data, or another protected category
- **THEN** the path is excluded from the cleanup candidates
- **AND** the application explains that it was protected or skipped when useful

#### Scenario: Invalid or ambiguous path

- **WHEN** a candidate is empty, relative, traversal-based, outside an allowlisted root, points through an unsafe symlink, or cannot be verified because discovery failed
- **THEN** the application does not delete or move it
- **AND** the candidate is reported as skipped or failed with a reason

### Requirement: User protection rules

The application SHALL allow users to persist exclusions for cleanup candidates and SHALL apply those exclusions before presenting the confirmation set.

#### Scenario: Excluded candidate

- **WHEN** a discovered candidate matches a saved user exclusion
- **THEN** the candidate is not selected for cleanup
- **AND** the user can inspect that it was protected by an exclusion rule

### Requirement: Safe removal destination

The application SHALL prefer reversible removal for user-owned files and SHALL reserve permanent deletion for bounded, known-rebuildable cleanup targets.

#### Scenario: User-owned candidate

- **WHEN** the user confirms an eligible user-owned file from analysis or large-file review
- **THEN** the application moves it to the macOS Trash
- **AND** the result identifies it as moved rather than permanently deleted

#### Scenario: Rebuildable cache candidate

- **WHEN** the user confirms a bounded cache or project artifact explicitly marked as rebuildable
- **THEN** the application may permanently remove it
- **AND** the result identifies the target category and removal outcome

### Requirement: Separated analysis and developer artifact workflows

The application SHALL distinguish general disk analysis from developer project-artifact cleanup. Each workflow SHALL use explicit scan boundaries instead of scanning the entire home directory by default.

#### Scenario: Disk analysis

- **WHEN** the user opens disk analysis
- **THEN** the application lets the user inspect configured home or Downloads locations and their large files
- **AND** it does not automatically include external volumes or unrelated system directories

#### Scenario: Developer artifact cleanup

- **WHEN** the user opens developer cleanup
- **THEN** the application can identify recognized artifacts such as `node_modules`, `target`, `.build`, `build`, `dist`, virtual environments, Xcode build data, and tool caches within configured project roots
- **AND** recently modified projects are not selected by default

### Requirement: Advanced Time Machine maintenance

Time Machine snapshot thinning SHALL be an explicit advanced maintenance action rather than part of routine cache cleanup.

#### Scenario: Safe snapshot maintenance

- **WHEN** the user opens the advanced Time Machine action
- **THEN** the application checks whether backup activity and snapshot state are known and safe to inspect
- **AND** it requires explicit confirmation before requesting administrator authorization

#### Scenario: Active or unknown backup state

- **WHEN** backup activity or snapshot state is active, unavailable, or ambiguous
- **THEN** the application skips snapshot thinning
- **AND** it does not report the action as completed

### Requirement: Operation summary and history

The application SHALL provide category-level results and retain a local history of cleanup operations.

#### Scenario: Category summary

- **WHEN** a cleanup run finishes
- **THEN** the application shows the number of candidates scanned, selected, removed, moved to Trash, skipped, and failed
- **AND** it shows reclaimed or affected bytes per category when measurable

#### Scenario: Operation history

- **WHEN** an operation completes or is cancelled
- **THEN** the application records its time, categories, result counts, and errors locally
- **AND** viewing history does not perform any cleanup operation

## MODIFIED Requirements

### Requirement: Cleanup task selection

The idle view SHALL expose cleanup categories and analysis entry points rather than presenting every operation as an immediately executable destructive task. The application SHALL only preselect candidates that are known to be safe under the current policy; recent, high-risk, protected, or ambiguous candidates SHALL remain unselected.

#### Scenario: Start a scan

- **WHEN** the user chooses a cleanup category or analysis workflow
- **THEN** the application starts a read-only scan for that workflow
- **AND** it does not request administrator authorization before the user reviews candidates

#### Scenario: Review selection

- **WHEN** the scan displays candidates
- **THEN** the user can select or deselect individual candidates or a category
- **AND** the interface shows the selected count and estimated size

#### Scenario: Apply availability

- **WHEN** there are no confirmed eligible candidates
- **THEN** the destructive cleanup action is disabled

### Requirement: Cleanup task behavior

The application SHALL run only confirmed, validated candidates. Routine cleanup SHALL be limited to configured safe caches, logs, and rebuildable developer artifacts; general analysis SHALL report candidates for review; and advanced maintenance SHALL remain separate from routine cleanup.

#### Scenario: Routine cache and log cleanup

- **WHEN** the user confirms routine cache and log candidates
- **THEN** the application cleans only the configured bounded targets
- **AND** it does not recursively delete every entry under `~/Library/Caches`

#### Scenario: Developer cleanup

- **WHEN** the user confirms developer cache or project-artifact candidates
- **THEN** the application cleans only recognized candidates inside configured boundaries
- **AND** it skips candidates that are recent, in use, protected, or ambiguous

#### Scenario: Large-file analysis

- **WHEN** the user confirms a large file from analysis
- **THEN** the application moves the file to the Trash
- **AND** it does not permanently delete an arbitrary user file as part of routine cleanup

### Requirement: Privileged operation handling

The application SHALL request administrator authorization only after the user confirms a candidate set containing privileged operations. Multiple confirmed privileged operations in one run SHALL share one authorization request, while authorization failure SHALL remain visible in the per-operation results.

#### Scenario: Single authorization request

- **WHEN** a confirmed candidate set contains one or more privileged operations
- **THEN** the application requests administrator authorization once for that run
- **AND** it does not authorize or execute unconfirmed candidates

#### Scenario: Authorization cancellation

- **WHEN** the user cancels the administrator authorization dialog
- **THEN** privileged candidates remain unmodified
- **AND** the application marks them cancelled or skipped instead of completed
- **AND** the user can review the results and retry later

### Requirement: Progress and live logs

The cleaning view SHALL represent scan, review, and apply stages and SHALL display ordered, structured events for candidate discovery and cleanup results.

#### Scenario: Scan progress

- **WHEN** a scan is running
- **THEN** the interface shows the active category and bounded progress information when available
- **AND** a stalled or timed-out probe cannot block the entire workflow indefinitely

#### Scenario: Apply progress

- **WHEN** confirmed candidates are being processed
- **THEN** the interface shows category and item-level progress
- **AND** each candidate receives one terminal result of removed, moved, skipped, failed, or cancelled

#### Scenario: Ordered log events

- **WHEN** a process emits output or a filesystem operation completes
- **THEN** the corresponding event is appended in execution order
- **AND** the run cannot enter its completed state before all pending events have been delivered

### Requirement: Error reporting

The application SHALL preserve command, filesystem, permission, timeout, and validation failures as explicit results. It SHALL fail closed for unsafe or ambiguous candidates and SHALL never present a failed operation as successful.

#### Scenario: Candidate failure

- **WHEN** a confirmed candidate cannot be processed
- **THEN** the candidate is marked failed or skipped with a reason
- **AND** the failure contributes to the final summary
- **AND** remaining candidates continue only when doing so is safe

#### Scenario: Discovery failure

- **WHEN** a scan cannot verify a location or candidate set
- **THEN** the application does not broaden the scan or deletion scope
- **AND** it reports the affected category as incomplete or unavailable

### Requirement: Completion summary

The completed view SHALL show scan and operation totals, category-level affected bytes, user-visible errors, and the distinction between permanent removal and Trash moves.

#### Scenario: Completed run

- **WHEN** all confirmed candidates have reached terminal states
- **THEN** the application shows the before-and-after disk values when available
- **AND** it shows scanned, selected, removed, moved, skipped, failed, and cancelled counts
- **AND** the user can open the corresponding operation history entry

#### Scenario: Partial or cancelled run

- **WHEN** at least one candidate is skipped, failed, or cancelled
- **THEN** the application presents a partial-result state
- **AND** it does not label the run as an unqualified success
