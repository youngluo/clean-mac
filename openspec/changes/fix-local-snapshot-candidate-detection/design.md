## Context

`tmutil listlocalsnapshots /` 的输出标题不是稳定的固定字符串。当前机器返回的是 `Snapshots for volume group containing disk /:`，而现有代码只过滤 `Snapshots for disk ` 前缀，因此标题会被当作记录。当前机器同时返回 `com.apple.os.update-*` 系统更新快照，这些记录不能直接作为 Time Machine 维护候选。

## Decision

将快照解析分成两步。第一步按行清理空白，并过滤所有以 `Snapshots for ` 开头且以冒号结尾的标题。第二步只保留以 `com.apple.TimeMachine.` 开头的实际 Time Machine 快照记录，其他系统管理记录或非结构化输出不参与候选判断。

`scanTimeMachine` 继续把多个实际 Time Machine 快照聚合为一个待确认的维护候选项；没有可维护记录时只保留已有的无快照诊断，不创建路径为空、大小未知的候选项。

## Verification

- 覆盖旧版磁盘标题和新版 volume group 标题。
- 覆盖仅含 `com.apple.os.update-*` 系统更新快照的输出。
- 覆盖实际 `com.apple.TimeMachine.*` 快照记录仍会被识别。
- 执行 Debug 构建并启动最新 CleanMac。
