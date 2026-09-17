## Why

面板需要与 App 自身的右键菜单看起来是同一张表面。

右键菜单是系统 `NSMenu`，实测其表面为 `R244 G246 B247`：比背景亮约 9 个色阶，G、B 比 R 高 2~3，偏冷近白；主文字 `#1B1B1B`（亮度 27），次要文字（快捷键 ⌘Q）`#919192`（亮度 146）。面板实测 `R242 G244 B245`，与其只差 2 个色阶，色相特征一致。

但此前迭代把根材质从 `.menu` 换成了 `.popover`：先是因为 `windowBackgroundColor`（约 `#ECECEC`）灰 tint 会把系统校准过的菜单材质压暗，于是移除 tint；随后为进一步提白换成 `.popover`。结果是白度达标，材质却与菜单不是一族，整体观感对不上。

本轮把根材质换回 `.menu`，用一层纯白低 alpha 提亮来标定白度。

## What Changes

- 根材质复用系统组件：macOS 26 起使用 `NSGlassEffectView`（系统菜单同款 Liquid Glass，`style = .regular`）；macOS 13 至 25 使用 `NSVisualEffectView` + `.menu` + `.behindWindow`。两条路径均以约束承载内容，并都在表面图层设 `cornerRadius` + `masksToBounds`（缺圆角遮罩会让窗口阴影按方形计算、在窗口边界画出一圈方角暗线）。
- 根材质之上保留唯一一层纯白低 alpha 提亮（默认 `0.45`），用于把 `.menu` 的底色标定到与右键菜单实测表面一致；提亮只在亮色外观生效，暗色不叠加。
- macOS 26 的 Liquid Glass 透底更强，亮色下以 `0.65` 比例使用中性白雾化层，降低蓝色桌面过度染色；暗色不叠加。
- 亮色外观下三个内容卡片在主面板毛玻璃上直接叠加不透明度 `0.5` 的 `#F7F7F7`，不重复使用 `thinMaterial`，并将边框提高到 `Color.primary.opacity(0.2)` 以补足层次；暗色内容卡片同样不重复使用 `thinMaterial`，只保留现有 `0.06` 白色提亮和 `0.07` 边框，缓和偏深观感。
- 可清理项目卡片标题与列表之间的分隔线在亮色主题下使用 `0.25` 不透明度，暗色主题保持现有 `0.45`，避免亮色近白表面上的线条过重。
- 圆球下方的扫描提示文案采用无句号的短语形式，中英文保持一致，并将“正在准备统一扫描”“正在进行大文件扫描”等偏绕表达收敛为更自然的短句；扫描阶段事件也更新该提示，避免高层阶段文案被流程状态切换丢弃。
- 圆球下方提示使用系统次要文字颜色，与权限卡片说明保持一致；移除主圆球按钮上的辅助 Tooltip。
- 缓存扫描阶段使用“正在扫描缓存”文案，与 provider 的“缓存清理”名称保持一致。
- 去掉缓存、项目和应用扫描中与 provider 详细提示重复的阶段文案；项目 provider 详细提示去掉 `node_modules` 这一内部实现名称，并清理未被扫描流程使用的重复安装包提示键。
- 面板内侧保留一道纯白亮边；外侧描边在亮色下保持较系统菜单更轻的量级。
- 保留面板现有系统窗口阴影，不增加自绘投影。
- 暗色外观下沿用原生系统玻璃，不在主面板下铺实色底。面板保留深灰半透明表面，并让桌面颜色经模糊后自然透出，匹配用户提供的视觉参考。
- 两套 pill 按钮的按下与禁用状态收敛到同一组共用常量：禁用填充统一取与次按钮同源的中性 tint，不再让主按钮借用描边令牌当填充，避免禁用按钮比可点的次按钮更重。
- “跟随系统”模式清除 App、面板和 HostingView 的固定外观覆盖，初始化和系统外观变化都继承 macOS 当前外观。
- 验收基准：亮色面板表面落在 `R244 G246 B247` 附近，与 App 自身右键菜单一致；暗色主面板呈深灰半透明玻璃，内容卡片稍浅并仍可辨认桌面模糊色彩。

## Capabilities

### New Capabilities

### Modified Capabilities

- `spotless-app`: 主清理面板改用与 App 自身右键菜单同族的系统材质，并允许一层纯白低 alpha 提亮用于亮色外观；暗色外观沿用原生半透明玻璃，不叠加实色根背景。

## Impact

- `src/App/AppDelegate.swift`：`MenuMaterialView` 的材质、提亮层、内侧亮边与外侧描边；系统主题模式的外观继承。
- `src/Extensions/Theme.swift`：`SurfaceLift`、内容卡片的同源提亮和暗色轻提亮；`ButtonSurface` 共用常量与两套按钮样式的禁用填充。
- `src/Views/Screens/CleaningView.swift`：取消按钮统一到项目已有的次要按钮样式。
- `src/Views/Screens/IdleView.swift`、`src/Views/Components/CandidateReviewSection.swift`：更新扫描提示的颜色与交互辅助文案，并按主题调整结果列表分隔线。
- `src/Services/CleanerService.swift`、`src/ViewModels/CleanerViewModel.swift`：统一阶段提示和 provider 详细提示的传递。
- `src/Models/AppLanguage.swift`、`src/Resources/Localizable.xcstrings`：收敛提示文案并删除未被引用的旧本地化键。
- `openspec/specs/spotless-app/spec.md`：本 change 完成后同步根背景材质要求和按钮状态量要求。
- 不改变清理行为、手动亮色/暗色主题、布局、候选列表或内部交互。
