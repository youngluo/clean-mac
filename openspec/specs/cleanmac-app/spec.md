# CleanMac Menu Bar App Specification

## Purpose

CleanMac provides a lightweight macOS menu bar application for reviewing and running common cleanup tasks. It replaces the original shell-script workflow with a native SwiftUI interface that exposes task selection, progress, logs, authorization, and cleanup results in one popover.

## Requirements

### Requirement: Menu bar application shell

The application SHALL run as a macOS 13 Ventura or later menu bar application without a Dock icon. It SHALL use Swift 5.9, SwiftUI, MVVM, XcodeGen, `NSStatusItem`, and `NSPopover` without external runtime dependencies.

#### Scenario: Application launch

- **WHEN** the application launches
- **THEN** it creates a single menu bar status item
- **AND** it keeps the application out of the Dock
- **AND** it presents the CleanMac popover when the status item is clicked

#### Scenario: Duplicate launch

- **WHEN** another CleanMac instance is already running
- **THEN** the new instance activates the existing instance
- **AND** the new instance terminates without creating a second status item

### Requirement: Menu bar icon and popover behavior

The application SHALL use the CleanMac leaf icon as a template menu bar icon. It SHALL use transient popover behavior while idle or completed and application-defined behavior while cleanup or authorization is in progress.

#### Scenario: Start and finish icon state

- **WHEN** cleanup starts
- **THEN** the menu bar icon changes to a rotating cleanup indicator
- **AND** the popover remains available while authorization is requested

- **WHEN** cleanup ends or is cancelled
- **THEN** the original CleanMac menu bar icon is restored
- **AND** the popover returns to transient behavior

#### Scenario: Right-click menu

- **WHEN** the user right-clicks the menu bar icon
- **THEN** the application shows an Exit command
- **AND** choosing Exit closes the popover and terminates the application

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

### Requirement: Cleanup task selection

The idle view SHALL expose routine cleanup, startup-volume analysis, developer-artifact cleanup, and advanced maintenance entry points. Each entry point SHALL start a read-only scan before any administrator authorization. Recent, high-risk, protected, or ambiguous candidates SHALL remain unselected unless the user explicitly selects them.

#### Scenario: Start a scan

- **WHEN** the user chooses a cleanup category or analysis workflow
- **THEN** the application starts a read-only scan for that workflow
- **AND** it does not request administrator authorization before the user reviews candidates

#### Scenario: Start startup-volume analysis

- **WHEN** the user chooses startup-volume analysis
- **THEN** the application scans the current local macOS startup volume without moving or deleting files
- **AND** it presents a review state when the scan finishes or produces a partial result

#### Scenario: Limited startup-volume access

- **WHEN** macOS has not granted CleanMac full disk access
- **THEN** the idle and review states show that the scan covers only readable locations
- **AND** the user can open the relevant macOS Privacy & Security settings and recheck the permission
- **AND** the scan remains usable without forcing the user to grant the permission

#### Scenario: Review selection

- **WHEN** the scan displays candidates
- **THEN** the user can select or deselect individual candidates or a category
- **AND** the interface shows the selected count and estimated affected size

#### Scenario: Empty scan result

- **WHEN** a scan finishes without any actionable candidates
- **THEN** the application shows a completed empty state instead of an inactive review screen
- **AND** the user can return to the idle main view or start the scan again

#### Scenario: Apply availability

- **WHEN** there are no confirmed eligible candidates
- **THEN** the destructive cleanup action is disabled

### Requirement: Cleanup task behavior

The application SHALL run only confirmed, validated candidates. Routine cleanup SHALL be limited to configured safe caches, logs, and rebuildable developer artifacts; general analysis SHALL report candidates for review; startup-volume analysis SHALL cover the current local startup volume; and advanced maintenance SHALL remain separate from routine cleanup.

#### Scenario: Startup-volume overview

- **WHEN** the user starts startup-volume analysis
- **THEN** the application reports total, available, and measurable occupied space for the startup volume
- **AND** it provides an overview of major directory or category usage and eligible large-file or large-directory candidates when measurable

#### Scenario: External volume boundary

- **WHEN** external or removable volumes are mounted
- **THEN** startup-volume analysis does not include them by default
- **AND** their contents cannot become cleanup candidates through this scan

#### Scenario: Protected startup-volume paths

- **WHEN** analysis encounters system roots, credentials, databases, virtual-memory data, active backup data, or another protected path
- **THEN** the application may report its size or mark it as unavailable for analysis
- **AND** it does not present the path as an actionable cleanup candidate

#### Scenario: Confirmed user-owned candidate

- **WHEN** the user confirms an eligible user-owned candidate from startup-volume analysis
- **THEN** the application moves it to the macOS Trash
- **AND** it records the result as moved rather than permanently removed

#### Scenario: Empty startup-volume result

- **WHEN** startup-volume analysis completes without eligible large-file or cleanup candidates
- **THEN** the application reports that the scan completed successfully with zero actionable candidates
- **AND** it does not report the scan as failed merely because no candidate was found

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

The cleaning view SHALL represent scan, review, and apply stages and SHALL provide bounded progress information, cancellation, timeout or unavailable diagnostics, and ordered, structured events for candidate discovery and cleanup results.

#### Scenario: Scan progress

