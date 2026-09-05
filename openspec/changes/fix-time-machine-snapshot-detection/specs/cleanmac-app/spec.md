## MODIFIED Requirements

### Requirement: 清理任务行为

应用 SHALL 将 Time Machine 快照状态和可用性作为空间分析信息，并且只有在确认存在实际本地快照记录时，才创建 Time Machine 维护候选项。

#### Scenario: 没有本地快照

- **WHEN** `tmutil listlocalsnapshots /` 只返回磁盘标题或没有实际快照记录
- **THEN** 空间分析不创建 Time Machine 快照候选项
- **AND** 保留“未发现本地快照”的扫描诊断
- **AND** 空间分析项目计数不因标题行增加

#### Scenario: 存在本地快照

- **WHEN** `tmutil listlocalsnapshots /` 返回一个或多个实际快照记录
- **THEN** 空间分析创建一个聚合的 Time Machine 维护候选项
- **AND** 该候选项保持待确认状态
