## Why

应用残留扫描目前只读取常用安装目录的顶层 `.app`，并用目录名是否像 Bundle ID 来判断残留。这会漏掉应用包内深层 Framework、Updater、Helper、签名应用组和自定义位置的已安装组件，也会把 SDK 数据、浏览器扩展注册和数据库旁车文件误认为可清理残留。仅针对当前机器增加排除名单无法解决这类归属错误。

## What Changes

- 建立通用的应用身份目录，收集系统应用目录、用户应用目录、Homebrew Cask、Setapp、输入法、运行应用、LaunchAgent/LaunchDaemon 关联以及按 Bundle ID 查询的 LaunchServices 注册应用。
- 递归识别应用包内的 `.app`、`.appex`、`.xpc`、`.framework`、`.bundle` 和 `.plugin`，并读取签名应用标识（包含 Team ID）和应用组。
- 将启动项的 `AssociatedBundleIdentifiers`、`Program` 和 `ProgramArguments` 纳入身份索引。
- 对 Preferences、Saved Application State、HTTPStorages 和 Application Scripts 使用严格命名空间归一化；识别 `.binarycookies`，拒绝 `default.store-wal` 等弱文件名。
- 增加应用身份历史作为补充证据。只有曾在应用仍被确认存在时观察到、且当前所有拥有者都已消失的命名空间，才可作为应用残留候选；应用身份清单不完整时暂停候选判定。
- 未知、共享或无法验证归属的数据保持受保护/隐藏，不因名字像 Bundle ID 就展示为可清理项目。
- 应用来源扫描按 Bundle 包边界停止展开，注册、签名或组件身份读取失败时保持 fail-closed；孤立启动项不能单独证明应用仍然存在。
- 更新应用残留规格、README 和跨机器通用回归测试。

## Capabilities

### New Capabilities

### Modified Capabilities

- `spotless-app`: 收紧应用残留的归属证明和候选生成规则。

## Impact

- `src/Services/CleanerService.swift`：应用身份目录、残留命名空间判断和扫描流程。
- `src/Services/ApplicationIdentityHistoryStore.swift`：持久化曾确认过的应用命名空间拥有者。
- `Tests/SpotlessTests/CleanupServiceTests.swift`：增加嵌套组件、应用组、启动项、历史和弱文件名测试。
- `README.md` 与 `openspec/specs/spotless-app/spec.md`：明确 fail-closed 安全边界。

本变更不会按当前机器上的具体应用名称增加特例，也不会把扫描期间发现的未知数据直接标记为可清理。
