# Tasks

## 1. 实现

- [x] 1.1 `UnifiedScanContext` 新增受保护子树集合：登记路径与按祖先前缀匹配的查询
- [x] 1.2 `scanDeveloper` 在"名称 + 项目标记命中但近期保护"分支登记产物目录为受保护子树
- [x] 1.3 空间分析在文件候选与 metrics 复用候选两条路径上，将受保护子树与前序候选所有权同样屏蔽；遍历与空间统计不变

## 2. 测试与验证

- [x] 2.1 新增用例：标记 + 近期项目的 `node_modules` 内大文件不出现在空间分析候选，Documents 统计仍大于 0
- [x] 2.2 新增用例：无标记通用 `build` 目录不受保护规则影响（沿用既有不入选用例断言候选语义）
- [x] 2.3 运行全量单元测试（增量并行）、`openspec validate --strict`、Debug 构建并替换运行实例

## 3. VCS 数据目录排除（并入）

- [x] 3.1 候选资格检查（`isEligibleAnalysisCandidate`，文件与观察复用共用）排除路径组件命中 `.git`/`.svn`/`.hg` 的子树；遍历与统计不变
- [x] 3.2 新增用例：`Documents/Repo/.git/objects/pack/*.pack` 大文件不入选，Documents 统计仍大于 0
- [x] 3.3 全量测试、严格校验、Debug 构建并替换运行实例

## 4. 磁盘镜像 bundle 与 Music 路径（并入）

- [x] 4.1 候选资格判定扩展：路径组件以 `.vmwarevm`/`.pvm`/`.sparsebundle`/`.disk` 结尾同样不产候选
- [x] 4.2 媒体保护表补默认 Music 资料库路径 `~/Music/Music/Music Library.musiclibrary`
- [x] 4.3 新增用例：VM bundle 内 dmg 不入选且统计保留；默认资料库内压缩包不入选
- [x] 4.4 全量测试、严格校验、Debug 构建并替换运行实例（与 3.3 合并执行）

## 5. DerivedData 产物化（并入）

- [x] 5.1 `DerivedData` 加入产物目录名单并豁免标记校验（无歧义名称通道）
- [x] 5.2 新增用例：近期项目 `DerivedData/ModuleCache.noindex` 内大文件不入选；30 天未动的 `DerivedData` 整目录进项目清理候选
- [x] 5.3 全量测试、严格校验、Debug 构建并替换运行实例

## 6. 跳过遍历与统计口径（并入）

- [x] 6.1 空间分析对受保护产物子树与机器管理 bundle 整树跳过（不枚举、不计字节）；metrics 复用与无 metrics 补扫语义不变
- [x] 6.2 `VolumeAnalysisSummary` 新增 `gapBytes`（总容量−可用−实测），各构造点透传
- [x] 6.3 `usr` 保护改为二级子项判定，`/usr/local` 纳入统计
- [x] 6.4 修正 :1630 过时注释（候选 home-only，无全局安装包发现）
- [x] 6.5 测试：调整受屏蔽域统计断言（补普通文件）、新增 gapBytes 一致性与 `/usr/local` 测量用例；全量测试、严格校验、Debug 构建并替换运行实例
