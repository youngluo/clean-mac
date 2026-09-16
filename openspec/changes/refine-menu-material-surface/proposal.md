## Why

面板需要与 App 自身的右键菜单看起来是同一张表面。

右键菜单是系统 `NSMenu`，实测其表面为 `R244 G246 B247`：比背景亮约 9 个色阶，G、B 比 R 高 2~3，偏冷近白；主文字 `#1B1B1B`（亮度 27），次要文字（快捷键 ⌘Q）`#919192`（亮度 146）。面板实测 `R242 G244 B245`，与其只差 2 个色阶，色相特征一致。

但此前迭代把根材质从 `.menu` 换成了 `.popover`：先是因为 `windowBackgroundColor`（约 `#ECECEC`）灰 tint 会把系统校准过的菜单材质压暗，于是移除 tint；随后为进一步提白换成 `.popover`。结果是白度达标，材质却与菜单不是一族，整体观感对不上。

本轮把根材质换回 `.menu`，用一层纯白低 alpha 提亮来标定白度。

## What Changes

- 根材质复用系统组件：macOS 26 起使用 `NSGlassEffectView`（系统菜单同款 Liquid Glass，`style = .regular`）；macOS 13~15 回退到 `NSVisualEffectView` + `.menu` + `.behindWindow`。两条路径均以约束承载内容，并都在表面图层设 `cornerRadius` + `masksToBounds`（缺圆角遮罩会让窗口阴影按方形计算、在窗口边界画出一圈方角暗线）。
- 根材质之上保留唯一一层纯白低 alpha 提亮（默认 `0.45`），用于把 `.menu` 的底色标定到与右键菜单实测表面一致；提亮只在亮色外观生效，暗色不叠加。
- 内容卡片叠加同源提亮，使卡片不出现比面板表面更暗的灰块，分组由细描边承担。
- 面板内侧保留一道纯白亮边；外侧描边在亮色下保持较系统菜单更轻的量级。
- 面板不叠加系统窗口投影。
- 验收基准：面板表面落在 `R244 G246 B247` 附近，与 App 自身右键菜单一致。

## Capabilities

### New Capabilities

### Modified Capabilities

- `spotless-app`: 主清理面板改用与 App 自身右键菜单同族的 `.menu` 材质，并允许一层纯白低 alpha 提亮用于标定白度；禁止使用中性灰根背景 tint。

## Impact

- `src/App/AppDelegate.swift`：`MenuMaterialView` 的材质、提亮层、内侧亮边与外侧描边。
- `src/Extensions/Theme.swift`：`SurfaceLift` 与内容卡片的同源提亮。
- `src/Views/Screens/CleaningView.swift`：取消按钮统一到项目已有的次要按钮样式。
- `openspec/specs/spotless-app/spec.md`：本 change 完成后同步根背景材质要求。
- 不改变清理行为、主题切换、布局、候选列表或内部交互。
