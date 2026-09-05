## Why

空闲界面的圆形主操作上下留白偏紧，顶部磁盘信息、圆球、说明文字和权限提示卡片在视觉上挤在同一组内，降低了主操作的视觉层级。

## What Changes

- 增加空闲状态顶部信息与圆形主操作之间的垂直留白。
- 增加圆形主操作与说明文字、权限提示之间的垂直留白。
- 保持弹出面板宽度、圆球尺寸、文案和其他工作状态布局不变。

## Impact

- `src/Views/MenuBarView.swift`
- `src/Views/Screens/IdleView.swift`
