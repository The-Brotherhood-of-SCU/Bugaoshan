# 鸿蒙维护约定

- 鸿蒙适配的持久修改默认限定为 `ohos/`；用户明确要求纳入根工程的共享依赖和文件打开入口除外。
- 原生代码、OH 依赖配置、工具链锁、文档、测试和源码覆盖文件保存在 `ohos/`；相关脚本统一放在 `ohos/tool/`。
- 用户于 2026-09-23 要求鸿蒙改用根 `pubspec.lock`，先切换锁来源，暂不处理兼容性。
  准备时从根锁生成工作目录中的普通文件副本，仅转换本地 path 包的相对路径；
  使用 `--enforce-lockfile`，不允许独立解锁或回写根锁。根锁变化必须使准备缓存失效。
- 用户于 2026-09-23 要求根锁与远端 main 同步，OH 依赖来源在根声明中维护：
  根 `pubspec.lock` 完全采用 main `7fab588704291616077e6670994bf6ea9d78633e` 的 205 项记录；
  不手写 OH 包的锁记录，后续由用户执行 Pub 解析生成。
  根 `pubspec.yaml` 相比 main 保留 7 个独立 OH 包的 overrides，另按用户要求将
  `open_file_ohos` 作为普通 dependencies；这 8 个包均尚未重新解析到根锁。
  鸿蒙副本继承根 overrides，并转换其中两个本地包的相对路径。仍不维护或加载独立的
  `pubspec_overrides.yaml`，准备时清除旧文件；额外依赖的增减仍由 `pubspec_dependencies.json` 配置。
  当前根锁尚未包含覆盖结果，`--enforce-lockfile` 会拒绝这些差异；不擅自重新解析或解除严格校验。
- 用户随后要求还原 open_filex 主包：删除其 CPF override，根声明恢复为 `^4.7.0`，
  根锁沿用 main 的 hosted 4.7.0。该包不含 OH 实现，鸿蒙文件打开通过独立 `open_file_ohos` 调用。
- 用户随后要求将 CPF open_filex 下载到 vendor：完整原始仓库位于 `vendor/cpf/open_filex/`，
  固定 dev 提交 `513644d7a1320d5a9e8f14b97c1bb5c4ec4a2ced`，鸿蒙模块在其 `ohos/` 子目录。
  当前尚未拆分 `open_filex_ohos` 或接入依赖；下载源码不代表恢复 CPF 主包来源。
- 用户随后选择 `open_file_ohos 1.0.0`，并要求从根 override 移至普通 dependencies。
  来源为 CPF `fluttertpc_open_file.git` 的 `ohos/` 包，固定正式版提交
  `85db425fc4b8cc403983fc854a36da6f300ad952`；未运行依赖解析、构建或测试。
  文件打开统一入口为根 `lib/utils/open_file.dart` 的 `openFile(path)`：
  OH 调用 `open_file_ohos.OpenFile.open`，其他平台调用官方 `OpenFilex.open`，统一返回 `OpenResult`。
  附件页直接调用 `openFile`，只增加平台分发和返回类型转换；原生插件检查要求 `open_file_ohos`。
  根附件弹窗、下载管理和日历导出的通用打开分支已共用入口；删除两个附件页和打开工具的 OH 覆盖。
  日历导出的其他 OH 保存与原生导入适配仍保留在覆盖文件中，并同步根文件的基线哈希。
- 文档集中在 `ohos/docs/`；`README.md` 是开发总入口，各补丁目录的 README 仅说明就近配置。
- 第三方插件直接使用锁定的上游源码，不再维护或应用插件补丁；安全存储直接使用 OH 包自带的 Dart 接口。
- 用户于 2026-09-23 要求把应用信息、分享的 OH 实现拆成独立包，并直接在本地 CPF Git 仓库修改。
  两个独立包维护在 `vendor/cpf/` 对应仓库中，通过根 `pubspec.yaml` 的 path override 接入；
  鸿蒙工作目录继承根声明并转换相对路径，不在专用依赖配置重复声明。
  构建不得自动从云端拉取或覆盖这两个包的源码。分享原生适配直接编辑独立包中的 `.ets` 文件。
