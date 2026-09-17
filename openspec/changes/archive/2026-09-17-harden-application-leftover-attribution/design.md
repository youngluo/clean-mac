## Context

macOS 没有公开的、覆盖所有任意用户数据的“卸载历史”接口。扫描时可以可靠确认当前应用及其签名组件，却不能从一个孤立的 `Library` 目录名反推出它曾属于哪个应用。因此“发现所有残留”和“零误删”不能同时通过无状态启发式保证。

本 change 采用 fail-closed 策略。当前扫描能确认的应用身份用于保护数据；扫描期间观察到的“命名空间 → 拥有者应用”关系写入 Spotless 自己的身份历史。应用消失后，只有历史中所有拥有者均不再存在的命名空间才重新进入复核候选。没有历史或存在共享拥有者的数据保持隐藏。

## Goals / Non-Goals

**Goals:**

- 以应用身份和签名声明为依据，而不是以本机具体应用名单为依据。
- 覆盖深层嵌套组件、输入法、运行/注册应用和启动项关联。
- 参考 Mole 的多来源应用发现，覆盖系统、用户、Homebrew Cask 和 Setapp 安装位置。
- 对应用组和 Team ID 路径进行精确归一化，避免把共享数据当作单应用残留。
- 在跨次扫描中保留可验证的归属证据，并让历史拥有者全部退出后才允许候选化。
- 保留既有的缓存、容器和 WebKit 模糊边界，不把它们升级为应用残留候选。

**Non-Goals:**

- 不通过扫描任意二进制内容猜测 SDK 的宿主应用。
- 不删除或自动清理没有身份历史的数据。
- 不调用私有 LaunchServices 数据库接口，不依赖当前机器的固定应用名称或路径。
- 不改变清理执行前的路径、符号链接和体积复核。

## Decisions

### 1. 使用结构化应用身份目录

每个当前应用记录根 Bundle ID、包内所有嵌套 Bundle ID、签名的 `com.apple.application-identifier`（其中包含 Team ID）、应用组和可解析的启动项关联。应用发现覆盖 `/Applications`、`/System/Applications`、`~/Applications`、`/opt/homebrew/Caskroom`、`/usr/local/Caskroom`、Setapp 应用目录和输入法目录，并递归查找其中的 `.app` 包；应用来源扫描遇到 `.app`、`.appex`、`.xpc`、`.framework`、`.bundle` 或 `.plugin` 等 Bundle 包时停止向包内资源展开，嵌套 Bundle 由应用包扫描单独解析，避免系统资源目录触发无意义的深度失败。再通过运行应用和 `NSWorkspace` 的 Bundle ID 注册查询补充自定义位置。任一已存在来源、已发现应用的组件、注册应用身份或代码签名信息无法读取时，身份目录标记为不完整，应用残留扫描不生成候选。

### 2. 启动项只作为可验证身份来源

LaunchAgent/LaunchDaemon 的 `Label`、`BundleIdentifier`、`AssociatedBundleIdentifiers` 只用于查询实际存在的 LaunchServices 应用；指向应用包的 `Program`/`ProgramArguments` 可直接解析并加入索引。只使用精确 ID 和已解析包身份，不使用双向前缀猜测，避免父命名空间反向覆盖无关项目。没有实际应用包或注册记录的孤立启动项不作为当前拥有者。

### 3. 持久化命名空间拥有者

身份历史按归一化命名空间保存拥有者根 Bundle ID，只作为精确身份规则的补充证据，不替代多来源当前应用清单。扫描到当前身份明确拥有的 Preferences、Saved State、HTTPStorages 或 Application Scripts 项目时记录关系；下次扫描只有历史记录存在且所有拥有者都不再出现在当前目录、运行状态、启动项或 LaunchServices 注册中，才生成复核候选。应用组拥有者只要仍有一个应用存在，就继续保护整个共享命名空间。

### 4. 采用语义归一化，不扩大文件名猜测

Preferences、Saved State、HTTPStorages 去除 `.plist`、`.savedState` 和 `.binarycookies` 后再匹配精确 Bundle ID。Application Scripts 通过 Team ID、`group.`/`groups.` 形式与签名应用组归一化匹配。没有明确命名空间的项目，以及 `default.store-wal`、SQLite 旁车文件等弱文件名，不进入历史或候选。

### 5. 读取失败保持受保护

注册应用查询得到路径但无法读取有效身份、应用包的组件遍历失败，或已签名包的代码签名信息无法读取时，目录标记为不完整。本次应用残留扫描直接返回部分结果，不使用已有历史去推断候选，避免把读取失败误判为已卸载。

### 6. 未知归属保持受保护

SDK 数据、Native Messaging 注册、浏览器共享目录和未被历史确认的 reverse-DNS 样式目录不能仅凭名称认定为已卸载应用残留。它们不进入“应用残留”可选择集合；这会牺牲一部分无历史数据的召回率，但避免将当前应用的共享组件误删。

## Risks / Trade-offs

- **首次运行没有历史**：之前未被 Spotless 观察过的已卸载应用残留不会被候选化。该限制是没有 macOS 卸载历史 API 时保证安全边界的必然结果。
- **LaunchServices 查询不完整**：目录扫描、运行应用、启动项和按 ID 注册查询多源合并；任何无法确认的项目仍保持隐藏。
- **身份历史增长**：只保存命名空间、拥有者和最近观察时间，不保存文件内容，并限制条目数量。

## Migration Plan

1. 增加身份历史存储和通用身份目录。
2. 替换应用残留扫描中的单层 Bundle ID 启发式。
3. 补充跨机器 fixture 测试并同步规格与 README。
4. 执行 `git diff --check`、XCTest、Debug 构建，并重启最新构建的 Spotless。

如需回滚，删除新的身份历史读取和严格候选门槛即可；不会影响已存在的清理历史或用户排除项。
