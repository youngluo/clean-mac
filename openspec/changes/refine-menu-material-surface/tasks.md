## 1. 根背景材质

- [x] 1.1 将 `MenuMaterialView` 的根背景调整为单一毛玻璃，移除 `windowBackgroundColor` 灰色 tint。
- [ ] 1.3 根材质从 `.popover` 换回 `.menu`，与 App 自身右键菜单同族；随后按实测把提亮值标定到菜单表面 `R244 G246 B247`。
- [x] 1.2 保留有效外观同步、圆角、细边框和阴影行为。

## 2. 纯白提亮层

- [ ] 2.1 在 `MenuMaterialView` 中于根材质之上增加纯白低 alpha 提亮视图（当前 `0.45`，可调），与根材质一同参与 `layout()`。
- [ ] 2.2 提亮层仅在亮色外观下生效，在 `viewDidChangeEffectiveAppearance` 流程中同步；暗色外观下 alpha 取 0。
- [ ] 2.3 确认提亮层不影响命中测试：z-order 位于根材质之上、SwiftUI hosting 之下。
- [ ] 2.9 自绘投影强度校准：实测 0.25 仅压出 7 阶（目标约 31 阶），拉到 `shadowOpacity` 1.0；复核白色背景下轮廓是否可见。
- [ ] 2.8 边缘收细：外侧描边 0.18 → 0.10，内侧亮边宽度 1pt → 0.5pt、alpha 0.8 → 0.45。
- [ ] 2.7 将亮色外观下的外侧描边从 `separatorColor` 0.35 调到 0.18，对齐系统菜单实测的约 31 个色阶；暗色维持 0.35。
- [ ] 2.6 在 `MenuMaterialView` 中补内侧纯白亮边（`rimView`，1pt、圆角随主圆角内缩），亮色下 alpha 0.8、暗色下为 0，仅用于轮廓感。
- [ ] 2.5 将 `取消` 按钮从 `.buttonStyle(.bordered)` 统一到 `ThemeSecondaryButtonStyle`，消除提亮后面板内最深的填充块。
- [ ] 2.4 在 `SubtleGlassPanelModifier` 中叠加与根背景同源的纯白提亮（共用 `SurfaceLift.whiteAlpha`），使内容卡片不再比面板表面更暗；暗色外观下不叠加。

## 3. 规格与验证

- [x] 3.1 执行 `git diff --check`，确认变更不影响现有未提交工作。
- [ ] 3.2 执行 Spotless Debug 构建。
- [ ] 3.3 关闭旧版 Spotless 并启动最新构建。
- [ ] 3.4 逐行取色复核：面板表面与内容卡片均不低于输入法菜单的同高度读数，且卡片不再出现比表面更暗的灰块。
- [ ] 3.5 在彩色或深色背景上复核：表面读数落在 `#F0`~`#F8` 且能读出背景冷暖色偏；暗色主题下无白色提亮。
