<div align="center">
  <img src="src/Assets.xcassets/AppIcon.appiconset/icon_512.png" width="128" height="128" alt="Spotless">
  <h1>Spotless</h1>
  <p>安全、透明的 macOS 菜单栏清理工具。</p>
  <p>简体中文&nbsp;&nbsp;|&nbsp;&nbsp;<a href="README.md">English</a></p>
</div>

Spotless 在菜单栏弹出面板中扫描可清理内容，允许用户逐项复核候选，再将确认的项目移入 macOS 废纸篓。扫描阶段只读，未经用户明确确认不会执行清理。

## 功能

- 扫描缓存、临时文件、开发工具缓存、项目产物、应用残留、安装包、压缩包和大文件。
- 按路径和体积复核候选项，只选择需要清理的内容。
- 扫描阶段只读，清理前要求确认并再次校验候选，确认后将文件移入 macOS 废纸篓。
- 分析启动磁盘空间和本地 Time Machine 快照。

## 安装

从 [GitHub Releases](https://github.com/youngluo/clean-mac/releases) 下载最新 DMG，将 `Spotless.app` 拖入 `Applications`。

如果应用未经公证而被 macOS 拦截，可以在“系统设置 → 隐私与安全性”中允许打开，或执行：

```bash
xattr -cr /Applications/Spotless.app
```

## 开发指南

### 环境要求

- macOS 13 或更高版本
- Xcode 26.0.1 或兼容版本
- Swift 5.9
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 启动命令

```bash
# 生成 Xcode 工程。
(cd src && xcodegen generate)

# 构建 Debug App。
xcodebuild -quiet -project src/Spotless.xcodeproj -scheme Spotless -configuration Debug -derivedDataPath /private/tmp/spotless-derived-data build

# 关闭正在运行的实例。
killall Spotless

# 启动最新构建。
open /private/tmp/spotless-derived-data/Build/Products/Debug/Spotless.app
```

### SDD 开发流程

Spotless 使用 OpenSpec 实践基于规格的开发。实现行为变更前，先在 `openspec/changes` 中记录 proposal、spec、design 和 tasks，并保持文档、代码和测试一致；完成后执行校验并归档 change。

## License

[MIT](LICENSE)
