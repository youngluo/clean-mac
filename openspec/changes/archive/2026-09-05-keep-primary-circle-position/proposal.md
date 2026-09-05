## Why

空闲、扫描、确认、清理和完成状态使用了不同的外层垂直间距，扫描动画还会额外上移圆球，导致主操作在状态切换时发生可见的上下跳动。

## What Changes

- 统一所有主界面状态中顶部磁盘信息与圆球之间的外层间距。
- 移除工作状态动画对圆球垂直位置的改变。
- 抽出统一的圆球视觉组件，避免空闲和工作状态的样式参数分叉。
- 收敛悬停、按下和工作状态动画，保留轻量反馈但减少跳动感。
- 保留圆球的尺寸、颜色、文案和清理行为。

## Impact

- `src/Views/MenuBarView.swift`
- `src/Views/Components/PrimaryActionCircle.swift`
- `src/Views/Screens/CleaningView.swift`
- `src/Views/Screens/IdleView.swift`
- `src/Extensions/Theme.swift`
