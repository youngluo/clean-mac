# CleanMac Release Workflow Specification

## Purpose

The release workflow builds CleanMac on macOS, packages the application as a DMG, updates version and changelog metadata, and publishes a GitHub Release with a downloadable artifact. Releases are intentional, reproducible, and protected from partial publication when build or packaging fails.

## Requirements

### Requirement: Manual versioned release trigger

The release workflow SHALL run only through a manual GitHub Actions workflow dispatch. The dispatch form SHALL require a version bump type of major, minor, or patch.

#### Scenario: Release request

- **WHEN** an authorized maintainer starts the workflow manually
- **THEN** GitHub Actions presents the supported version bump choices
- **AND** the workflow does not run automatically on ordinary pushes

### Requirement: Reproducible macOS build

The workflow SHALL use a macOS runner with a supported Xcode version, install or invoke XcodeGen, generate the Xcode project from `src/project.yml`, and build the CleanMac Release configuration.

#### Scenario: Build application

- **WHEN** the release workflow reaches the build stage
- **THEN** it generates the project before invoking `xcodebuild`
- **AND** it produces `CleanMac.app` from the CleanMac scheme
- **AND** a build failure stops the workflow before any tag or release is published

### Requirement: DMG packaging

The workflow SHALL package the built application into a compressed DMG named `CleanMac-{version}.dmg`. The DMG SHALL include the application and an Applications-folder link for drag-and-drop installation.

#### Scenario: Package release artifact

- **WHEN** the Release build succeeds
- **THEN** the workflow creates the versioned DMG with `hdiutil`
- **AND** it verifies that the expected DMG file exists
- **AND** a packaging failure stops the workflow before the repository is tagged or a release is published

### Requirement: Version metadata

The workflow SHALL derive the next semantic version from the current project metadata and the selected bump type. It SHALL update the user-facing bundle version and build version before creating the release commit.

#### Scenario: Version bump

- **WHEN** the maintainer selects patch, minor, or major
- **THEN** the workflow increments only the corresponding semantic version component
- **AND** it uses the resulting version consistently in project metadata, the DMG filename, the Git tag, and the GitHub Release name

### Requirement: Conventional changelog generation

The release process SHALL generate changelog content from Conventional Commit messages between releases. Feature and fix commits SHALL be included according to the selected release type, and the generated changelog SHALL be committed with the version metadata.

#### Scenario: Generate release notes

- **WHEN** the version has been calculated
- **THEN** the workflow creates a new version section in `CHANGELOG.md`
- **AND** the release notes identify the user-visible feature and fix changes
- **AND** the workflow exposes the generated notes to the GitHub Release action

### Requirement: Release commit and tag

The workflow SHALL commit the version and changelog changes, create a `v{version}` tag, and push both the commit and tag to the configured main branch only after build and packaging have succeeded.

#### Scenario: Publish repository metadata

- **WHEN** the application and DMG have passed the build and packaging stages
- **THEN** the workflow commits the release metadata with the release version
- **AND** pushes the commit to the main branch
- **AND** pushes the matching `v{version}` tag

#### Scenario: Pre-publication failure

- **WHEN** checkout, project generation, build, packaging, or changelog generation fails
- **THEN** the workflow exits unsuccessfully
- **AND** it does not push a release tag or create a GitHub Release

### Requirement: GitHub Release artifact

The workflow SHALL create a GitHub Release for the matching version tag and upload the generated DMG. The release SHALL support draft publication so maintainers can review the changelog and artifact before making it public.

#### Scenario: Create release

- **WHEN** the release commit and tag have been pushed
- **THEN** GitHub creates a release named `v{version}`
- **AND** it attaches `CleanMac-{version}.dmg`
- **AND** it includes the generated changelog content
- **AND** draft or direct publication follows the configured release policy

### Requirement: Conventional commit types

The repository SHALL use Conventional Commit prefixes for release-relevant history, including `feat`, `fix`, `docs`, `refactor`, `perf`, and `chore`.

#### Scenario: Classify commits

- **WHEN** the changelog generator reads commits
- **THEN** it can classify release notes by the Conventional Commit type
- **AND** unrelated merge commits are excluded from the generated summary
