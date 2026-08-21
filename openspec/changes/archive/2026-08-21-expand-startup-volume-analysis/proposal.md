## Why

当前空间分析只扫描 `~/Downloads` 中超过 200 MB 且 7 天未修改的文件，无法回答用户“系统盘空间被什么占用”的核心问题。扫描没有候选项时，review 页面只有重新扫描和禁用的清理按钮，用户无法回到主界面。

## What Changes

- **BREAKING** 将空间分析范围从 `~/Downloads` 扩展到当前 macOS 本地启动盘，提供系统盘容量、顶层目录和大文件的空间占用概览。
- 将“全启动盘只读分析”和“允许清理的候选项”分离，系统目录、凭据、数据库、虚拟内存、Time Machine 等受保护路径只能分析或标记为不可操作。
- 保持外置磁盘不自动纳入扫描，避免扫描范围随挂载设备变化。
- 为全盘扫描增加阶段进度、取消、超时、权限不足和部分结果状态，不能因为单个目录不可读而扩大清理范围或阻塞整个流程。
- 保留用户文件移入废纸篓、可重建缓存和开发产物受限永久删除的安全策略。
- 当扫描完成但没有候选项时，显示明确的空结果状态，并提供“返回主界面”和“重新扫描”入口。
- 确保 review 状态始终存在返回主界面的路径，不依赖是否发现候选项。

## Capabilities

### New Capabilities

<!-- No separate capability is introduced; this change extends the existing CleanMac app contract. -->

### Modified Capabilities

- `cleanmac-app`: 扩展启动盘空间分析范围，增加全盘扫描状态与空结果导航，同时保持受保护路径和受控清理边界。

## Impact

- `src/Services/CleanerService.swift`: 增加启动盘概览、目录占用和大文件扫描，处理不可读目录、超时和取消。
- `src/Models/`: 补充卷分析或目录占用结果所需的模型，区分分析结果和可清理候选。
- `src/ViewModels/CleanerViewModel.swift`: 管理全盘扫描进度、部分结果、空结果和返回主界面状态。
- `src/Views/`: 更新空间分析结果、空状态和导航操作。
- `Tests/`: 增加启动盘边界、受保护目录、扫描取消、空结果和返回状态测试。
- 不引入新的运行时依赖，也不自动请求更宽泛的文件访问权限。
