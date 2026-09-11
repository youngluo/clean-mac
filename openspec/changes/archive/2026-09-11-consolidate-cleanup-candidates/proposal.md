## Why

快速清理目前会把用户旧日志和临时目录中的每个文件都展示为单独候选，日志和临时文件数量较多时，确认列表难以阅读，也无法体现真正的清理范围。

## What Changes

- 不再将 `~/Library/Logs` 和 `/private/var/log` 的旧日志加入快速清理候选。
- 保留临时目录扫描，但按扫描根目录聚合为少量可选候选组。
- 候选组展示内部文件数量和实际占用空间，默认不选中。
- 清理时展开候选组，逐个重新校验内部文件并移入用户废纸篓。
- 支持候选组部分成功，避免因单个临时文件变化而扩大清理范围。
- 修正空间分析的全局安装包和压缩包规则，使用户目录（包括 `~/Library` 中未受保护的位置）仍能识别这些文件；普通大文件继续只在常用用户目录中按阈值识别。
- 收紧应用残留识别，只展示能够确认属于已卸载应用的数据；当前应用、Helper、Updater、Service 以及缓存、Container、WebKit 等归属不明确的数据不进入可选择候选。
- 移除清理结果页的“重新扫描”按钮，结果页只保留清理和完成操作；需要重新扫描时回到空闲页从主清理入口重新开始。
- 保留空间分析诊断数据供内部结果处理和调试，但不在候选确认界面增加额外提示面板。
- 收紧临时文件的年龄和大小快照处理，未知修改时间或未知聚合大小不再被误判为可清理或 `0 B`。

## Impact

- `src/Models/CleanupModels.swift`
- `src/Services/CleanerService.swift`
- `src/Models/AppLanguage.swift`
- `src/Resources/Localizable.xcstrings`
- `src/Views/Components/CandidateRowView.swift`
- `src/Views/Screens/CleaningView.swift`
- `Tests/CleanMacTests/CleanupServiceTests.swift`
