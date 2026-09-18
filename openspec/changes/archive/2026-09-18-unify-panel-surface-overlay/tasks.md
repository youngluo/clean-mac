## 1. 统一主面板表面叠加

- [x] 1.1 在主题令牌中增加暗色主面板低 alpha 中性叠加值 `0.20`，并确认亮色现有 `0.45 × 0.65` 计算保持不变
- [x] 1.2 将 `MenuMaterialView` 的亮色提亮视图抽象为统一表面叠加视图；macOS 26 及以上暗色玻璃路径使用中性深色 `0.20` 叠加，且叠加层仍位于系统玻璃之上、SwiftUI 内容之下
- [x] 1.3 保持外观变化刷新、圆角、内容约束、旧系统 `.menu` 路径和命中测试不变，并通过代码检查确认亮色、暗色分支均使用同一叠加层级
- [x] 1.4 将暗色主面板叠加从 `0.06` 调整为 `0.08`，并确认亮色叠加与其它界面层级不变
- [x] 1.5 将暗色主面板叠加从 `0.08` 调整为 `0.20`，并确认暗色内容卡片仍保持 `0.06`
- [x] 1.6 将暗色主面板叠加从 `0.20` 调整为 `0.50`，并确认暗色内容卡片仍保持 `0.06`
- [x] 1.7 将暗色主面板叠加从 `0.50` 调整为 `0.30`，并确认暗色内容卡片仍保持 `0.06`
- [x] 1.8 将暗色主面板叠加从 `0.30` 调整为 `0.20`，并确认暗色内容卡片仍保持 `0.06`
- [x] 1.9 将亮色卡片背景从 `#F7F7F7 @ 0.5` 调整为纯白 `@ 0.20`，并确认暗色卡片与两主题边框保持不变
- [x] 1.10 将面板外部点击关闭条件从 `isCleaning` 调整为 `appState != .idle`，让扫描、确认、清理和结果状态保持面板常驻

## 2. 规格与验证

- [x] 2.1 运行 `openspec validate unify-panel-surface-overlay --type change --strict`，确认 proposal、delta spec、design 和 tasks 格式有效
- [x] 2.2 运行 `rtk git diff --check`，确认代码和文档没有空白错误
- [x] 2.3 运行 Spotless Debug 构建 `rtk xcodebuild -quiet -project src/Spotless.xcodeproj -scheme Spotless -configuration Debug -derivedDataPath /private/tmp/spotless-derived-data build`，确认修改可以编译
- [x] 2.4 关闭旧版 Spotless 并运行 `rtk open /private/tmp/spotless-derived-data/Build/Products/Debug/Spotless.app`，确认最新构建可以启动
- [x] 2.5 检查非 `idle` 状态的常驻条件与 `idle` 状态的外部关闭行为，确认状态切换逻辑与面板事件监视器一致
