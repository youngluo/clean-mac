<p align="center">
  <img src="src/Assets.xcassets/AppIcon.appiconset/icon_512.png" width="128" height="128" alt="Spotless">
  <p align="center"><strong>Spotless</strong></p>
  <p align="center">安全、透明的 macOS 菜单栏清理工具</p>
</p>

Spotless 在一个界面内完成磁盘扫描、候选选择、移到废纸篓和结果反馈。扫描阶段只读取文件系统，所有清理项都由用户确认后执行。

## 功能

- 扫描缓存、旧日志、项目产物、应用残留、安装包和启动磁盘
- 实时显示各分类实际扫描的文件数量
- 按分类展示候选路径、体积、选择状态和处理结果
- 清理前重新校验路径、符号链接、保护状态和体积
- 普通文件和目录统一移到 macOS 废纸篓
- 跳过系统保护路径、应用包和 Photos、Music 等媒体资料库
- 支持完全磁盘访问状态检查和 Time Machine 本地快照分析

## 清理范围

### 缓存清理

| 范围 | 路径 | 默认选择 |
| --- | --- | --- |
| 用户缓存 | `~/Library/Caches/com.apple.Safari`、`~/Library/Caches/com.apple.dt.Xcode` | 是 |
| 七天前的用户日志 | `~/Library/Logs` | 是 |
| Python、Node.js 与包管理器缓存 | `~/Library/Caches/pip`、`~/.npm/_cacache`、`~/Library/pnpm/store`、`~/Library/Caches/Yarn`、`~/.cache/yarn`、`~/.yarn/berry/cache`、`~/.bun/install/cache` | 否 |
| Apple 开发工具缓存 | `~/Library/Developer/Xcode/DerivedData`、`~/Library/Caches/CocoaPods`、`~/Library/Caches/org.swift.swiftpm` | 否 |
| Homebrew 缓存 | `~/Library/Caches/Homebrew` | 否 |
| Rust、Java 与 Go 缓存 | `~/.cargo/registry/cache`、`~/.cargo/git/db`、`~/.gradle/caches`、`~/Library/Caches/go-build`、`~/go/pkg/mod/cache/download` | 否 |
| 系统缓存与七天前的系统日志 | `/Library/Caches/com.apple.Safari`、`/Library/Caches/com.apple.dt.Xcode`、`/private/var/log` | 否，需要权限 |

开发工具缓存使用 macOS 常见默认路径，不读取工具的自定义环境变量。全局工具缓存归入缓存清理，不归入项目清理。

### 项目清理

扫描以下项目根目录：

- `~/Projects`
- `~/GitHub`
- `~/dev`
- `~/Work`
- `~/Documents`

识别以下可重建目录：

- 依赖与构建产物：`node_modules`、`target`、`.build`、`build`、`dist`、`.venv`、`venv`
- 前端与测试产物：`.next`、`.turbo`、`.parcel-cache`、`.vite`、`coverage`
- Python 工具缓存：`.pytest_cache`、`.mypy_cache`、`.ruff_cache`

候选项目必须超过 30 天未更新、不是符号链接且没有进程占用。候选默认不选中，只显示目录路径和聚合体积，不展示内部文件。

### 应用残留

应用残留扫描先建立当前应用身份目录，应用发现覆盖以下通用来源，并递归查找其中的 `.app` 包：

- `/Applications`
- `/System/Applications`
- `~/Applications`
- `/opt/homebrew/Caskroom` 和 `/usr/local/Caskroom`
- `~/Library/Application Support/Setapp/Applications`
- 系统和用户输入法目录
- 当前运行应用、LaunchServices 注册应用以及启动项关联的应用

应用身份还包含应用包内的 Helper、Updater、Service、Extension 等嵌套 Bundle，以及签名声明的 Team ID 和 App Group。启动项只有在能解析到真实应用包或 LaunchServices 注册应用时才会参与保护，孤立启动项不会把已卸载应用伪装成当前应用。应用清单无法完整读取时，应用残留分组会暂停候选判定并报告部分扫描。

残留扫描覆盖以下目录的直接子项：

- `~/Library/Application Support`
- `~/Library/Preferences`
- `~/Library/Caches`
- `~/Library/Containers`
- `~/Library/Saved Application State`
- `~/Library/WebKit`
- `~/Library/HTTPStorages`
- `~/Library/Application Scripts`

候选名称必须可以归一化为 Bundle ID，并且只能在已确认的身份历史中找到归属；当前应用、嵌套组件、共享数据和归属不明确的数据不会进入候选。`.plist`、`.savedState` 和 `.binarycookies` 后缀会在命名空间比对前移除，SQLite 旁车文件等弱文件名会被跳过。应用残留默认不选中，清理前会再次检查应用身份和候选文件状态。

