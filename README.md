<div align="center">
  <img src="src/Assets.xcassets/AppIcon.appiconset/icon_512.png" width="128" height="128" alt="Spotless">
  <h1>Spotless</h1>
  <p>A safe and transparent macOS menu bar cleanup app.</p>
  <p>English&nbsp;&nbsp;|&nbsp;&nbsp;<a href="README-zh_CN.md">简体中文</a></p>
</div>

Spotless scans removable files in one menu bar popover, lets you review the candidates, and moves confirmed items to the macOS Trash. Scanning is read-only and cleanup never starts without explicit confirmation.

## Features

- Scan caches, temporary files, developer caches, project artifacts, application leftovers, installers, archives, and large files.
- Review candidates by path and size, then choose exactly what to clean.
- Keep scanning read-only, require confirmation, validate candidates again, and move approved files to the macOS Trash.
- Analyze startup-disk usage and local Time Machine snapshots.

## Installation

Download the latest DMG from [GitHub Releases](https://github.com/youngluo/clean-mac/releases), then drag `Spotless.app` to `Applications`.

If macOS blocks the app because it is not notarized, allow it in **System Settings → Privacy & Security**, or run:

```bash
xattr -cr /Applications/Spotless.app
```

## Development

### Requirements

- macOS 13 or later
- Xcode 26.0.1 or compatible
- Swift 5.9
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Run locally

```bash
# Generate the Xcode project.
(cd src && xcodegen generate)

# Build the Debug app.
xcodebuild -quiet -project src/Spotless.xcodeproj -scheme Spotless -configuration Debug -derivedDataPath /private/tmp/spotless-derived-data build

# Close the running instance.
killall Spotless

# Launch the latest build.
open /private/tmp/spotless-derived-data/Build/Products/Debug/Spotless.app
```

### SDD workflow

Spotless follows Spec-Driven Development with OpenSpec. Describe behavior changes in `openspec/changes` before implementation, keep the proposal, spec, design, tasks, code, and tests aligned, then validate and archive the change when it is complete.

## License

[MIT](LICENSE)
