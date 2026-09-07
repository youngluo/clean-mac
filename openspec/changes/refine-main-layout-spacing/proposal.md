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
- 不新增依赖，不改变清理行为或数据模型。
