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

## Build Verification

- 每次修改代码或界面后，自动重新构建 Debug App，确认修改可以正常编译。
- 构建完成后，关闭当前运行的旧版 CleanMac 实例，并启动最新构建的 App，保证可以直接验证修改。
- 构建命令：`rtk xcodebuild -quiet -project src/CleanMac.xcodeproj -scheme CleanMac -configuration Debug -derivedDataPath /private/tmp/cleanmac-derived-data build`
- 关闭命令：`rtk killall CleanMac`
- 启动命令：`rtk open /private/tmp/cleanmac-derived-data/Build/Products/Debug/CleanMac.app`

## Change 归属

- 后续改动默认归入当前相关且尚未归档的 change，并同步更新其 proposal、spec、design、tasks 等文档。
- 只有用户明确要求新建 change，或当前 change 与任务无关、已归档时，才创建新的 change；创建前必须先归档其它尚未归档的 change。
- 归档 change 前自动同步 delta spec 到主规格，并确认同步结果。
- 每次归档 change 后必须执行一次 commit，提交归档产生的文档与相关变更。

## Explore 与执行

- 在 `openspec-explore` 阶段确认方案后，只需再次确认 proposal；proposal 确认后直接继续创建后续 OpenSpec 文档、实现代码并完成必要验证，直到代码写完，不再逐个 artifact 或实现步骤等待确认。
