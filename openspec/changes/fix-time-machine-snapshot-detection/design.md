## Context

`tmutil listlocalsnapshots /` 的无快照输出可能只有磁盘标题，不能使用“标准输出是否为空”判断快照是否存在。实际快照记录位于标题之后的独立行中。

## Decision

将输出按行拆分，移除空行和 `Snapshots for disk ...:` 标题，只要剩余实际记录行非空就创建一个聚合的 Time Machine 维护候选项。没有记录时只追加已有的无快照诊断。

不改变候选项的聚合设计，也不为每条快照创建单独的删除候选项；执行阶段继续通过受限的 `tmutil thinlocalsnapshots` 维护操作处理确认后的候选。

## Verification

- 使用当前机器的无快照输出覆盖仅含标题的情况。
- 添加有实际快照记录和无实际快照记录的扫描测试。
- 执行 Debug 构建并启动最新 CleanMac。
