# 鸿蒙 Flutter 适配

根工程维护共享业务、共用依赖声明和根锁文件。构建入口先检查对应上游源码基线，
在 `ohos/.flutter-workspace/` 通过文件链接共用根 Dart 源码，有覆盖的路径链接鸿蒙完整 Dart 文件。
`assets/` 直接链接根资源目录；生成代码、合并后的翻译及依赖配置使用独立本地文件。
原生工程直接使用仓库 `ohos/`，Flutter 工作目录内不放置原生工程。
环境及 DevEco 调试入口见 [鸿蒙开发说明](../README.md)。持久修改只保存在 `ohos/`。

| 位置 | 用途 |
| --- | --- |
| `ohos/flutter/overrides/lib/` | 适配后的完整 Dart 文件；未覆盖文件直接使用上游 |
| `ohos/flutter/source-manifest.json` | 文件及翻译条目的上游基线；新增项使用 null |
| `ohos/flutter/l10n/` | 鸿蒙新增或覆盖的 ARB 条目 |
| `ohos/tool/ohos_sources.py` | 只读基线检查、完整文件复制和翻译合并 |
| `ohos/tool/ohos_links.py` | 建立共用源码链接、维护链接清单、检查代码生成隔离 |
| `ohos/tool/ohos_native.py` | 连接根原生工程，刷新生成代码、插件注册及版本属性 |
| `ohos/tool/ohos_toolchain.py` | 从工具链锁读取 OH 产物版本与平台缓存哈希，在准备及增量编译前校验 |
| `ohos/tool/flutter_bootstrap.ts` | DevEco Sync 首次自举、失效环境重建及 OH 插件模块注入 |
| `ohos/flutter/patches/hvigor/` | SDK Hvigor 路径适配与源码哈希 |
| `ohos/flutter/pubspec_dependencies.json` | 仅在副本增加 OH 依赖、排除不使用的根依赖 |
| `pubspec.lock` | 所有平台共用的依赖锁；准备时复制并转换本地包路径，使用 `--enforce-lockfile` |
| `ohos/flutter/patches/framework/` | 已移除的 Flutter framework 诊断补丁记录 |
| `ohos/tests/` | 源码组装与插件脚本测试、OH Flutter 测试模板 |

## Dart 文件覆盖

[覆盖目录](../flutter/overrides/README.md) 只保存有鸿蒙适配的完整文件，目前 41 个：
27 个替换上游文件、14 个鸿蒙新增文件。它们通过同一个包名和最终 `lib/` 与共用文件一起编译。
构建时不再对应用源码执行 `git apply`。旧 26 个补丁及最终目标的对应关系见
[迁移记录](audits/source-overlay-migration.md)；上游已具备同等实现的适配会取消覆盖，
直接使用根 `lib/`。

- `main.dart`、`app.dart` 和主题相关文件：鸿蒙启动及主题回退，移除非 OH 的入口调用。
- `utils/file_save.dart`、`gallery_save.dart`、`image_pick.dart`、`open_file.dart`：
  接入 CPF 选择、保存及打开接口，统一结果和失败处理。
- `widgets/webview/download_webview.dart`：OH WebView 入口、下载回调、全局禁用回弹及实例生命周期。
- `widgets/webview/tuanwei_mobile_layout.dart`、`tuanwei_notice_loader.dart`：
  青春川大移动视口、CSS 重排及加载控制，关闭缩放。
- `widgets/webview/notice_layout_ready.dart`、`notice_webview_scripts.dart`：
  布局稳定后展示、教务处搜索框配色。主题由 ArkWeb AUTO 和原生配置更新处理，不自动 reload。
- 认证、API、表单与导航容器文件：相关覆盖已取消，直接采用根 `lib/` 的上游实现。
- `services/ohos_course_card_snapshot.dart`、`ohos_course_card_sync.dart`：课表快照、前台和设置同步。
- `utils/mobile_device_info.dart`、动态图标及开发者页文件：环境信息、图标 API 保护和文案。

原生卡片和平台通道仍在 `ohos/entry/src/main/ets/`；数据库、认证和业务仍采用上游架构。
迁移只改变维护与组装方式，既有功能验收记录不会自动成为新组装流程的构建通过记录。

## 翻译、分析和上游同步

