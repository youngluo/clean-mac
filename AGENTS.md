# Spotless

macOS menu bar cleanup app in SwiftUI.

## Quick Start

```bash
cd src && xcodegen generate
xcodebuild -project src/Spotless.xcodeproj -scheme Spotless -configuration Debug build
```

## Architecture

MVVM, NSStatusItem + NSPopover, bached osascript privilege escalation. macOS 13+, Swift 5.9.

## Project Layout

```
src/
├── SpotlessApp.swift           # @main entry
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
- 构建完成后，关闭当前运行的旧版 Spotless 实例，并启动最新构建的 App，保证可以直接验证修改。
- 构建命令：`rtk xcodebuild -quiet -project src/Spotless.xcodeproj -scheme Spotless -configuration Debug -derivedDataPath /private/tmp/spotless-derived-data build`
- 测试构建（一次）：`rtk xcodebuild build-for-testing -quiet -project src/Spotless.xcodeproj -scheme Spotless -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/spotless-derived-data`
- 运行测试（增量、并行；可加 `-only-testing:SpotlessTests/<Class>` 缩小范围）：`rtk xcodebuild test-without-building -project src/Spotless.xcodeproj -scheme Spotless -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/spotless-derived-data -parallel-testing-enabled YES -parallel-testing-worker-count 4`
- 关闭命令：`rtk killall Spotless`
- 启动命令：`rtk open /private/tmp/spotless-derived-data/Build/Products/Debug/Spotless.app`

## Change 归属

- 除非用户明确要求，不要将后续需求混入当前 change。后续改动默认归入当前相关且尚未归档的 change；只有用户明确要求新建 change，或当前 change 无关或已归档时，才创建新的 change。创建新 change 前，先归档其他尚未归档的 change。
- Explore 阶段只用于探索方案和确认需求。用户确认 `proposal` 后，结束 Explore，进入 fast-forward 和 apply 流程，连续生成或更新剩余文档、实现代码并完成必要验证；除非遇到需求歧义、设计冲突或错误，否则不逐项请求确认。
- 实现过程中，代码变更必须同步更新当前 change 的 `proposal`、`spec`、`design` 和 `tasks`，保持方案、约束、实现和进度一致。
- 归档前先 review 相关文档，清理过时描述，并同步移除或简化由此产生的冗余代码；然后将 delta spec 同步到主规格并确认结果。
- 完成归档后，提交归档文档及相关代码变更。
- Bug 的 spec 必须记录已确认的用户可见现象、根因和最终处理约束；排查日志、临时诊断代码和失败试改只保留在 design 或归档记录中，不混入长期规格。
