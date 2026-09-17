## MODIFIED Requirements

### Requirement: 已卸载应用残留

应用 SHALL 只把能够高置信度确认属于已卸载应用的数据加入“应用残留”候选。扫描 SHALL 建立当前应用身份目录，覆盖 `/Applications`、`/System/Applications`、`~/Applications`、Homebrew Cask、Setapp、输入法、运行应用、按 Bundle ID 查询的 LaunchServices 注册应用和用户/系统启动项，并递归收集应用包内的嵌套 Helper、Service、Updater、Extension 等 Bundle。Bundle ID、签名应用标识（包含 Team ID）和应用组 SHALL 进入身份索引；应用来源扫描 SHALL 在进入 Bundle 包后停止展开包内资源，避免把资源目录误判为应用来源缺失。应用发现不完整或身份读取失败时 SHALL 暂停应用残留候选判定。Bundle ID 相同或以已安装 Bundle ID 加点号作为前缀的数据不得进入候选。`Library/Caches`、`Library/Containers` 和 `Library/WebKit` 下仅凭目录名无法确认归属的数据视为不明确项，不进入可选择候选。

#### Scenario: 已卸载应用残留分组

- **WHEN** 扫描发现用户目录中的数据无法与当前已安装应用关联
- **THEN** 应用只将高置信度的残留作为复核分组展示
- **AND** 不将任何已安装应用本体加入清理候选项

#### Scenario: 不明确的应用残留

- **WHEN** 残留路径无法高置信度关联到某个应用
- **THEN** 应用将其标记为信息项或受保护项
- **AND** 不将该路径加入可选择清理集合

#### Scenario: 已安装应用后缀归一化

- **WHEN** Preferences 或 Saved Application State 中的项目名以 `.plist` 或 `.savedState` 结尾
- **THEN** 应用在比对已安装 Bundle ID 前去掉该后缀
- **AND** 与已安装应用匹配的数据不进入残留候选

#### Scenario: 当前应用组件不作为残留

- **WHEN** 应用残留扫描发现的 Bundle ID 属于已安装应用，或属于其嵌套组件、启动项或 Bundle ID 子命名空间
- **THEN** 应用不创建对应的应用残留候选

#### Scenario: 归属不明确的数据不作为残留

- **WHEN** `Library/Caches`、`Library/Containers` 或 `Library/WebKit` 下存在看起来像 Bundle ID、但无法确认已卸载的数据
- **THEN** 应用不将该路径加入可选择候选
- **AND** 不因“未在顶层 `.app` 中找到同名 Bundle ID”就认定应用已经卸载

#### Scenario: 应用发现不完整时暂停残留判定

- **WHEN** 任一已存在的应用来源目录无法读取，或应用发现因取消而未完成
- **THEN** 应用残留 provider 报告部分扫描
- **AND** 本次扫描不生成应用残留候选

#### Scenario: 多来源应用保护数据

- **WHEN** Bundle ID 对应的应用位于 Homebrew Cask、Setapp、系统应用目录、用户输入法目录或其它已发现的应用来源
- **THEN** 应用将其视为当前应用身份
- **AND** 该身份及其嵌套组件对应的数据不进入应用残留候选

#### Scenario: 已卸载应用的身份数据仍可复核

- **WHEN** Preferences、Saved Application State、HTTPStorages、Application Scripts 或 Application Support 下的 Bundle ID 曾在应用仍存在时被身份历史确认
- **AND** 该 Bundle ID 的所有历史拥有者都不在当前完整身份目录中
- **THEN** 应用可以将该路径作为待复核的应用残留候选
- **AND** 候选默认不选中

#### Scenario: 孤立启动项不阻止残留识别

- **WHEN** LaunchAgent 或 LaunchDaemon 只剩 `Label`、`BundleIdentifier` 或 `AssociatedBundleIdentifiers`，但对应应用包、可执行文件和 LaunchServices 注册均不存在
- **THEN** 应用不得仅凭这些字段把该身份加入当前应用目录
- **AND** 已有历史归属且其它拥有者均已消失的数据仍可作为待复核残留

#### Scenario: 应用身份读取失败时保持安全

- **WHEN** 已注册应用的 Bundle、嵌套组件或代码签名信息无法读取
- **THEN** 应用残留 provider 报告部分扫描
- **AND** 本次扫描不生成应用残留候选
