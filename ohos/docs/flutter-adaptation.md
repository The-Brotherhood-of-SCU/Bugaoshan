# 鸿蒙 Flutter 适配

根工程维护共享业务、上游依赖和上游锁文件。构建入口先检查对应上游源码基线，
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
| `ohos/flutter/pubspec_overrides.yaml` | 固定 CPF 主包及平台接口/实现的 Git 提交 |
| `ohos/flutter/pubspec.lock` | 鸿蒙稳定 SDK 对应的独立依赖锁 |
| `ohos/flutter/patches/plugins/` | 插件补丁、版本清单和安全存储兼容处理 |
| `ohos/flutter/patches/framework/` | 已移除的 Flutter framework 诊断补丁记录 |
| `ohos/flutter/patches/embedding/` | Flutter OH HAR 主题配置补丁、包版本与源码哈希 |
| `ohos/tests/` | 源码组装与插件脚本测试、OH Flutter 测试模板 |

## Dart 文件覆盖

[覆盖目录](../flutter/overrides/README.md) 只保存有鸿蒙适配的完整文件，目前 43 个：
28 个替换上游文件、15 个鸿蒙新增文件。它们通过同一个包名和最终 `lib/` 与共用文件一起编译。
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

## 插件补丁

`webview-configuration-update.patch` 将系统主题配置更新传给现有的 WebBuilderNode，
与 [Flutter 嵌入层补丁](../flutter/patches/embedding/README.md) 配合，移除主题变化导致的原生节点重建。
嵌入层 HAR 由 Hvigor 在副本中准备，不写入 SDK；这一补丁不属于 Pub 缓存补丁。

`file-picker-save-bytes.patch` 让保存操作直接使用本次传入的 bytes 和文件名，
不依赖此前选择文件产生的缓存；处理空内容、部分写入、取消和文件句柄关闭。

`gallery-save-result.patch` 保证重复调用和异常都返回 Flutter 结果，且在 finally 中恢复
保存状态，避免出错后后续保存永久等待。

第三阶段新增 `open-file-result.patch`、`share-files-result.patch`、`image-picker-result.patch`，
修复系统打开结果、分享文件准备及错误回复、选图取消和失败分类。
配套 Dart 实现已迁入覆盖目录（原 `0005` 至 `0007`），行为和权限依据见 [第三阶段代码说明](phases/phase3.md)。
原 `0008` 至 `0012` 的最终实现补齐登录恢复、账号切换、表单和上传的异常路径；
`secure-storage-results.patch` 修复 OH 安全存储的错误回传和并发操作。
旧数据处理与逐项审查结果见 [代码审查记录](audits/phase3-code.md)。

`secure-storage.json` 保留 EasyNode 同类接入方式：OH 固定正式版 9.2.4，解析后为
`_selectOptions()` 增加空 options 回退，并补上根源码使用的 macOS 参数别名。
它校验包版本和待替换原文；根依赖继续使用 10.x。

上述插件补丁只应用到 `ohos/.pub-cache/` 专用缓存。每次先校验包版本、提交及补丁上下文；
完整应用过的补丁允许重入，遇到源码漂移立即失败。不要直接修改全局 Pub 缓存作为维护方式。
安全存储补丁现将六处捕获后重新抛出的异常转换为明确的 `Error`，满足 ArkTS 的 `arkts-limited-throw` 限制。
已应用旧版的缓存通过清单中的 `previousPatch` 识别，再应用 `upgradePatch`；下一次运行构建入口时自动处理。
`legacy/secure-storage-results-untyped-throw.patch` 仅用于识别旧状态，不作为新构建的应用目标。
`secure-storage-error-types.patch` 仅用于将该旧状态升级到当前完整补丁，避免清空缓存或覆盖其他修改。
升级插件时必须重新审查补丁，更新锁文件并重跑测试和无签名构建。

## 验证命令

本次只迁移代码和维护位置，未执行验证。以下命令由用户在根目录执行，SDK 从 PowerShell 环境读取：

```powershell
python -m unittest discover -s ohos/tests/python -p "test_*.py"
python ohos/tool/build_ohos.py --mode release
python ohos/tool/generate_ohos_dependency_inventory.py
```

只有依赖有意变更时才执行 `python ohos/tool/build_ohos.py --update-lockfile`。
测试维护目录及运行位置见 [测试说明](../tests/README.md)。构建脚本将
`ohos/tests/flutter/*.dart.template` 链接为工程的 `test/ohos/*.dart`，遇到与根测试同名的文件即停止。
在已组装源码并完成代码生成的构建副本根目录中，使用同一 Flutter OH SDK 执行：

```powershell
flutter test --no-pub test/ohos/platform_adapters_test.dart test/webview_notice_handlers_test.dart
dart analyze lib
```

测试模拟文件选择和相册通道；它们不替代真机上的保存弹窗、文件内容、下载去重、Cookie
和验证码验证。构建入口只生成 unsigned HAP，发布签名在同步计划最后阶段处理。
