## 1. 应用身份目录

- [x] 1.1 增加可持久化的命名空间拥有者历史，并限制未知数据只能保持隐藏
- [x] 1.2 递归收集标准目录、输入法、运行/注册应用及所有嵌套 Bundle 的身份、签名应用组和 Team ID
- [x] 1.3 解析 LaunchAgent/LaunchDaemon 的多种关联字段，并补充自定义位置的 Bundle ID 查询

## 2. 应用残留扫描安全边界

- [x] 2.1 用精确命名空间与历史拥有者交集替换单层 Bundle ID 和双向前缀启发式
- [x] 2.2 归一化 `.plist`、`.savedState`、`.binarycookies`，拒绝弱文件名和未知/共享 SDK 数据
- [x] 2.3 保持 Caches、Containers、WebKit 的模糊路径不进入候选，并同步清理执行的允许路径约束

## 3. 规格、测试与验证

- [x] 3.1 增加深层组件、输入法、签名/应用组路径、启动项、多拥有者、历史生命周期和弱文件名的通用 fixture 测试
- [x] 3.2 同步 README 与主规格，执行 `git diff --check` 和 OpenSpec 文档检查
- [x] 3.3 执行 XCTest、Spotless Debug 构建，关闭旧实例并启动最新构建的 App

## 4. Review 收口修正

- [x] 4.1 修正应用来源递归边界，避免系统 Bundle 资源触发全局部分扫描
- [x] 4.2 将注册应用、签名和嵌套组件读取失败统一改为 fail-closed
- [x] 4.3 孤立启动项不得单独保护已卸载应用数据
- [x] 4.4 补充默认目录、Bundle 资源、签名异常和孤立启动项 fixture 测试，并重新验证 XCTest、构建和应用启动
