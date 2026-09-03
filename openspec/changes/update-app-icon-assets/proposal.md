## Why

CleanMac 已确认新的绿色叶子图标方向，但当前批准稿仍是普通 RGB 图像，圆角外区域没有可靠的透明通道，且 App Icon 与菜单栏模板资源尚未统一更新。现在同步整理这些资源，可以避免 macOS 中出现方形底色，并确保不同尺寸下保持一致的视觉识别。

## What Changes

- 以用户最后确认的 PNG 为唯一视觉基准更新 App Icon 全部尺寸资源，不再人工重绘叶片主体。
- 为 App Icon 圆角外区域提供真正透明的 alpha 通道。
- 更新菜单栏图标的黑色模板资源，并保持其圆角外区域透明。
- 增大菜单栏模板图标的有效绘制区域，确保在 macOS 菜单栏中清晰可辨。
- 加粗菜单栏叶片轮廓，避免缩小后只剩下不易辨认的细小形状。
- 移除会造成视觉漂移且未被资源目录映射使用的旧 SVG 源文件。
- 保持现有绿色背景、白色叶子、中央叶脉和浅色内侧叶面，不改变应用功能或交互。
- 通过资源检查和 Debug 构建验证图标资源可被 CleanMac 正确打包。

## Capabilities

### New Capabilities

无。此 change 只更新应用视觉资源。

### Modified Capabilities

无。应用行为和用户可见功能要求不变。

## Impact

- `src/Assets.xcassets/AppIcon.appiconset/` 中的 App Icon PNG 资源。
- `src/Assets.xcassets/menubar-icon.imageset/` 中的菜单栏 PNG 与资源配置。
- Xcode asset catalog 编译与 Debug App 打包结果。
- 不涉及 Swift 代码、API、依赖或数据存储。
