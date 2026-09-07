## Why

工作状态下圆形主操作的视觉阴影与状态面板距离偏近，主界面的间距值也分散在多个视图中，后续调整容易产生局部不一致。与此同时，`CompletedView` 已不再参与统一清理流程，保留它会让维护者误以为存在第二套完成态布局。

## What Changes

- 增加工作状态圆形主操作与 provider 状态面板之间的视觉缓冲，同时保持圆球顶部定位和其他状态布局不变。
- 在当前生效的 SwiftUI 视图中集中管理语义化间距值，保持现有信息层级和紧凑度，减少散落的数字常量。
- 调整 provider 状态图标，0 项时显示正常完成图标；仍有候选项的 partial 状态继续显示警示图标。
- 将圆球的呼吸效果限定在正在扫描状态，清理执行、完成和其他状态保持静态。
- 过滤实际测得为 0 KB 的可清理候选项，保留大小未知的候选项。
- 在“可清理项目”标题右侧同时显示已选大小和全部候选项总大小，并用 `/` 分隔。
- 允许直接点击候选项名称切换选中状态，路径、大小和行内空白保持原有行为。
- 点击“移到废纸篓”后保留该按钮但禁用，防止重复触发；清理执行期间同时保留并禁用“完成”按钮，圆球显示“正在清理”，结束后显示“清理完成”。
- 删除未被主界面挂载的 `CompletedView` 及其旧完成态布局。
- 以 App 图标的鼠尾草绿和暖象牙白建立品牌色，主操作与进度状态使用同一色系，警告和失败状态使用独立的语义色。
- 清理成功的候选项仅保留成功图标，不再重复显示“已移到废纸篓”等成功结果文案。
- 将“移到废纸篓”作为操作区最左侧的主操作，重新扫描和完成操作依次排列在其右侧。
- 提亮主操作、成功和警告语义色，并提高主弹出层与内部面板的毛玻璃凝实度，减少背景透出。
- 在毛玻璃下方增加动态中性系统底色，不使用鼠尾草绿 tint，降低桌面背景颜色对界面的影响。
- 统一 NSPopover 原生外壳与 SwiftUI 根视图的系统背景，将毛玻璃效果保留在内部内容面板，消除箭头与内容区的背景分界。
- 将选中、成功、警告和失败状态改为 macOS 动态系统色，分别使用 systemGreen、systemGreen、systemOrange 和 systemRed；保留品牌绿用于主操作和品牌强调。
- 将正在扫描状态改为 macOS 动态 systemBlue，保持进行中与成功状态的语义区分。
- 将选中状态改为 macOS 动态 systemBlue，与成功状态的 systemGreen 区分。
- 清理完成后保留候选项目列表及其当前滚动位置，不因状态切换重新挂载清理视图。
- 将主操作按钮与圆形主操作统一为更深的鼠尾草绿，并使用暖象牙白前景增强品牌一致性与对比度。
- 同步 NSPopover 外壳、HostingView 与 SwiftUI 根背景的动态外观，避免箭头与内容区出现颜色分离。
- 移除 SwiftUI 根视图的不透明背景，让 NSPopover 原生材质同时绘制箭头与内容外壳。

## Capabilities

### New Capabilities

### Modified Capabilities

- `cleanmac-app`: 主界面工作态需要在圆球和 provider 面板之间保留稳定的视觉缓冲，并继续使用统一的主界面布局。

## Impact

- `src/Views/Screens/CleaningView.swift`
- `src/Views/MenuBarView.swift`
- `src/Views/Screens/IdleView.swift`
- `src/Views/Components/CandidateReviewSection.swift`
- `src/Views/Components/CandidateRowView.swift`
- `src/Extensions/Theme.swift`
- 删除 `src/Views/Screens/CompletedView.swift`
- 不新增依赖，不改变清理行为或数据模型；颜色集中在 `Theme.swift`，毛玻璃材质同步调整主界面与面板。
