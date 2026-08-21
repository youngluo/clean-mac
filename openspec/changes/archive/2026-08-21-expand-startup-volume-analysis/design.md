## Context

当前分析 provider 只遍历 `~/Downloads`，结果模型只包含可清理候选，无法表达整个启动盘的容量、目录占用、受保护路径和部分扫描状态。现有 review 页面也把“没有候选项”当成没有可操作列表处理，缺少明确的完成和返回入口。具体动机见 `proposal.md`，行为约束见 `specs/cleanmac-app/spec.md`。

## Goals / Non-Goals

**Goals:**

- 以当前 macOS 本地启动卷为唯一默认分析边界，提供容量信息、顶层占用概览和可复核的大文件/目录候选。
- 将信息性分析结果与可执行清理候选分开建模，允许展示受保护或不可读位置但不允许对其执行清理。
- 让长时间扫描可取消、可报告进度，并在部分目录不可读或探测超时时返回可用结果。
- 让有候选、无候选、部分完成和取消结果都具备明确的 review/返回路径。
- 保持现有废纸篓、受限永久删除、路径复核和单次管理员授权策略。

**Non-Goals:**

- 不扫描或清理外置卷、网络卷和其他挂载卷，除非未来单独设计入口。
- 不把 `/System`、凭据、数据库、虚拟内存、活动备份数据等系统路径变成可删除候选。
- 不在本次变更实现完整的可视化磁盘树、应用卸载或重复文件分析。
- 不通过提升权限来扩大扫描可见范围，也不因权限错误自动改变扫描边界。

## Decisions

### 1. Use the startup volume as the analysis boundary

分析从 `/` 的卷资源信息开始，并确认卷是本地、非可移除的启动卷。卷容量和可用空间直接来自卷资源属性；目录遍历只在该卷内进行，不跟随符号链接或跨卷路径。

相比扫描 `~/Downloads` 或让用户手动选择任意路径，这能回答系统盘占用问题，同时保持范围稳定。相比把所有挂载卷都纳入，固定启动卷可以避免扫描时间和隐私范围随设备变化。

### 2. Separate volume summary from actionable candidates

扫描结果新增两类数据：

- **Volume summary**：卷总容量、可用容量、已测量容量、扫描状态，以及根目录下主要目录的占用项。受保护或不可读项可以出现在这里，并带有状态和诊断。
- **Cleanup candidates**：仅包含通过路径边界、安全策略和可执行方式校验的文件或目录。默认全部不选；大文件和普通用户目录使用 review 风险与废纸篓方式，已知可重建目录沿用现有开发清理策略。

这样全盘分析可以展示“哪里占空间”，但不会把“占空间”直接等同于“应该删除”。候选列表设置上限并按大小排序，避免把数万个文件一次性塞入菜单栏 popover；扫描进度和汇总仍覆盖完整遍历。

### 3. Use cancellable bounded traversal

扫描器对启动卷执行分阶段遍历：先读取卷信息和根目录概览，再遍历可读目录累计大小并筛选大文件/目录。每处理一批条目检查 `CancellationToken`，通过事件报告当前阶段、已处理条目、可估算的进度和诊断数量。

遍历默认跳过符号链接、跨卷目录、明确的系统运行时目录和无法验证的路径。单个目录读取失败只生成不可用诊断；候选扫描不因失败而转为更宽泛的 shell 删除。对外部进程或长时间探测设置独立超时，超时只影响对应位置并将结果标为 partial。

### 4. Extend the existing scan result and event flow

在现有 `ScanResult` 上增加可选的 `VolumeAnalysisSummary` 和 partial 状态，在 `CleanupEvent` 中增加结构化的扫描进度和扫描完成事件。候选仍复用现有稳定 ID、大小、修改时间、风险和 removal mode 字段；信息性目录项不进入 apply 快照。

View model 收到扫描完成事件后统一进入 review。review 页面同时渲染容量概览、诊断、候选列表和操作栏。无候选时显示空结果说明，保留“重新扫描”和“返回主界面”；返回主界面只清理当前 review 状态，不启动扫描或清理。

### 5. Expand validation only for user-owned analysis candidates

分析候选的可执行根目录从 Downloads 扩展到当前用户 Home，但仍拒绝系统根、凭据、浏览器历史、iCloud 同步数据、虚拟内存、数据库和符号链接路径。执行前复核路径、当前大小、保护状态、排除规则和 removal mode。

用户-owned 分析项只进入废纸篓流程；永久删除继续限制在开发清理的可重建目录。系统卷上仅用于概览的路径没有 removal mode，不会进入确认集合或管理员批次。

### 6. Keep the popover navigable in every terminal scan state

扫描完成、部分完成、取消和空结果都使用同一组终态出口。`isCleaning` 只表示扫描或 apply 正在进行；扫描结束后即使没有候选也恢复 transient popover，并在页面上提供返回 idle 的按钮。这个出口不依赖 `selectedCount`，避免禁用的清理按钮成为唯一可见操作。

## Risks / Trade-offs

- **[Scan cost]** 全卷遍历可能比 Downloads 扫描慢 → 分阶段事件、可取消检查、候选上限和部分结果保证菜单栏不会无限等待。
- **[Permission visibility]** 沙盒/TCC 可能导致用户目录或系统目录不可读 → 记录不可用位置，不请求隐含的广泛权限，也不把不可读位置当作可清理。
- **[Size accuracy]** 目录占用可能受硬链接、稀疏文件和 APFS 语义影响 → 将目录值标为 measured/estimated，并把卷可用空间作为独立事实展示。
- **[Review density]** 全盘大文件候选可能过多 → 默认只展示排序后的有限候选和分组概览，全部候选数量仍计入扫描结果。
- **[Stale candidates]** 扫描期间文件可能变化或消失 → apply 前复核大小、路径和保护状态，变化项标记失败或跳过。

## Migration Plan

1. 扩展模型和扫描事件，保留现有 routine、developer 和 Time Machine provider。
2. 将 analysis provider 改为启动卷扫描，先接入卷概览和只读候选，不改变其他清理类别。
3. 扩展 review UI 展示概览、partial/empty 状态，并为所有 review 结果增加返回 idle 的出口。
4. 扩展 analysis 候选的安全校验和废纸篓执行路径，补充全盘边界与取消测试。
5. 运行 OpenSpec strict validate、XCTest 和 Xcode Debug build 后再启用新的 analysis 入口。

回滚时可将 analysis provider 恢复为只读 Downloads 扫描；routine、developer、Time Machine 和已有历史数据不需要迁移。

## Open Questions

- 当前实现可以先采用固定的大文件阈值和候选上限；阈值是否需要做成用户设置，不影响本次规格和安全边界。
