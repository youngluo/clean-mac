## Why

macOS 27 的系统玻璃由系统决定基础透底效果，亮暗主题目前只有亮色面板使用应用侧提亮层，暗色面板没有对应的应用叠加。两种主题的表面补偿机制不一致，导致暗色面板的透底变化难以稳定控制。

## What Changes

- 让 macOS 26 及以上的主面板统一使用一层应用侧表面叠加视图，叠加视图位于系统玻璃之上、SwiftUI 内容之下。
- 亮色沿用现有白色叠加比例，不把当前约 `0.2925` 的最终值调整为 `0.30`。
- 暗色增加低 alpha 的中性深色叠加，使用 `0.20`，收住 macOS 27 的透底效果。
- 亮色内容卡片改用 `0.20` 的纯白低 alpha 叠加，暗色内容卡片、边框、布局、按钮和清理行为保持不变。
- 面板仅在 `idle` 初始状态允许点击外部关闭；扫描、确认、清理和结果状态均保持面板常驻。

## Capabilities

### New Capabilities

### Modified Capabilities

- `spotless-app`: 主面板在不同外观下统一使用应用侧表面叠加机制，同时保留主题对应的颜色和强度。

## Impact

- `src/App/AppDelegate.swift`：统一主面板表面叠加视图及亮暗主题的叠加颜色。
- `src/App/AppDelegate.swift`：让所有非 `idle` 状态的面板保持常驻。
- `src/Extensions/Theme.swift`：增加暗色主面板叠加层的独立视觉令牌。
- `openspec/changes/unify-panel-surface-overlay/specs/spotless-app/spec.md`：记录主面板叠加层的主题行为。
- 不引入新依赖，不改变清理流程或用户数据。
