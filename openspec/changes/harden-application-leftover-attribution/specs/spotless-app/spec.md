## MODIFIED Requirements

### Requirement: 已卸载应用残留

应用 SHALL 只把能够高置信度确认属于已卸载应用的数据加入“应用残留”候选。扫描 SHALL 建立当前应用身份目录，覆盖 `/Applications`、`/System/Applications`、`~/Applications`、Homebrew Cask、Setapp、输入法、运行和 LaunchServices 注册应用、应用包内所有嵌套 Bundle、签名应用标识（包含 Team ID）、应用组以及用户/系统启动项关联。应用发现不完整时 SHALL 暂停应用残留候选判定。Preferences、Saved Application State、HTTPStorages 和 Application Scripts 下的项目只有在精确命名空间匹配当前身份或已持久化的历史拥有者关系时才可判定归属；`Library/Caches`、`Library/Containers` 和 `Library/WebKit` 下无法确认归属的数据仍不进入候选。

#### Scenario: 深层嵌套组件保护当前数据

- **WHEN** 应用残留扫描发现的命名空间属于已安装应用包内深层 Framework、Updater、Helper、Service、Extension 或 SDK Bundle
- **THEN** 应用不创建对应的应用残留候选
- **AND** 判断不依赖嵌套组件所在的具体应用名称或固定路径

#### Scenario: 输入法和自定义位置应用保护数据

- **WHEN** Bundle ID 对应的应用位于用户/系统输入法目录、LaunchServices 注册的自定义位置或当前运行应用路径
- **THEN** 应用将其视为当前身份并保护精确匹配的数据
- **AND** 不因应用不在 `/Applications` 顶层就判定为已卸载

#### Scenario: 启动项关联保护数据

- **WHEN** LaunchAgent 或 LaunchDaemon 通过 `Label`、`BundleIdentifier`、`AssociatedBundleIdentifiers`、`Program` 或 `ProgramArguments` 指向一个应用或其组件
- **THEN** 应用将解析出的精确身份加入当前索引
- **AND** 该身份关联的数据不进入应用残留候选

#### Scenario: 签名应用组保护共享数据

- **WHEN** Application Scripts 项目与当前应用签名声明的 Team ID、`com.apple.application-identifier` 或应用组精确匹配
- **THEN** 应用保护该应用组命名空间
- **AND** 只要仍有一个声明该组的拥有者存在，共享数据就不作为已卸载应用残留

#### Scenario: 历史拥有者全部消失后可复核

- **WHEN** 某个 Preferences、Saved Application State、HTTPStorages 或 Application Scripts 命名空间曾在应用仍被确认存在时被观察到
- **AND** 该命名空间历史中的所有拥有者都不再出现在当前身份目录、运行状态、启动项或 LaunchServices 注册中
- **THEN** 应用可以将该项目作为默认不选中的应用残留候选
- **AND** 候选保留实际路径与当前体积信息

#### Scenario: 未知或共享归属保持隐藏

- **WHEN** 项目看起来像 reverse-DNS 名称，但没有当前身份匹配，也没有已确认的历史拥有者，或仍存在共享拥有者
- **THEN** 应用不将该项目加入可选择清理集合
- **AND** 不通过具体 SDK、浏览器扩展注册或当前机器的应用名称特例强行推断归属

#### Scenario: 多来源应用保护数据

- **WHEN** Bundle ID 对应的应用位于 Homebrew Cask、Setapp、系统应用目录、用户输入法目录或其它已发现的应用来源
- **THEN** 应用将其视为当前身份并保护精确匹配的数据
- **AND** 不因应用不在 `/Applications` 顶层就判定为已卸载

#### Scenario: 应用发现不完整时暂停残留判定

- **WHEN** 任一已存在的应用来源目录无法读取，或应用发现因取消而未完成
- **THEN** 应用残留 provider 报告部分扫描
- **AND** 本次扫描不生成应用残留候选

#### Scenario: 后缀和弱文件名归一化

- **WHEN** 项目名以 `.plist`、`.savedState` 或 `.binarycookies` 结尾
- **THEN** 应用去除后缀后按精确命名空间匹配
- **AND** `default.store-wal`、SQLite 旁车文件和其他无法构成可靠 Bundle ID 的文件名不进入历史或候选

#### Scenario: 不对模糊数据扩大清理范围

- **WHEN** `Library/Caches`、`Library/Containers` 或 `Library/WebKit` 下存在看起来像 Bundle ID 的目录
- **THEN** 应用将其视为不明确项并保持受保护
- **AND** 扫描不会因为新的身份历史机制而扩大这些根目录的清理范围
