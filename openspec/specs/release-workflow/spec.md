# CleanMac 发布流程规范

## 目的

发布流程负责在 macOS 上构建 CleanMac、将应用打包为 DMG、更新版本和变更日志元数据，并发布带有可下载产物的 GitHub Release。发布操作应当明确、可复现；如果构建或打包失败，不得发布不完整的版本。

## Requirements

### Requirement: 手动触发带版本的发布

发布流程 SHALL 只能通过手动触发的 GitHub Actions workflow dispatch 运行。触发表单 SHALL 要求选择 major、minor 或 patch 版本升级类型。

#### Scenario: 发起发布

- **WHEN** 获得授权的维护者手动启动流程
- **THEN** GitHub Actions 展示受支持的版本升级选项
- **AND** 普通 push 不会自动运行发布流程

### Requirement: 可复现的 macOS 构建

流程 SHALL 使用支持的 Xcode 版本和 macOS runner，安装或调用 XcodeGen，根据 `src/project.yml` 生成 Xcode 工程，并构建 CleanMac Release 配置。

#### Scenario: 构建应用

- **WHEN** 发布流程进入构建阶段
- **THEN** 在调用 `xcodebuild` 前先生成 Xcode 工程
- **AND** 从 CleanMac scheme 产出 `CleanMac.app`
- **AND** 构建失败时在创建 tag 或发布版本前停止流程

### Requirement: DMG 打包

流程 SHALL 将构建后的应用打包为名为 `CleanMac-{version}.dmg` 的压缩 DMG。DMG SHALL 包含应用和用于拖放安装的 Applications 文件夹链接。

#### Scenario: 打包发布产物

- **WHEN** Release 构建成功
- **THEN** 流程使用 `hdiutil` 创建带版本号的 DMG
- **AND** 验证预期的 DMG 文件确实存在
- **AND** 打包失败时在给仓库创建 tag 或发布版本前停止流程

### Requirement: 版本元数据

流程 SHALL 根据当前项目元数据和所选升级类型计算下一个语义化版本，并在创建发布 commit 前更新面向用户的 bundle 版本和 build 版本。

#### Scenario: 升级版本

- **WHEN** 维护者选择 patch、minor 或 major
- **THEN** 流程只递增对应的语义化版本部分
- **AND** 在项目元数据、DMG 文件名、Git tag 和 GitHub Release 名称中使用同一版本

### Requirement: 生成规范化变更日志

发布流程 SHALL 根据版本之间的 Conventional Commit 提交信息生成变更日志。Feature 和 fix 提交 SHALL 按所选发布类型纳入结果，生成的变更日志 SHALL 与版本元数据一起提交。

#### Scenario: 生成发布说明

- **WHEN** 版本计算完成
- **THEN** 流程在 `CHANGELOG.md` 中创建新的版本段落
- **AND** 发布说明标识面向用户的功能和修复变更
- **AND** 将生成的说明提供给 GitHub Release action

### Requirement: 发布 commit 和 tag

流程 SHALL 仅在构建和打包成功后提交版本及变更日志修改，创建 `v{version}` tag，并将 commit 和 tag 推送到配置的主分支。

#### Scenario: 发布仓库元数据

- **WHEN** 应用和 DMG 通过构建及打包阶段
- **THEN** 流程使用发布版本提交发布元数据
- **AND** 将 commit 推送到主分支
- **AND** 推送匹配的 `v{version}` tag

#### Scenario: 发布前失败

- **WHEN** checkout、工程生成、构建、打包或变更日志生成失败
- **THEN** 流程以失败状态退出
- **AND** 不推送发布 tag，也不创建 GitHub Release

### Requirement: GitHub Release 产物

流程 SHALL 为匹配的版本 tag 创建 GitHub Release 并上传生成的 DMG。Release SHALL 支持 draft 发布，以便维护者在公开前检查变更日志和产物。

#### Scenario: 创建 Release

- **WHEN** 发布 commit 和 tag 已推送
- **THEN** GitHub 创建名为 `v{version}` 的 Release
- **AND** 附加 `CleanMac-{version}.dmg`
- **AND** 包含生成的变更日志内容
- **AND** 按配置的发布策略执行草稿或直接发布

### Requirement: Conventional Commit 类型

仓库 SHALL 对与发布相关的历史提交使用 Conventional Commit 前缀，包括 `feat`、`fix`、`docs`、`refactor`、`perf` 和 `chore`。

#### Scenario: 分类提交

- **WHEN** 变更日志生成器读取提交
- **THEN** 可以按 Conventional Commit 类型对发布说明分类
- **AND** 排除无关的合并提交
