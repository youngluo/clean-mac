## MODIFIED Requirements

### Requirement: Cleanup task selection

The idle view SHALL expose separate routine cleanup, startup-volume analysis, developer-artifact cleanup, and advanced maintenance entry points. Starting an entry point SHALL begin a read-only scan and SHALL not request administrator authorization before the user reviews the concrete candidates.

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

- **WHEN** the scan displays actionable candidates
- **THEN** the user can select or deselect individual candidates
- **AND** the interface shows the selected count and estimated affected size

#### Scenario: Empty scan result

- **WHEN** a scan finishes without any actionable candidates
- **THEN** the application shows a completed empty state instead of an inactive review screen
- **AND** the user can return to the idle main view or start the scan again

### Requirement: Cleanup task behavior

The application SHALL distinguish read-only startup-volume analysis from cleanup execution. Startup-volume analysis SHALL cover the current local startup volume, while cleanup candidates SHALL remain limited to explicitly allowed user-owned, rebuildable, or otherwise approved targets.

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

### Requirement: Progress and live logs

The cleaning view SHALL represent startup-volume scanning, review, and applying as distinct stages. It SHALL provide bounded progress information, cancellation, timeout or unavailable diagnostics, and ordered events for partial scans and candidate operations.

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

#### Scenario: Ordered apply events

- **WHEN** confirmed candidates are being processed
- **THEN** each candidate receives one terminal result of moved, removed, skipped, failed, or cancelled
- **AND** the interface does not enter a terminal state before pending events are delivered

### Requirement: Error reporting

The application SHALL preserve startup-volume discovery, permission, timeout, validation, and filesystem failures as explicit diagnostics or candidate results. It SHALL fail closed and SHALL never expand the cleanup scope because a location cannot be inspected safely.

#### Scenario: Discovery failure

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

The completed view SHALL show startup-volume scan status, before-and-after availability when available, measurable category totals, actionable candidate counts, and user-visible diagnostics. It SHALL provide a navigation path back to the idle main view for both non-empty and empty results.

#### Scenario: Completed startup-volume analysis

- **WHEN** startup-volume analysis finishes without blocking failures
- **THEN** the application shows the volume overview and scan completion status
- **AND** it distinguishes actionable candidates from protected, skipped, unavailable, or informational paths

#### Scenario: Empty completion state

- **WHEN** the completed scan contains zero actionable candidates
- **THEN** the application shows an explicit empty-result message
- **AND** the user can choose “返回主界面” or “重新扫描”

#### Scenario: Cleanup result navigation

- **WHEN** a cleanup run or analysis result is displayed
- **THEN** the user can return to the idle main view without relying on the presence of a cleanup candidate
- **AND** returning to the idle view does not start another scan or cleanup operation
