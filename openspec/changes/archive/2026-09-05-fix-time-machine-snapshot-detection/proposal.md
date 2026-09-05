## Why

在没有本地快照时，`tmutil listlocalsnapshots /` 仍会输出 `Snapshots for disk /:` 标题。当前扫描逻辑只判断标准输出非空，因此把标题误判为一个 Time Machine 快照候选项，导致空间分析始终显示 1 项和大小未知。

## What Changes

- 只将 `tmutil` 输出中的实际快照记录加入空间分析候选项。
- 无实际快照时保留“未发现本地快照”诊断，不创建可清理候选项。
- 保持现有 Time Machine 状态检查、权限边界和特权清理行为不变。

## Impact

- `src/Services/CleanerService.swift`
- `Tests/CleanMacTests/CleanupServiceTests.swift`
