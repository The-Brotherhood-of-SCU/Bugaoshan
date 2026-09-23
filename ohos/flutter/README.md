# Flutter OH 适配输入

此目录维护鸿蒙依赖配置、工具链版本、Dart 覆盖文件和 Hvigor 路径适配。开发与构建命令见
[鸿蒙开发入口](../README.md)，实现机制见 [Flutter 适配说明](../docs/flutter-adaptation.md)。

| 位置 | 用途 |
| --- | --- |
| [pubspec_dependencies.json](pubspec_dependencies.json) | 在副本增加或排除依赖 |
| [根 pubspec.lock](../../pubspec.lock) | 与其他平台共用的依赖锁；准备时复制并转换本地路径，严格校验 |
| [toolchain.lock.json](toolchain.lock.json) | 锁定 Flutter OH、Dart 与原生工具链版本 |
| [overrides/lib/](overrides/README.md) | 适配后的完整 Dart 文件，只覆盖同路径文件或新增 OH 文件 |
| [source-manifest.json](source-manifest.json) | 覆盖清单、逐文件及翻译条目的上游基线 |
| [l10n/](l10n/README.md) | 按键合并的鸿蒙 ARB 条目 |
| [patches/framework/](patches/framework/README.md) | 已移除的 Flutter framework 诊断补丁记录 |
| [patches/hvigor/](patches/hvigor/README.md) | SDK Hvigor 路径适配及锁定源码哈希 |

`ohos/.flutter-workspace/` 通过文件链接引用共用及鸿蒙适配 Dart，翻译合并和代码生成写入本地普通文件；
应用信息、分享的独立包直接在 `ohos/vendor/cpf/` 中的本地 Git 仓库维护并通过 path 接入，
见 [本地 CPF 插件](../docs/dependencies/local-cpf-plugins.md)；其他插件仍使用锁定上游源码。
Pub 缓存位于 `ohos/.pub-cache/upstream/`，不复用此前修改过的缓存。安全存储通过 Dart 覆盖调用 OH 包自带接口；嵌入层直接使用 SDK 原始 HAR。
根 `pubspec.yaml` 配置 7 个独立 OH 包的 overrides，另将 open_file_ohos 1.0.0 作为普通 Git 依赖；
open_filex 沿用 main 的 hosted 来源。根锁保留 main `7fab588` 的 205 项基线，这 8 个 OH 包均尚未解析到根锁。
根 `lib/utils/open_file.dart` 的 `openFile(path)` 由所有平台共用，按平台分发调用并统一返回类型。
构建仍启用 `--enforce-lockfile`，当前覆盖与根锁不一致会直接失败，兼容性暂未处理。
上述来源维护在根 `pubspec.yaml` 的 dependencies 和 dependency_overrides，工作目录继承并转换本地路径。
独立 `pubspec_overrides.yaml` 保持删除，工作目录中残留的旧文件会在准备时清除。
Dart 源码覆盖及工具链适配仍维护在本目录，SDK 安装目录不保存这些适配结果。
原生工程直接使用仓库 `ohos/`，DevEco 打开此目录；Flutter 工作目录中不再放置原生工程。

测试位于 [ohos/tests/](../tests/README.md)；阶段说明、兼容性审查和依赖对照已集中到
`ohos/docs/`，从 [开发入口](../README.md) 查阅。
