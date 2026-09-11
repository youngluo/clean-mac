## Context

`CleanupCandidate` 当前代表一个文件或目录，临时目录扫描会为每个旧文件创建候选项。扫描结果、候选列表、选择状态和清理结果都以候选项为单位，因此单纯折叠 UI 不能安全地表达批量清理范围。

## Decisions

### 1. Keep candidates as the user-facing cleanup unit

为 `CleanupCandidate` 增加内部 `CleanupTarget` 列表。普通文件或目录候选包含一个目标，临时目录候选包含多个目标；候选组的实际分配空间是内部目标空间之和。

### 2. Remove broad log discovery from quick cleanup

快速清理不再递归扫描用户日志目录或系统旧日志目录。Codex Desktop 等诊断日志不进入默认候选，避免误删排障材料并减少列表噪音。

### 3. Aggregate temporary roots

临时目录仍依据当前用户、普通文件、非符号链接和 15 天未修改规则筛选，但每个配置的临时根目录最多生成一个候选组。候选组默认不选中，路径展示根目录，数量和体积展示内部目标的聚合值。

### 4. Revalidate every target before Trash

执行时不删除临时根目录本身。应用逐个检查目标路径、允许范围、符号链接状态、文件身份、实际分配空间和逻辑大小；目标变化或消失时只跳过该目标。

如果同一候选组同时包含成功、跳过或失败目标，候选组结果标记为部分完成，并保留需要重新扫描的错误信息。

### 5. Preserve the global installer/archive rule

空间分析先判断文件是否属于安装包或压缩包，再决定候选边界。此类文件在当前用户目录内不受 `~/Downloads`、`~/Desktop`、`~/Documents` 或 10 MB 阈值限制，因此 `~/Library` 下未落入保护目录、日志目录、排除目录或符号链接边界的 `.dmg`、`.pkg`、`.mpkg`、`.xip`、`.ipsw`、`.zip`、`.rar`、`.7z`、`.tar.gz` 等文件也可以成为候选。普通文件仍只在三个常用目录且超过 10 MB 时进入空间分析。

清理校验使用与扫描相同的特殊文件边界；日志目录和系统保护路径继续拒绝。缓存、应用残留等已登记的父目录仍保持唯一归属，不因为全局规则产生重复子候选。

### 6. Keep diagnostics out of the candidate list

空间分析的诊断结果继续保留在统一扫描结果和 ViewModel 中，供内部结果处理和调试使用，但候选确认界面不额外展示诊断面板，避免扫描提示重新增加候选列表噪音。

临时文件扫描只有在明确读到修改时间且早于 15 天截止时间时才接受文件；聚合大小只有存在已知大小时才报告数值，否则显示未知。部分清理结果的影响空间包含已经成功移入废纸篓的目标大小。

### 7. Use an installed-application identity index for remnants

应用残留扫描先收集标准应用目录中的应用 Bundle ID，再收集应用包内的 Helper、Service、Updater、Extension 等嵌套 Bundle，以及用户和系统启动项的 Bundle ID/Label。匹配时同时支持精确 ID 和以已安装 ID 加点号开始的子命名空间，避免把当前应用组件的缓存或偏好设置误判为卸载残留。

`Library/Caches`、`Library/Containers` 和 `Library/WebKit` 仅凭目录名无法证明应用已卸载，因此不再作为可选择的应用残留来源。Preferences、Saved Application State、HTTPStorages、Application Scripts 和 Application Support 保留为身份型残留来源，并在扫描时排除已安装身份；无法建立高置信度关联的数据宁可不展示。

### 8. Keep one scan entry point

候选确认和清理结果页不提供“重新扫描”按钮，避免在同一个底部操作区同时出现清理、完成和第二个扫描入口。需要重新扫描时，用户点击“完成”返回空闲页，再从主清理操作启动统一扫描；候选变化或缺失仍保留在结果消息中供用户理解。

## Verification

- 同一临时根目录的多个旧文件只产生一个候选组。
- 新文件、非当前用户文件、符号链接和目录不进入候选组。
- 日志目录不会生成用户旧日志或系统旧日志候选。
- 聚合候选清理时只移动内部目标，不移动根目录。
- 单个目标变化时其它目标仍按各自复核结果处理。
- `~/Library` 下非保护位置的安装包和压缩包可以进入空间分析，普通大文件规则不因此扩张。
- 空间分析为空时，候选确认界面显示该 provider 的诊断信息。
