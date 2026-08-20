# CleanMac

macOS menu bar cleanup app in SwiftUI.

## Quick Start

```bash
cd src && xcodegen generate
xcodebuild -project src/CleanMac.xcodeproj -scheme CleanMac -configuration Debug build
```

## Architecture

MVVM, NSStatusItem + NSPopover, bached osascript privilege escalation. macOS 13+, Swift 5.9.

## Project Layout

```
src/
├── CleanMacApp.swift           # @main entry
├── AppDelegate.swift           # NSStatusItem, popover, icon rotation
├── Theme.swift                # Color.theme
├── Models/CleanTask.swift     # TaskId, CleanTask, TaskStatus
├── Services/CleanerService.swift  # Shell + sudo
├── ViewModels/CleanerViewModel.swift
└── Views/                     # MenuBarView, IdleView, CleaningView, CompletedView
```

## Assets

- **App icon**: `src/Assets.xcassets/AppIcon.appiconset/` (7 sizes)
- **Menu bar icon**: `src/Assets.xcassets/menubar-icon.imageset/` (1x + 2x PNG)

## Conventions

- UI text in Chinese (zh-CN)
- Colors: `Color.theme.primary / .inProgress / .warning`
- Read stderr **before** `waitUntilExit()`
- Popover: `.transient` idle, `.applicationDefined` cleaning
- **Git**: no Co-Authored-By
