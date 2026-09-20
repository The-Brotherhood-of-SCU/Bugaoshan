# 鸿蒙维护约定

- 鸿蒙适配的持久修改范围严格限定为 `ohos/`。
- 原生代码、依赖配置、锁文件、文档、测试和源码覆盖文件保存在 `ohos/`；相关脚本统一放在 `ohos/tool/`。
- 文档集中在 `ohos/docs/`；`README.md` 是开发总入口，各补丁目录的 README 仅说明就近配置。
- 插件补丁及其版本清单保存在 `ohos/flutter/patches/plugins/`，`legacy/` 仍参与旧缓存迁移。
- Python 测试位于 `ohos/tests/python/`；OH Dart 测试维护为 `ohos/tests/flutter/*.dart.template`，
  只由构建脚本链接为鸿蒙工程的 `test/ohos/*.dart`，避免上游分析解析 OH 专用依赖。
- 原生工程只使用仓库 `ohos/`，DevEco 直接打开这里；不得复制第二个原生工程。
- `build-profile.json5` 的无签名基线必须受版本控制，以便 DevEco 在首次 Sync 前识别工程；
  本机签名路径、证书和密码不得提交。
- Flutter 工作目录固定在 `ohos/.flutter-workspace/`，其内不得创建或链接 `ohos/`；
  专用 Pub 缓存放在 `ohos/.pub-cache/`，生成物不提交。
- 编译工程的手写 Dart 文件通过符号链接引用根 `lib/` 或鸿蒙覆盖文件；`assets/` 链接根资源目录。
  `lib/` 各级目录必须为真实目录；生成 Dart、ARB 合并结果及 Pub 配置使用本地普通文件，
  防止代码生成写回根源码。不得把源码目录整体链接，也不得用硬链接替代符号链接。
- 根 `lib/`、依赖声明、锁文件及其他平台文件跟随上游，不为鸿蒙直接修改它们。
- Dart 适配维护为 `ohos/flutter/overrides/lib/` 下的完整文件，保持相对根 `lib/` 的路径。
  只保存有鸿蒙适配的文件；构建脚本在对应路径建立指向覆盖文件的链接，不复制整套业务源码。
- 源码及翻译基线登记在 `ohos/flutter/source-manifest.json`；上游对应文件变化时先合并再更新哈希，
  不通过只改哈希绕过同步。未覆盖文件直接采用上游；鸿蒙翻译条目放在 `ohos/flutter/l10n/`。
- `overrides/analysis_options.yaml` 只排除维护目录的独立分析；不得将其复制到最终 `lib/`，
  实际代码分析和测试在使用鸿蒙依赖的组装副本中进行。
- 只使用 `ohos/flutter/toolchain.lock.json` 固定的稳定 SDK，不使用预览版，不硬编码本机路径。
- Hvigor 路径适配保存在 `ohos/flutter/patches/hvigor/`；仅复制并调整锁定 SDK 的 Hvigor 工具源码，
  输出到 `.flutter-workspace/tooling/`，原生路径与 Flutter 工作目录显式分开。
- 嵌入层适配保存为 `ohos/flutter/patches/embedding/` 的补丁；Hvigor 只在 Flutter 工作目录内生成
  修改后的 HAR，不直接修改 SDK 安装目录。接入脚本在 `ohos/tool/`。
- 同一分支维护；双 SDK 校验放在阶段六，发布签名放在最后阶段。
- 鸿蒙不提供应用内下载更新包及自安装流程，也不接入仅服务自更新的下载通知通道；这些内容已从后续计划移除。
- 当前用户负责测试、依赖解析、构建及真机调试；代理只修改代码和文档，不执行这些命令。
- 开发入口见 [README.md](README.md)，状态见 [docs/sync-plan.md](docs/sync-plan.md)。
