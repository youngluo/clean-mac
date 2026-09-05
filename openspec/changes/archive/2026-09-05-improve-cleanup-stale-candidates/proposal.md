## Why

CleanMac 在执行清理前会重新验证候选项。DerivedData 等动态目录在扫描完成后可能继续变化，当前代码会将“目录内容已变化”与真正的非法路径统一显示为“路径未通过安全检查”，用户无法判断问题原因，也没有直接的重新扫描入口。

## What Changes

- 为候选项记录文件身份，并在执行前验证路径没有被替换。
- 将扫描后内容变化与路径越界、受保护路径、符号链接等安全失败区分开。
- 对内容变化继续保持 fail-closed，不执行移入废纸篓操作。
- 在清理部分失败且原因是候选项变化时提供重新扫描操作。
- 保持现有允许根目录、排除规则和大小复核，不静默放宽安全边界。

## Capabilities

### Modified Capabilities

- `cleanmac-app`: 改进清理执行前的候选项复核和失败恢复体验。

## Impact

- `src/Models/CleanerError.swift`
- `src/Models/CleanupModels.swift`
- `src/Models/AppLanguage.swift`
- `src/Services/CleanerService.swift`
- `src/ViewModels/CleanerViewModel.swift`
- `src/Views/Components/CandidateReviewSection.swift`
- `src/Resources/Localizable.xcstrings`
- `Tests/CleanMacTests/CleanupServiceTests.swift`
