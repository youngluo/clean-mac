# Proposal

## Why

项目清理对 30 天内使用过的项目刻意不生成产物候选，但空间分析的兜底条款（"前序 provider 因近期修改没有生成候选时仍可评估其中文件"）会从 `node_modules` 深处把大文件单独捞出为候选（实测 `~/Documents/workspace/resume/node_modules/.../next-swc.darwin-arm64.node` 130 MB 入选），"在用保护"被绕过，用户误删会破坏正在使用的项目。

## What Changes

- 产物目录同时命中"名称 + 项目特征标记"但被近期保护时，登记为受保护域：空间分析不在其整树内生成任何候选。
- 版本控制数据目录（`.git`、`.svn`、`.hg`）整树不进入空间分析候选：pack 等对象文件删除会不可恢复地损坏仓库。
- 磁盘镜像 bundle 目录（`*.vmwarevm`、`*.pvm`、`*.sparsebundle`、`*.disk`）与 VCS 同域处理：内部镜像成员文件不进入候选。
- 修正默认 Music 资料库保护路径：补 `~/Music/Music/Music Library.musiclibrary`（原表少一层，实际资料库未被排除，存在 TCC 弹窗与理论候选穿透），保留原路径兼容自定义位置。
- `DerivedData` 纳入项目产物目录名单，并作为无歧义名称免除标记校验：近期项目的 `DerivedData/ModuleCache` 内 `.pcm` 等再生文件不再被空间分析逐文件挑选；30 天未动的 `DerivedData` 以整目录进入项目清理候选。
- 屏蔽子树整树跳过遍历：近期保护产物与机器管理 bundle（VCS/磁盘镜像）目录不再为"无人消费的统计"逐文件扫描（本机实测约 14.8 万文件/次）；`volumeSummary` 已验证无任何 UI 消费方。前三类候选覆盖路径的 metrics 复用与补扫语义不变。
- 空间概览数据新增差额值 `gapBytes = 总容量 − 可用 − 实测`（仅数据层，不新增界面），承接保护、屏蔽与不可读区域。
- `/usr/local` 与 `/opt` 边界统一：`usr` 改为枚举子项并仅保护 `local` 以外的二级子项，第三方软件区纳入统计。
- 兜底条款收窄：仅保留"归属不明确"与"读取失败"两种兜底场景，移除"近期修改"兜底。
- 缓存侧本次不动：策略缓存根恒为候选已被屏蔽，临时目录在 `/private` 保护域内空间分析不可达，无同类漏洞；策略外缓存域的优化另行处理。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `spotless-app`: 近期项目产物目录对空间分析保持保护，兜底条款收窄至归属不明确与读取失败。

## Impact

- `src/Services/CleanerService.swift`：`scanDeveloper` 在近期保护分支登记受保护子树；`UnifiedScanContext` 承载保护路径；`scanStartupVolume` 复用所有权屏蔽检查。
- 测试：新增"标记 + 近期 → 产物目录内大文件不入选且仍计统计"用例；现有无标记场景的兜底断言不受影响。
- 主规格"启动磁盘分析"场景的兜底 AND 条款同步修订。
