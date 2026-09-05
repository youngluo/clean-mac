## 1. 使用最新确认稿建立资源基准

- [x] 1.1 以用户最新确认的 PNG 作为 `icon_1024.png` 基准，保留圆角外透明区域。
- [x] 1.2 从同心六边形结构生成黑色菜单栏模板图标，保持透明画布。

## 2. 生成资源目录图片

- [x] 2.1 生成 `icon_16.png`、`icon_32.png`、`icon_64.png`、`icon_128.png`、`icon_256.png`、`icon_512.png` 和 `icon_1024.png`，保持现有 `Contents.json` 映射不变。
- [x] 2.2 生成 18 × 18 的 `menubar-icon.png` 和 36 × 36 的 `menubar-icon@2x.png`。

## 3. 验证并启动应用

- [x] 3.1 校验资源目录 JSON，以及所有 PNG 的尺寸、alpha 通道和透明四角。
- [x] 3.2 按项目要求执行 CleanMac Debug 构建，关闭旧实例并启动最新构建的应用。
- [x] 3.3 检查 Git diff 和工作区状态，确认改动范围仅包含图标资源与本 change 文档，并保留无关的 `AGENTS.md` 修改。