- **WHEN** a scan is running
- **THEN** the interface shows the active category and bounded progress information when available
- **AND** a stalled or timed-out probe cannot block the entire workflow indefinitely

#### Scenario: Startup-volume scan progress

- **WHEN** a startup-volume scan is running
- **THEN** the interface shows the active scan stage and progress information when available
- **AND** the user can cancel the scan without triggering cleanup

#### Scenario: Unreadable or timed-out location

- **WHEN** a location cannot be read or a bounded probe times out
- **THEN** the application records the location as unavailable or incomplete
- **AND** it continues with safe remaining locations when possible without broadening the scan scope

#### Scenario: Partial scan result

- **WHEN** a scan completes with one or more unavailable locations
- **THEN** the interface distinguishes a partial result from a complete result
- **AND** it allows the user to review available candidates or return to the idle main view

#### Scenario: Apply progress

- **WHEN** confirmed candidates are being processed
- **THEN** the interface shows category and item-level progress
- **AND** each candidate receives one terminal result of removed, moved, skipped, failed, or cancelled

#### Scenario: Ordered log events

- **WHEN** a process emits output or a filesystem operation completes
- **THEN** the corresponding event is appended in execution order
- **AND** the run cannot enter a terminal state before all pending events have been delivered

### Requirement: Error reporting

The application SHALL preserve command, filesystem, startup-volume discovery, permission, timeout, and validation failures as explicit diagnostics or candidate results. It SHALL fail closed for unsafe or ambiguous candidates and SHALL never expand the cleanup scope because a location cannot be inspected safely or present a failed operation as successful.

#### Scenario: Candidate failure

- **WHEN** a confirmed candidate cannot be processed
- **THEN** the candidate is marked failed or skipped with a reason
- **AND** the failure contributes to the final summary
- **AND** remaining candidates continue only when doing so is safe

#### Scenario: Discovery failure

- **WHEN** a scan cannot verify a location or candidate set
- **THEN** the application does not broaden the scan or deletion scope
- **AND** it reports the affected category as incomplete or unavailable

#### Scenario: Startup-volume discovery failure

- **WHEN** a startup-volume location cannot be verified
- **THEN** the application reports the affected location or category as incomplete or unavailable
- **AND** it does not treat the failure as evidence that the location is safe to clean

#### Scenario: Permission guidance

- **WHEN** a protected system or application location is unavailable because of macOS privacy controls
- **THEN** the application groups the condition as a limited-access state instead of presenting every path as a blocking error
- **AND** it never attempts to grant itself full disk access or bypass the user consent flow

#### Scenario: Candidate validation failure

- **WHEN** a confirmed candidate disappears, changes size, becomes protected, or fails path validation before applying
- **THEN** the application skips or fails that candidate with a reason
- **AND** it continues only with candidates that still pass validation

#### Scenario: Cleanup permission preflight

- **WHEN** a discovered routine cleanup location cannot be moved to the macOS Trash by the current user
- **THEN** the application marks the location as protected and leaves it unselected
- **AND** it explains that Full Disk Access or another permission may be required before retrying
- **AND** it does not trigger a destructive operation merely to discover that permission is missing

### Requirement: Completion summary

The completed view SHALL show scan and operation totals, startup-volume status, before-and-after availability when available, measurable category totals, actionable candidate counts, user-visible diagnostics, and the distinction between permanent removal and Trash moves. It SHALL provide a navigation path back to the idle main view for both non-empty and empty results.

#### Scenario: Completed run

- **WHEN** all confirmed candidates have reached terminal states
- **THEN** the application shows the before-and-after disk values when available
- **AND** it shows scanned, selected, removed, moved, skipped, failed, and cancelled counts
- **AND** the user can open the corresponding operation history entry

#### Scenario: Completed startup-volume analysis

- **WHEN** startup-volume analysis finishes without blocking failures
- **THEN** the application shows the volume overview and scan completion status
- **AND** it distinguishes actionable candidates from protected, skipped, unavailable, or informational paths

#### Scenario: Empty completion state

- **WHEN** the completed scan contains zero actionable candidates
- **THEN** the application shows an explicit empty-result message
- **AND** the user can choose “返回主界面” or “重新扫描”

#### Scenario: Partial or cancelled run

- **WHEN** at least one candidate is skipped, failed, or cancelled
- **THEN** the application presents a partial-result state
- **AND** it does not label the run as an unqualified success

#### Scenario: Cleanup result navigation

- **WHEN** a cleanup run or analysis result is displayed
- **THEN** the user can return to the idle main view without relying on the presence of a cleanup candidate
- **AND** returning to the idle view does not start another scan or cleanup operation

### Requirement: Visual assets and theme

The application SHALL provide the CleanMac leaf app icon in the standard macOS sizes and SHALL use the established theme roles for primary, in-progress, and warning states.

#### Scenario: Asset rendering

- **WHEN** the app icon is displayed in Finder or the Dock-related system surfaces
- **THEN** the icon renders from the CleanMac asset catalog at the supported macOS sizes

#### Scenario: Status colors

- **WHEN** cleanup status is shown in the popover
- **THEN** primary actions and success states use `#46B065`
- **AND** in-progress states use system blue `#007AFF`
- **AND** warning states use system orange `#FF9500`