[翻译目录](../flutter/l10n/README.md) 保存每种语言 8 项差异，按键合并到副本 ARB。
上游其他文案与元数据保留，本地化 Dart 文件由副本既有 `flutter gen-l10n` 步骤生成。

构建前检查所有覆盖文件的上游哈希，以及翻译条目的原值哈希。变化时列出对应路径或键，
在写入任何覆盖文件前停止；先合并上游变化，再更新对应基线，不静默覆盖上游新实现。
普通文件未被覆盖时直接采用上游。检查范围不包含上游所有接口关系，持续同步仍需双 SDK 验证。

覆盖目录的独立 `analysis_options.yaml` 排除维护用 `lib/**`，避免根 SDK 扫描不完整的 OH 源码。
这个配置不会进入副本最终 `lib/`；实际分析和测试仍使用根工程规则及鸿蒙依赖。

```powershell
# 仓库根目录，只读检查源码输入，不运行 Flutter 或构建
python ohos/tool/ohos_sources.py --check
```

## 第三方插件

第三方插件补丁及旧缓存迁移逻辑已移除。构建直接使用依赖锁指定的上游源码，
应用信息和分享的独立 OH 包在本地 CPF 仓库维护，其余插件不再应用补丁。
当前 7 个独立 OH 包的 Git/path 来源集中在根 `pubspec.yaml` 的 `dependency_overrides`，
鸿蒙副本继承并转换本地路径，仍使用根锁；额外 OH 依赖由增减配置接入。
根锁现与 main `7fab588` 完全一致，尚未包含 overrides 的解析结果，当前严格锁校验会失败。
准备时清除残留的独立 `pubspec_overrides.yaml`，避免旧配置覆盖根声明。当前兼容性尚未验证。
open_filex 沿用 main 的 hosted 4.7.0；`open_file_ohos 1.0.0` 在根 dependencies 指定 Git 来源。
统一入口为根 `lib/utils/open_file.dart` 的 `openFile(path)`，按平台调用独立 OH 包或官方主包并统一返回类型；
插件检查要求 `open_file_ohos`。两个附件页及打开工具共用根源码，日历的其他 OH 适配继续保留。
此接入尚未完成依赖解析、构建和真机验证。

为避免已有补丁残留在 Pub 缓存中，新流程使用 `ohos/.pub-cache/upstream/`。
此前 `ohos/.pub-cache/` 下的缓存不再参与解析；不会自动删除旧缓存或全局缓存。
首次切换需要重新执行 DevEco Sync，更新解析结果和原生插件注册。

安全存储覆盖文件直接导入 `flutter_secure_storage_ohos` 自带的 `FlutterSecureStorage`，
该接口原生支持 OH options，因此不再修改主包的平台选择或 macOS 参数。
接口继续调用真实的原生加密存储，不使用空实现或普通偏好存储替代。

Hvigor 路径适配仍由清单维护；嵌入层直接使用 SDK 原始 HAR。先前有补丁时的验证记录仅供历史参考，
不能用于认定当前原版插件组合已经通过。文件、图片、分享、凭据、SQLite 和 WebView
需在实际构建后重新验收。

## 验证命令

本次只迁移代码和维护位置，未执行验证。以下命令由用户在根目录执行，SDK 从 PowerShell 环境读取：

```powershell
python -m unittest discover -s ohos/tests/python -p "test_*.py"
python ohos/tool/build_ohos.py --mode release
```

鸿蒙不保存独立锁文件，依赖在每次准备时于 `ohos/.flutter-workspace/` 内重新求解。
测试维护目录及运行位置见 [测试说明](../tests/README.md)。构建脚本将
`ohos/tests/flutter/*.dart.template` 链接为工程的 `test/ohos/*.dart`，遇到与根测试同名的文件即停止。
在已组装源码并完成代码生成的构建副本根目录中，使用同一 Flutter OH SDK 执行：

```powershell
flutter test --no-pub test/ohos/platform_adapters_test.dart test/webview_notice_handlers_test.dart
dart analyze lib
```

测试模拟文件选择和相册通道；它们不替代真机上的保存弹窗、文件内容、下载去重、Cookie
和验证码验证。构建入口只生成 unsigned HAP，发布签名在同步计划最后阶段处理。