- Python 测试位于 `ohos/tests/python/`；OH Dart 测试维护为 `ohos/tests/flutter/*.dart.template`，
  只由构建脚本链接为鸿蒙工程的 `test/ohos/*.dart`，避免上游分析解析 OH 专用依赖。
- 原生工程只使用仓库 `ohos/`，DevEco 直接打开这里；不得复制第二个原生工程。
- `build-profile.json5` 的无签名基线必须受版本控制，以便 DevEco 在首次 Sync 前识别工程；
  本机签名路径、证书和密码不得提交。
- Flutter 工作目录固定在 `ohos/.flutter-workspace/`，其内不得创建或链接 `ohos/`；
  专用 Pub 缓存放在 `ohos/.pub-cache/upstream/`，隔离此前已打补丁的缓存；生成物不提交。
- 编译工程的手写 Dart 文件通过符号链接引用根 `lib/` 或鸿蒙覆盖文件；`assets/` 链接根资源目录。
  `lib/` 各级目录必须为真实目录；生成 Dart、ARB 合并结果及 Pub 配置使用本地普通文件，
  防止代码生成写回根源码。不得把源码目录整体链接，也不得用硬链接替代符号链接。
- 根 `lib/` 中保留用户要求的共享文件打开入口及调用，其余源码跟随上游。根 overrides 中的独立 OH 平台包包括：
  `shared_preferences_ohos`、`image_picker_ohos`、`path_provider_ohos`、`sqflite_ohos`、`url_launcher_ohos`。
  存在接口冲突的 OH 包仍留在鸿蒙专用配置。新增根 Git 依赖的 CI 下载和开发说明同步维护。
- `package_info_plus_ohos`、`share_plus_ohos` 两个本地独立包同样只在根 overrides 指定来源。
  file_picker_ohos 已下载原始仓库，适配留到下一次。
- Dart 适配维护为 `ohos/flutter/overrides/lib/` 下的完整文件，保持相对根 `lib/` 的路径。
  只保存有鸿蒙适配的文件；构建脚本在对应路径建立指向覆盖文件的链接，不复制整套业务源码。
- 源码及翻译基线登记在 `ohos/flutter/source-manifest.json`；上游对应文件变化时先合并再更新哈希，
  不通过只改哈希绕过同步。未覆盖文件直接采用上游；鸿蒙翻译条目放在 `ohos/flutter/l10n/`。
- `overrides/analysis_options.yaml` 只排除维护目录的独立分析；不得将其复制到最终 `lib/`，
  实际代码分析和测试在使用鸿蒙依赖的组装副本中进行。
- 只使用 `ohos/flutter/toolchain.lock.json` 固定的 SDK；当前明确采用 Flutter OH 3.44.9 canary 开发快照，
  按完整 framework 提交、引擎、Dart 和平台缓存锁定，不跟随浮动分支，不硬编码本机路径。
- Hvigor 路径适配保存在 `ohos/flutter/patches/hvigor/`；仅复制并调整锁定 SDK 的 Hvigor 工具源码，
  输出到 `.flutter-workspace/tooling/`，原生路径与 Flutter 工作目录显式分开。
- 嵌入层直接使用 SDK 按模式和架构选择的原始 HAR，不维护或应用嵌入层补丁，不重新打包 HAR。
- 同一分支维护；双 SDK 校验放在阶段六，发布签名放在最后阶段。
- 鸿蒙不提供应用内下载更新包及自安装流程，也不接入仅服务自更新的下载通知通道；这些内容已从后续计划移除。
- 当前用户负责测试、依赖解析、构建及真机调试；代理只修改代码和文档，不执行这些命令。
- 开发入口见 [README.md](README.md)，状态见 [docs/sync-plan.md](docs/sync-plan.md)。
