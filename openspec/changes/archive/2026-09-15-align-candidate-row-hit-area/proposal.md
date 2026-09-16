## Why

可清理项目当前只有选择图标和名称响应点击，用户点击路径、大小或行内空白时没有反馈，整行的交互边界也没有与分组标题形成一致的视觉对齐。统一行级点击区域可以让候选项更容易发现和操作，并消除截图中列表右侧留下的无效区域。

## What Changes

- 将可选候选项改为整行可点击，点击行内任意位置都切换该候选项的选中状态。
- 让候选行的可用宽度和水平边距与分组标题保持一致。
- 保留不可选、已完成和受保护候选项的不可交互状态。
- 保留候选行的右键排除菜单、现有滚动定位和垂直间距。
- 更新候选列表相关规格、设计和实现任务，移除“仅名称和图标可点击”的旧约束。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `spotless-app`: 更新候选列表的点击区域和分组对齐要求。

## Impact

- 修改 `src/Views/Components/CandidateRowView.swift` 的行级按钮结构和命中区域。
- 视需要调整 `src/Views/Components/CandidateReviewSection.swift` 的列表宽度与分组标题对齐约束。
- 不新增依赖，不改变清理业务逻辑或文件系统操作。
