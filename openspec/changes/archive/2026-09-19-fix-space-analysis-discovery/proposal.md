## Why

空间分析目前从启动磁盘根目录开始遍历，容易在访问受限目录或超时前还没处理到 `Downloads`，导致其中大于 10 MB 的普通文件没有候选。现有媒体排除规则也把用户的整个 `Pictures`、`Music` 和 `Movies` 目录排除了，和实际只保护系统 Photos/Music 应用及其关联数据的要求不一致。

## What Changes

- 优先扫描 `~/Downloads`、`~/Desktop` 和 `~/Documents`，确保普通文件大于 10 MB 的候选及时发现，同时保留启动磁盘空间统计。
- 保持安装包、压缩包等特殊文件的现有候选规则，不增加候选数量上限，不改变候选列表和大小显示。
- 将媒体保护范围收窄到系统 Photos.app、Music.app 及其明确关联的数据，不再整目录排除用户的 `Pictures`、`Music` 和 `Movies`。
- 修正启动磁盘保护边界、外部卷识别、硬链接重复计数及元数据读取失败处理，避免漏扫、误计和静默丢候选。
- 在统一扫描中将缓存清理、项目清理和应用残留的实际候选作为优先归属，空间分析只跳过这些候选路径及其子项，避免重复展示但保留无候选时的空间分析兜底。
- 保持扫描只读和空间概览内部数据结构；空间分析即使部分完成但已有候选时，provider 状态显示成功勾选，避免把可用结果误显示为警告。
- 项目产物候选增加“项目特征标记”闸门：目录名命中仅是嫌疑，须在其祖先链中找到 `.git`、`package.json` 等项目标记才成为候选，避免通用用户目录中同名 `build`、`dist` 等目录被误判。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `spotless-app`: 修正启动磁盘空间分析的扫描优先级、媒体保护范围、候选发现和异常处理；收紧项目产物候选判定。

## Impact

- 主要修改 `src/Services/CleanerService.swift` 和 `src/Views/Screens/CleaningView.swift`，必要时补充空间分析测试和内部数据去重逻辑；项目产物标记闸门同样落在 `CleanerService.swift` 的 `scanDeveloper`。
- 不修改界面文案、候选大小展示方式或候选数量限制。
- 不引入新的依赖或清理副作用。
