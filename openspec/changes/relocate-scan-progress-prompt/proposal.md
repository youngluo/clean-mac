## Why

扫描阶段的动态提示目前放在 provider 面板中，并与“扫描进度”标题叠加，导致圆形主操作下方的提示位置没有承担扫描反馈。将提示集中到圆形按钮下方后，用户可以在固定位置读取当前扫描阶段，provider 面板则专注展示各分类状态。

## What Changes

- 在圆形主按钮下方增加稳定的单行进度提示区域。
- 扫描中将当前 `scanProgress` 阶段文案显示在该区域，扫描尚未产生 provider 状态时显示准备扫描提示。
- 空闲提示与扫描提示复用同一个视觉元素，扫描时只更新描述文案，不显示分类名称。
- 移除 provider 面板中的扫描动态说明和“扫描进度”标题。
- 扫描完成及后续状态下 provider 面板只保留四个分类状态行，不显示阶段标题。
- 空闲状态继续使用现有安全扫描辅助说明，扫描完成后隐藏进度提示区域。

## Capabilities

### New Capabilities

### Modified Capabilities

- `cleanmac-app`: 调整统一清理界面的扫描进度提示位置和 provider 面板内容。

## Impact

- `src/Views/Screens/CleaningView.swift`：迁移扫描提示并收敛 provider 面板内容。
- `src/Views/Screens/IdleView.swift` 及提示组件：保持空闲提示与工作态提示的布局语义一致。
- `openspec/specs/cleanmac-app/spec.md`：更新统一清理交互要求。
- 不修改扫描服务、事件模型、清理行为或本地化数据结构。
