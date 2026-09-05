## Why

CleanMac 当前资源仍是上一版叶子图标，但用户已经确认使用新的几何六边形稿。需要将最新确认的绿色圆角方形与米白色同心六边形环同步到 App Icon 和菜单栏资源，并确保圆角外区域真正透明。

## What Changes

- 以用户最新确认的 1024 × 1024 PNG 作为唯一视觉基准。
- 更新 App Icon 的全部尺寸，保留外层绿色圆角方形、米白色大六边形和同心小六边形镂空。
- 从同心六边形结构生成清晰的黑色菜单栏模板图标。
- 保持四角透明、资源目录映射和现有应用功能不变。
- 通过资源检查和 Debug 构建验证图标可以被 CleanMac 正确打包。

## Capabilities

### New Capabilities

无。此 change 只更新应用视觉资源。

### Modified Capabilities

无。应用行为和用户可见功能要求不变。

## Impact

- `src/Assets.xcassets/AppIcon.appiconset/` 中的 App Icon PNG 资源。
- `src/Assets.xcassets/menubar-icon.imageset/` 中的菜单栏 PNG 资源。
- Xcode asset catalog 编译与 Debug App 打包结果。
- 不涉及 Swift 代码、API、依赖或数据存储。