### 空间分析

- 在 `~/Downloads`、`~/Desktop` 和 `~/Documents` 中扫描 `dmg`、`pkg`、`mpkg`、`xip`、`ipsw` 安装包
- 分析本地启动磁盘中的可读取文件和目录，不设置体积阈值
- 检查 Time Machine 状态，本地快照维护单独确认
- 跳过外部、网络和可移动磁盘
- 跳过系统保护路径、应用包、Pictures、Music、Photos 和 Music 资料库

空间分析候选默认不选中。`$TMPDIR`、`/private/tmp` 和 `/private/var/folders` 不在清理范围内。

## 安装

从 [Releases](https://github.com/vainjs/clean-mac/releases) 下载 DMG，将 `Spotless.app` 拖入 `Applications`。

应用未经 Apple 公证时，可在“系统设置 → 隐私与安全性”中选择“仍要打开”，或执行：

```bash
xattr -cr /Applications/Spotless.app
```

## 开发

### 环境要求

- macOS 13+
- Xcode 15+
- Swift 5.9
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

安装 XcodeGen：

```bash
brew install xcodegen
```

### 生成工程

`src/project.yml` 是 Xcode 工程配置源。修改 target、构建设置或文件组织后，需要重新生成工程：

```bash
cd src
xcodegen generate
cd ..
```

不要直接维护 `src/Spotless.xcodeproj/project.pbxproj` 中可由 XcodeGen 生成的内容。

### 构建

从仓库根目录执行：

```bash
xcodebuild \
  -project src/Spotless.xcodeproj \
  -scheme Spotless \
  -configuration Debug \
  -derivedDataPath /private/tmp/spotless-derived-data \
  build
```

构建产物位于：

```text
/private/tmp/spotless-derived-data/Build/Products/Debug/Spotless.app
```

启动最新构建：

```bash
killall Spotless 2>/dev/null || true
open /private/tmp/spotless-derived-data/Build/Products/Debug/Spotless.app
```

### 测试

```bash
xcodebuild \
  -project src/Spotless.xcodeproj \
  -scheme Spotless \
  -configuration Debug \
  -derivedDataPath /private/tmp/spotless-derived-data \
  -destination 'platform=macOS' \
  test
```

文件扫描、路径保护、默认选择、体积统计和废纸篓路由发生变化时，必须在 `Tests/SpotlessTests` 中补充或更新测试。

### 项目结构

| 路径 | 职责 |
| --- | --- |
| `src/App` | 应用入口、菜单栏状态和 Popover 生命周期 |
| `src/Models` | 清理候选、扫描状态、执行结果和错误模型 |
| `src/Services` | 文件扫描、安全校验、废纸篓操作、权限与历史记录 |
| `src/ViewModels` | 扫描、选择、执行和结果状态编排 |
| `src/Views` | SwiftUI 主界面、阶段页面和复用组件 |
| `src/Extensions` | 主题和通用扩展 |
| `Tests/SpotlessTests` | 服务、ViewModel 和清理流程测试 |
| `openspec` | 功能规格、设计、任务和归档记录 |

### 开发约束

- 架构保持 MVVM，视图不直接执行文件系统或权限操作。
- UI 文案使用简体中文，颜色优先使用 `Color.theme` 中的语义颜色。
- 扫描必须只读，不能把删除、移动或管理员命令作为扫描副作用。
- 新增扫描路径时，同步更新候选生成、执行前路径校验、README 和测试。
- 所有普通文件与目录使用废纸篓路由，不增加永久删除入口。
- 递归扫描必须在读取目录和元数据前应用系统、媒体和符号链接排除规则。
- 子进程必须先读取标准错误，再调用 `waitUntilExit()`，避免管道阻塞。
- 保留逐项失败结果，不允许单个候选失败中断整批清理。

### 贡献要求

- 功能分支基于 `main`。
- 行为变更在 `openspec/changes` 中包含对应 change，proposal、spec、design、tasks 与实现保持一致。
- 文件扫描、状态流或界面行为变更包含对应测试。
- 提交前通过 XCTest、Debug 构建和 `openspec validate <change-name> --strict`。
- 界面变更使用最新 Debug 构建完成实际运行验证。
- 提交保持单一职责，不添加 `Co-Authored-By`。
- Pull Request 说明变更范围、安全边界、测试结果，以及新增或调整的扫描路径。

## License

[MIT](LICENSE)
