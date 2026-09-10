## Why

macOS 不同版本的 `tmutil listlocalsnapshots /` 会输出不同格式的磁盘标题，例如 `Snapshots for disk /:` 和 `Snapshots for volume group containing disk /:`。当前解析器只过滤第一种标题，可能把第二种标题当作快照记录，重新生成没有路径和大小的空快照候选项。

此外，系统更新产生的 `com.apple.os.update-*` 快照不是用户可维护的 Time Machine 快照，不应作为空间分析中的可清理候选项展示。

## What Changes

- 兼容并过滤所有 `Snapshots for ...:` 形式的标题行。
- 只将合法的 `com.apple.TimeMachine.*` 记录视为 Time Machine 本地快照。
- 忽略 `com.apple.os.update-*` 等系统管理快照，避免生成空的快照维护候选项。
- 补充新标题、系统更新快照和实际 Time Machine 快照的解析测试。

## Impact

- `src/Services/CleanerService.swift`
- `Tests/CleanMacTests/CleanupServiceTests.swift`
