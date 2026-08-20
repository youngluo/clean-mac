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

### Requirement: Cleanup task selection

The idle view SHALL expose four independently selectable tasks, all selected by default:

- Time Machine local snapshot cleanup
- System cache and log cleanup
- Developer tool cache cleanup
- Large-file scanning

#### Scenario: Selection controls

- **WHEN** the user toggles a task row
- **THEN** only that task's selection state changes

- **WHEN** no task is selected
- **THEN** the Start Cleanup button is disabled

- **WHEN** at least one task is selected and the user starts cleanup
- **THEN** the application records the selected task set for the current run

### Requirement: Cleanup task behavior

The application SHALL run each selected task conditionally and SHALL skip unavailable tools or directories without treating an unavailable optional task as a fatal application error.

#### Scenario: Time Machine snapshots

- **WHEN** the Time Machine task is selected
- **THEN** the application runs `tmutil thinlocalsnapshots / 1000000000000 4`
- **AND** it reports the task result in the cleanup log

#### Scenario: System caches and logs

- **WHEN** the cache and log task is selected
- **THEN** the application cleans user caches under `~/Library/Caches`
- **AND** it cleans the configured safe system cache directories
- **AND** it deletes log files older than seven days from `/private/var/log` and `~/Library/Logs`

#### Scenario: Developer tool caches

- **WHEN** the developer cache task is selected
- **THEN** the application cleans available Homebrew, npm, and pip caches
- **AND** it skips a cache when its tool or directory is unavailable

#### Scenario: Large-file scan

- **WHEN** the large-file task is selected
- **THEN** the application scans `~/Downloads` for files larger than 200 MB and older than seven days
- **AND** it reports matching files without deleting them

### Requirement: Privileged operation handling

The application SHALL use `osascript` administrator authorization only for operations that require elevated privileges. Time Machine and system-level cache operations SHALL be batched into one authorization request for a cleanup run.

#### Scenario: Single authorization request

- **WHEN** a selected task set contains one or more privileged operations
- **THEN** the application requests administrator authorization once for the batch
- **AND** user-space tasks continue to use the normal user context

#### Scenario: Authorization cancellation

- **WHEN** the user cancels the administrator authorization dialog
- **THEN** the application stops the cleanup run
- **AND** returns to the idle state without reporting the privileged tasks as completed

### Requirement: Progress and live logs

The cleaning view SHALL show progress based on the number of selected tasks and SHALL display task output as the run proceeds.

#### Scenario: Task progress

- **WHEN** a selected task starts
- **THEN** the task is marked in progress
- **AND** the progress indicator shows the current task count

- **WHEN** a task completes, fails, or is skipped
- **THEN** the task count advances
- **AND** the task result remains visible in the log

#### Scenario: Log presentation

- **WHEN** a task emits stdout or stderr
- **THEN** the output is appended to the task log
- **AND** the log view scrolls toward the newest entry
- **AND** warning output uses the warning color

### Requirement: Error reporting

The application SHALL preserve task failures as explicit task results instead of silently treating failed commands as successful.

#### Scenario: Task failure

- **WHEN** a cleanup command exits unsuccessfully
- **THEN** the task is marked failed
- **AND** the error is appended to the log with warning styling
- **AND** the application continues with the remaining selected tasks when it is safe to do so

### Requirement: Completion summary

The completed view SHALL show disk availability before and after the cleanup run, the released-space result when it can be determined, and a scrollable summary of task logs.

#### Scenario: Successful completion

- **WHEN** all selected tasks have reached a terminal state
- **THEN** the application shows the before-and-after disk values
- **AND** it shows completed, failed, and skipped task results
- **AND** the Done button resets the run state and closes the popover

### Requirement: Visual assets and theme

The application SHALL provide the CleanMac leaf app icon in the standard macOS sizes and SHALL use the established theme roles for primary, in-progress, and warning states.

#### Scenario: Asset rendering

- **WHEN** the app icon is displayed in Finder or the Dock-related system surfaces
- **THEN** the icon renders from the CleanMac asset catalog at the supported macOS sizes

- **WHEN** cleanup status is shown in the popover
- **THEN** primary actions and success states use `#46B065`
- **AND** in-progress states use system blue `#007AFF`
- **AND** warning states use system orange `#FF9500`
