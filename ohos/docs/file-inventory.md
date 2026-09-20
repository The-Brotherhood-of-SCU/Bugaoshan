**鸿蒙独立维护文件清单**

按当前迁移结果统计，`ohos/` 共 **168 个**维护文件，不计本清单文件。每个文件占一行，左列为文件，右列为用途。链接采用仓库相对路径，重新 clone 后仍可使用。

其中，`ohos/flutter/overrides/lib/` 有 **43 个 Dart 文件：28 个覆盖上游，15 个鸿蒙新增**。原先 5 个优先恢复候选和 18 个通用修复覆盖已取消，组装工程直接使用根 `lib/` 的现有上游实现；另有 1 个覆盖（`pages/campus/repair/repair_page.dart`）因与上游字节一致而移除。18 份未合入的修复快照已由维护者剪切出当前仓库，不计入本清单，也不参与构建。

范围不含 `.flutter-workspace/`、`.pub-cache/`、`oh_modules/`、`node_modules/`、构建输出和本机忽略文件。原生测试脚手架及历史补丁迁移输入仍属于受版本控制的维护文件，已逐项列出。用途说明不等于已通过构建或真机验证。

| 类别 | 文件数 |
| --- | ---: |
| 覆盖上游的 Dart 文件 | 28 |
| 鸿蒙新增的 Dart 文件 | 15 |
| 原生功能代码 | 9 |
| 原生工程配置与资源 | 25 |
| Flutter 依赖、翻译与覆盖配置 | 8 |
| 插件、嵌入层与 Hvigor 补丁 | 16 |
| 构建与维护工具 | 12 |
| Flutter 与 Python 测试 | 15 |
| DevEco 原生测试工程 | 10 |
| 文档与维护约定 | 30 |

**覆盖上游的 Dart 文件（28 个）**

原 52 个文件的逐项判断和本次迁移结果见 [上游复用评估](audits/upstream-reuse-assessment.md)。

本组目录：`ohos/flutter/overrides/lib/`。

| 文件 | 用途 |
| --- | --- |
| [app.dart](../flutter/overrides/lib/app.dart) | 应用主题和全局界面装配；使用鸿蒙系统强调色回退。 |
| [injection/injector.dart](../flutter/overrides/lib/injection/injector.dart) | 鸿蒙依赖注入装配；接入课表卡片快照和同步服务。 |
| [main.dart](../flutter/overrides/lib/main.dart) | 鸿蒙启动入口；清理桌面及其他平台启动调用，接入启动错误报告和 Debug 诊断。 |
| [pages/campus/downloads/attachments_sheet.dart](../flutter/overrides/lib/pages/campus/downloads/attachments_sheet.dart) | 通知附件操作面板；对接鸿蒙文件打开、分享及失败提示。 |
| [pages/campus/downloads/notice_downloaded_page.dart](../flutter/overrides/lib/pages/campus/downloads/notice_downloaded_page.dart) | 已下载附件管理；适配本地文件打开、分享和错误反馈。 |
| [pages/campus/service_hall/service_field_widgets.dart](../flutter/overrides/lib/pages/campus/service_hall/service_field_widgets.dart) | 办事大厅表单字段；适配鸿蒙图片选择及失败处理。 |
| [pages/dev/environment_info_page.dart](../flutter/overrides/lib/pages/dev/environment_info_page.dart) | 环境信息页面；展示原生设备信息，支持完整复制和读取重试。 |
| [pages/settings/add_widget/add_widget_page.dart](../flutter/overrides/lib/pages/settings/add_widget/add_widget_page.dart) | 添加桌面卡片页面；提供鸿蒙课表卡片管理入口和说明。 |
| [pages/settings/set_course_style_page.dart](../flutter/overrides/lib/pages/settings/set_course_style_page.dart) | 课表样式设置；适配背景图片操作和鸿蒙强调色。 |
| [pages/settings/set_dock_page.dart](../flutter/overrides/lib/pages/settings/set_dock_page.dart) | Dock 设置；兼容 Flutter OH 3.41 的排序回调。 |
| [pages/settings/set_theme_color_page.dart](../flutter/overrides/lib/pages/settings/set_theme_color_page.dart) | 主题色设置页面；使用鸿蒙强调色回退。 |
| [pages/settings/software_setting_page.dart](../flutter/overrides/lib/pages/settings/software_setting_page.dart) | 软件设置；接入鸿蒙动态图标和课表卡片入口，并检查图标功能所需 API。 |
| [providers/app_config_provider.dart](../flutter/overrides/lib/providers/app_config_provider.dart) | 应用设置加载和持久化；鸿蒙强调色回退、数值偏好宽松读取，避免整数被强转为 double。 |
| [providers/environment_info/native.dart](../flutter/overrides/lib/providers/environment_info/native.dart) | 收集运行环境和目录信息；鸿蒙跳过可能触发断言的 os_type 分类。 |
| [providers/set_theme_color_provider.dart](../flutter/overrides/lib/providers/set_theme_color_provider.dart) | 主题色来源管理；鸿蒙系统强调色回退。 |
| [services/dynamic_icon_service.dart](../flutter/overrides/lib/services/dynamic_icon_service.dart) | 动态图标 Dart 接口；调用鸿蒙原生通道并检查 API 支持。 |
| [services/exit_service.dart](../flutter/overrides/lib/services/exit_service.dart) | 鸿蒙退出服务；隔离桌面窗口插件依赖。 |
| [services/update_asset_selector.dart](../flutter/overrides/lib/services/update_asset_selector.dart) | 更新资源选择逻辑；通过设备信息封装隔离 device_info_plus 依赖，不新增鸿蒙自安装流程。 |
| [services/widget_update_service.dart](../flutter/overrides/lib/services/widget_update_service.dart) | 桌面组件更新服务；接入鸿蒙课表快照和卡片更新通道。 |
| [services/window_state_service.dart](../flutter/overrides/lib/services/window_state_service.dart) | 桌面窗口状态服务的鸿蒙空实现；不恢复窗口、不注册桌面监听器。 |
| [theme.dart](../flutter/overrides/lib/theme.dart) | 应用主题；兼容 Flutter OH 的主题导入和转场接口。 |
| [utils/calendar_export_utils.dart](../flutter/overrides/lib/utils/calendar_export_utils.dart) | 课表日历导出；保存 ICS，并通过鸿蒙通道交给日历应用确认导入。 |
| [utils/open_link.dart](../flutter/overrides/lib/utils/open_link.dart) | 统一外链打开；使用系统接收应用并反馈失败。 |
| [widgets/common/image_viewer.dart](../flutter/overrides/lib/widgets/common/image_viewer.dart) | 图片查看器；接入鸿蒙相册保存接口及结果反馈。 |
| [widgets/eula_content.dart](../flutter/overrides/lib/widgets/eula_content.dart) | 用户协议展示；适配协议内外部链接的打开方式。 |
| [widgets/webview/captcha_webview_dialog.dart](../flutter/overrides/lib/widgets/webview/captcha_webview_dialog.dart) | 网页验证码弹窗；接入鸿蒙 WebView 及兼容接口。 |
| [widgets/webview/webview_notice_handlers.dart](../flutter/overrides/lib/widgets/webview/webview_notice_handlers.dart) | 通知 WebView 回调；兼容 CPF 6.1.5 下载接口及附件处理。 |
| [widgets/webview/webview_notice_page.dart](../flutter/overrides/lib/widgets/webview/webview_notice_page.dart) | 共享通知页面；鸿蒙 WebView、美化、首帧遮罩、主题跟随及加载重试。 |

**鸿蒙新增的 Dart 文件（15 个）**

本组目录：`ohos/flutter/overrides/lib/`。

| 文件 | 用途 |
| --- | --- |
| [services/ohos_course_card_snapshot.dart](../flutter/overrides/lib/services/ohos_course_card_snapshot.dart) | 把当前课表、展示设置和隐私选项转换为原生课表卡片快照。 |
| [services/ohos_course_card_sync.dart](../flutter/overrides/lib/services/ohos_course_card_sync.dart) | 监听前台恢复、课表和设置变化，协调课表卡片同步。 |
| [utils/file_save.dart](../flutter/overrides/lib/utils/file_save.dart) | 封装 CPF 文件选择器的文件保存能力，统一保存、取消和失败结果。 |
| [utils/gallery_save.dart](../flutter/overrides/lib/utils/gallery_save.dart) | 封装鸿蒙图片保存到相册及结果判断。 |
| [utils/image_pick.dart](../flutter/overrides/lib/utils/image_pick.dart) | 封装鸿蒙图片选择，区分取消与失败。 |
| [utils/mobile_device_info.dart](../flutter/overrides/lib/utils/mobile_device_info.dart) | 封装原生设备信息读取，隔离上游设备插件依赖。 |
| [utils/ohos_debug_diagnostics.dart](../flutter/overrides/lib/utils/ohos_debug_diagnostics.dart) | Debug 原始异常与堆栈输出；脱敏、分段并避免错误报告递归。 |
| [utils/ohos_startup_error.dart](../flutter/overrides/lib/utils/ohos_startup_error.dart) | 格式化启动失败原因及原始堆栈，展示前脱敏。 |
| [utils/ohos_system_accent_color.dart](../flutter/overrides/lib/utils/ohos_system_accent_color.dart) | 集中定义鸿蒙系统强调色的回退值。 |
| [utils/open_file.dart](../flutter/overrides/lib/utils/open_file.dart) | 封装系统打开本地文件，统一打开结果和失败处理。 |
| [widgets/webview/download_webview.dart](../flutter/overrides/lib/widgets/webview/download_webview.dart) | 封装鸿蒙 WebView 创建、下载回调、主题跟随、禁用回弹及实例生命周期。 |
| [widgets/webview/notice_layout_ready.dart](../flutter/overrides/lib/widgets/webview/notice_layout_ready.dart) | 判断通知页面美化后的布局是否稳定，控制正文展示时机。 |
| [widgets/webview/notice_webview_scripts.dart](../flutter/overrides/lib/widgets/webview/notice_webview_scripts.dart) | 通知页注入脚本；包括教务处搜索框配色等页面调整。 |
| [widgets/webview/tuanwei_mobile_layout.dart](../flutter/overrides/lib/widgets/webview/tuanwei_mobile_layout.dart) | 青春川大页面移动视口和 CSS 布局适配，限制缩放。 |
| [widgets/webview/tuanwei_notice_loader.dart](../flutter/overrides/lib/widgets/webview/tuanwei_notice_loader.dart) | 青春川大通知加载控制；等待正文与美化完成，处理遮罩及重试。 |

**原生功能代码（9 个）**

本组目录：`ohos/entry/src/main/ets/`。

| 文件 | 用途 |
| --- | --- |
| [entryability/EntryAbility.ets](../entry/src/main/ets/entryability/EntryAbility.ets) | 原生应用入口；注册 Flutter 插件、动态图标、设备信息、课表卡片及 ICS 导入通道。 |
| [pages/Index.ets](../entry/src/main/ets/pages/Index.ets) | 承载 Flutter 页面的 ArkUI 入口。 |
| [platform/DynamicIconChannel.ets](../entry/src/main/ets/platform/DynamicIconChannel.ets) | 通过鸿蒙应用包 API 查询和切换备用图标。 |
| [platform/EnvironmentInfoChannel.ets](../entry/src/main/ets/platform/EnvironmentInfoChannel.ets) | 读取设备品牌、型号、系统版本、API 和 ABI 等公开信息并返回 Dart。 |
| [cards/CourseCard.ets](../entry/src/main/ets/cards/CourseCard.ets) | 桌面课表卡片的 ArkUI 展示及点击打开应用行为。 |
| [cards/CourseCardChannel.ets](../entry/src/main/ets/cards/CourseCardChannel.ets) | 接收 Flutter 课表快照、串行刷新卡片及打开系统卡片管理。 |
| [cards/CourseCardModel.ets](../entry/src/main/ets/cards/CourseCardModel.ets) | 课表卡片纯数据模型；校验快照、计算课程展示和刷新时间。 |
| [cards/CourseCardStore.ets](../entry/src/main/ets/cards/CourseCardStore.ets) | 持久化课表快照和卡片绑定信息，协调原生卡片刷新。 |
| [cards/CourseFormAbility.ets](../entry/src/main/ets/cards/CourseFormAbility.ets) | 课表卡片扩展 Ability；处理卡片创建、更新和销毁生命周期。 |

**原生工程配置与资源**

本组目录：`ohos/`。

| 文件 | 用途 |
| --- | --- |
| [.gitignore](../.gitignore) | 忽略鸿蒙本机配置、缓存、依赖和构建输出。 |
| [AppScope/app.json5](../AppScope/app.json5) | 应用级标识、图标及版本基线；实际构建版本由根 pubspec 注入。 |
| [AppScope/resources/base/element/string.json](../AppScope/resources/base/element/string.json) | 应用级名称等字符串资源。 |
| [AppScope/resources/base/media/app_icon.png](../AppScope/resources/base/media/app_icon.png) | 应用默认图标资源。 |
| [AppScope/resources/base/media/app_icon_old.png](../AppScope/resources/base/media/app_icon_old.png) | 用于动态图标切换的备用旧图标。 |
| [build-profile.json5](../build-profile.json5) | DevEco 工程识别、产品与构建配置；仅列用途，本次未读取本机签名配置内容。 |
| [entry/.gitignore](../entry/.gitignore) | 忽略原生 entry 模块的本地生成文件。 |
| [entry/build-profile.json5](../entry/build-profile.json5) | entry 模块构建选项，包括原生产物符号保留配置。 |
| [entry/hvigorfile.ts](../entry/hvigorfile.ts) | 注册 entry 模块的 HAP 构建任务。 |
| [entry/oh-package.json5](../entry/oh-package.json5) | 声明 entry 模块的鸿蒙依赖。 |
| [entry/src/main/module.json5](../entry/src/main/module.json5) | 声明主模块、应用入口、权限和课表卡片扩展。 |
| [entry/src/main/resources/base/element/color.json](../entry/src/main/resources/base/element/color.json) | 默认模式的原生颜色资源，包括启动背景。 |
| [entry/src/main/resources/base/element/string.json](../entry/src/main/resources/base/element/string.json) | 默认语言的原生页面及卡片文案。 |
| [entry/src/main/resources/base/media/icon.png](../entry/src/main/resources/base/media/icon.png) | entry 模块使用的图标资源。 |
| [entry/src/main/resources/base/profile/course_card.json](../entry/src/main/resources/base/profile/course_card.json) | 课表卡片名称、尺寸、更新和页面配置。 |
| [entry/src/main/resources/base/profile/main_pages.json](../entry/src/main/resources/base/profile/main_pages.json) | 原生主页面路由列表。 |
| [entry/src/main/resources/dark/element/color.json](../entry/src/main/resources/dark/element/color.json) | 深色模式的原生颜色资源，包括启动背景。 |
| [entry/src/main/resources/en_US/element/string.json](../entry/src/main/resources/en_US/element/string.json) | 原生界面和课表卡片英文文案。 |
| [entry/src/main/resources/rawfile/buildinfo.json5](../entry/src/main/resources/rawfile/buildinfo.json5) | Flutter 嵌入层运行配置；当前启用 Impeller。 |
| [entry/src/main/resources/rawfile/framesconfig.json](../entry/src/main/resources/rawfile/framesconfig.json) | 按动画类型和速度区间配置偏好帧率。 |
| [entry/src/main/resources/zh_CN/element/string.json](../entry/src/main/resources/zh_CN/element/string.json) | 原生界面和课表卡片简体中文文案。 |
| [hvigor/hvigor-config.json5](../hvigor/hvigor-config.json5) | Hvigor 工具依赖及执行配置。 |
| [hvigorconfig.ts](../hvigorconfig.ts) | DevEco 配置阶段入口；自举 Flutter 工作目录并注入已解析插件模块。 |
| [hvigorfile.ts](../hvigorfile.ts) | 应用级构建任务；接入 Flutter 编译适配和嵌入层 HAR 补丁。 |
| [oh-package.json5](../oh-package.json5) | 鸿蒙根工程的 OHPM 包声明和依赖配置。 |

**Flutter 依赖、翻译与覆盖配置**

本组目录：`ohos/flutter/`。

| 文件 | 用途 |
| --- | --- |
| [l10n/app_en.arb](../flutter/l10n/app_en.arb) | 鸿蒙新增或覆盖的英文翻译条目，组装时与上游按键合并。 |
| [l10n/app_zh.arb](../flutter/l10n/app_zh.arb) | 鸿蒙新增或覆盖的中文翻译条目，组装时与上游按键合并。 |
| [overrides/analysis_options.yaml](../flutter/overrides/analysis_options.yaml) | 避免根 SDK 单独分析不完整的覆盖目录；不替代最终组装工程的分析规则。 |
| [pubspec.lock](../flutter/pubspec.lock) | 鸿蒙独立的 Dart 依赖锁文件。 |
| [pubspec_dependencies.json](../flutter/pubspec_dependencies.json) | 声明鸿蒙新增依赖和需要排除的上游平台依赖。 |
| [pubspec_overrides.yaml](../flutter/pubspec_overrides.yaml) | 固定鸿蒙适用的主包、平台接口及实现版本和 Git 提交。 |
| [source-manifest.json](../flutter/source-manifest.json) | 登记全部 Dart 覆盖／新增文件和翻译差异，并检查上游基线哈希。 |
| [toolchain.lock.json](../flutter/toolchain.lock.json) | 锁定 Flutter OH、Dart、HarmonyOS 和构建工具版本，以及 OH 平台缓存哈希。 |

**插件、嵌入层与 Hvigor 补丁**

本组目录：`ohos/flutter/patches/`。

| 文件 | 用途 |
| --- | --- |
| [embedding/color-mode-update.patch](../flutter/patches/embedding/color-mode-update.patch) | 修复系统主题配置更新传递，避免主题变化时重建嵌入层节点。 |
| [embedding/manifest.json](../flutter/patches/embedding/manifest.json) | 锁定嵌入层 HAR 补丁的版本、源文件哈希和应用范围。 |
| [hvigor/manifest.json](../flutter/patches/hvigor/manifest.json) | 登记 SDK Hvigor 适配输入及哈希，保证路径适配基于匹配版本。 |
| [plugins/file-picker-save-bytes.patch](../flutter/patches/plugins/file-picker-save-bytes.patch) | 按本次传入的文件名和 bytes 保存文件，处理取消、部分写入和句柄关闭。 |
| [plugins/gallery-save-result.patch](../flutter/patches/plugins/gallery-save-result.patch) | 保证相册保存成功或失败都返回结果，并恢复保存状态。 |
| [plugins/image-picker-result.patch](../flutter/patches/plugins/image-picker-result.patch) | 修复选图取消、失败分类及平台结果回传。 |
| [plugins/legacy/secure-storage-results-untyped-throw.patch](../flutter/patches/plugins/legacy/secure-storage-results-untyped-throw.patch) | 识别旧版安全存储补丁缓存状态，供迁移使用；不是新构建的目标补丁。 |
| [plugins/manifest.json](../flutter/patches/plugins/manifest.json) | 声明原生插件补丁对应的包版本、Git 提交、应用顺序及旧补丁升级关系。 |
| [plugins/open-file-result.patch](../flutter/patches/plugins/open-file-result.patch) | 修复调用系统打开文件后的结果及错误回传。 |
| [plugins/secure-storage-error-types.patch](../flutter/patches/plugins/secure-storage-error-types.patch) | 将旧补丁中的无类型抛出改为明确 Error，满足 ArkTS 限制。 |
| [plugins/secure-storage-results.patch](../flutter/patches/plugins/secure-storage-results.patch) | 修复安全存储操作的错误回传和并发处理，包含当前异常类型修复。 |
| [plugins/secure-storage.json](../flutter/patches/plugins/secure-storage.json) | 安全存储主包的 options 回退和 macOS 参数兼容规则。 |
| [plugins/share-files-result.patch](../flutter/patches/plugins/share-files-result.patch) | 修复分享文件准备及成功／失败结果回传。 |
| [plugins/sqflite-main-thread-channel.patch](../flutter/patches/plugins/sqflite-main-thread-channel.patch) | 将数据库插件通道从自管理 Worker 恢复到主线程，避免 Worker 加载 UI 模块；不代表单独修复 Native 崩溃。 |
| [plugins/url-launcher-ability-kit.patch](../flutter/patches/plugins/url-launcher-ability-kit.patch) | 把 Want 等旧模块导入迁移到 API 26 的 AbilityKit。 |
| [plugins/webview-configuration-update.patch](../flutter/patches/plugins/webview-configuration-update.patch) | 把系统主题配置更新传给现有 WebView 节点，配合嵌入层补丁。 |

**构建与维护工具**

本组目录：`ohos/tool/`。

| 文件 | 用途 |
| --- | --- |
| [build_ohos.py](../tool/build_ohos.py) | 总构建入口；工具链校验、工作目录组装、依赖解析、补丁接入和 HAP 构建／版本核对。 |
| [flutter_bootstrap.ts](../tool/flutter_bootstrap.ts) | DevEco Sync 自举；发现 Python、准备工作目录和注入鸿蒙插件模块。 |
| [flutter_embedding_plugin.ts](../tool/flutter_embedding_plugin.ts) | Hvigor 插件；按模式和架构选择 HAR 后应用嵌入层补丁。 |
| [flutter_project.ts](../tool/flutter_project.ts) | Hvigor 与 Python 工具桥接；加载运行配置并使用本地 SDK 构建适配层。 |
| [generate_ohos_dependency_inventory.py](../tool/generate_ohos_dependency_inventory.py) | 对比根依赖锁与鸿蒙锁，生成依赖清单文档。 |
| [ohos_embedding.py](../tool/ohos_embedding.py) | 校验并修补嵌入层 HAR，在工作目录生成适配产物。 |
| [ohos_links.py](../tool/ohos_links.py) | 建立及维护逐文件源码链接、构建锁和代码生成隔离检查。 |
| [ohos_native.py](../tool/ohos_native.py) | 原生工程与 Flutter 工作目录衔接；生成代码、注册插件、注入版本、增量编译及 AOT 符号配置。 |
| [ohos_patches.py](../tool/ohos_patches.py) | 按清单校验和应用插件补丁，处理已应用状态及旧缓存升级。 |
| [ohos_sources.py](../tool/ohos_sources.py) | 检查覆盖文件及翻译条目的上游基线，规划覆盖和合并翻译。 |
| [ohos_toolchain.py](../tool/ohos_toolchain.py) | 校验锁定 OH 产物提交及两份平台缓存哈希，拒绝不匹配 SDK 缓存。 |
| [plugin_registrant.dart.template](../tool/plugin_registrant.dart.template) | 在鸿蒙依赖环境读取插件声明，供原生插件注册代码生成使用。 |

**Flutter 与 Python 测试**

本组目录：`ohos/tests/`。

| 文件 | 用途 |
| --- | --- |
| [flutter/app_config_numeric_preferences_test.dart.template](../tests/flutter/app_config_numeric_preferences_test.dart.template) | 验证整型、浮点、字符串及非法偏好值的读取和冷启动保存兼容。 |
| [flutter/course_copy_mode_test.dart.template](../tests/flutter/course_copy_mode_test.dart.template) | 使用内存假数据库验证课程副本页面、冲突拦截和新增保存。 |
| [flutter/course_duplicate_test.dart.template](../tests/flutter/course_duplicate_test.dart.template) | 验证课程复制生成新 ID、保留字段且不覆盖源课程。 |
| [flutter/home_page_loading_test.dart.template](../tests/flutter/home_page_loading_test.dart.template) | 验证首页按需加载、页面状态保留及账号隔离。 |
| [flutter/ohos_debug_diagnostics_test.dart.template](../tests/flutter/ohos_debug_diagnostics_test.dart.template) | 验证原始堆栈输出、分段脱敏以及日志故障不递归。 |
| [flutter/ohos_startup_error_test.dart.template](../tests/flutter/ohos_startup_error_test.dart.template) | 验证启动报告包含异常原因和原始栈，并正确脱敏。 |
| [flutter/platform_adapters_test.dart.template](../tests/flutter/platform_adapters_test.dart.template) | 模拟平台通道，验证文件保存、相册保存等适配结果。 |
| [flutter/support/memory_course_database.dart.template](../tests/flutter/support/memory_course_database.dart.template) | 为 OH 课程测试提供不调用原生插件的内存数据库替身。 |
| [flutter/theme_page_transitions_test.dart.template](../tests/flutter/theme_page_transitions_test.dart.template) | 验证 OH 原生转场构建器及自定义进出时长。 |
| [python/test_build_ohos.py](../tests/python/test_build_ohos.py) | 验证构建入口、版本与依赖配置、工作目录组装等逻辑。 |
| [python/test_ohos_links.py](../tests/python/test_ohos_links.py) | 验证源码链接维护、路径边界及生成文件隔离。 |
| [python/test_ohos_native.py](../tests/python/test_ohos_native.py) | 验证原生入口准备、增量复用、插件注册及构建参数处理。 |
| [python/test_ohos_patches.py](../tests/python/test_ohos_patches.py) | 验证插件补丁校验、重复应用及缓存升级。 |
| [python/test_ohos_sources.py](../tests/python/test_ohos_sources.py) | 验证源码基线、翻译合并、未登记文件和越界拒绝。 |
| [python/test_ohos_toolchain.py](../tests/python/test_ohos_toolchain.py) | 验证 OH 工具链产物及平台缓存一致性检查。 |

**DevEco 原生测试工程**

本组目录：`ohos/entry/src/ohosTest/`。

| 文件 | 用途 |
| --- | --- |
| [ets/test/Ability.test.ets](../entry/src/ohosTest/ets/test/Ability.test.ets) | Hypium 示例断言用例；目前是测试脚手架，不是业务功能验证。 |
| [ets/test/List.test.ets](../entry/src/ohosTest/ets/test/List.test.ets) | 原生测试套件汇总入口。 |
| [ets/testability/TestAbility.ets](../entry/src/ohosTest/ets/testability/TestAbility.ets) | 启动 Hypium 测试套件并承载测试窗口。 |
| [ets/testability/pages/Index.ets](../entry/src/ohosTest/ets/testability/pages/Index.ets) | 测试 Ability 的示例页面。 |
| [ets/testrunner/OpenHarmonyTestRunner.ts](../entry/src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ts) | 设备侧测试运行器；注册 Ability 监听并启动测试入口。 |
| [module.json5](../entry/src/ohosTest/module.json5) | 声明原生测试模块及 TestAbility。 |
| [resources/base/element/color.json](../entry/src/ohosTest/resources/base/element/color.json) | 测试模块颜色资源。 |
| [resources/base/element/string.json](../entry/src/ohosTest/resources/base/element/string.json) | 测试模块字符串资源。 |
| [resources/base/media/icon.png](../entry/src/ohosTest/resources/base/media/icon.png) | 测试模块图标。 |
| [resources/base/profile/test_pages.json](../entry/src/ohosTest/resources/base/profile/test_pages.json) | 测试模块页面路由列表。 |

**文档与维护约定**

本组目录：`ohos/`。

| 文件 | 用途 |
| --- | --- |
| [AGENTS.md](../AGENTS.md) | 鸿蒙维护约定；目录边界、源码覆盖方式及构建测试分工。 |
| [README.md](../README.md) | 鸿蒙开发总入口，介绍工具链、DevEco 操作及源码同步流程。 |
| [docs/audits/api20-debug-white-screen.md](audits/api20-debug-white-screen.md) | API 20 Debug 白屏的日志分析、环境限制和排查记录。 |
| [docs/audits/notice-webview.md](audits/notice-webview.md) | 通知 WebView 的适配审计与行为检查记录。 |
| [docs/audits/phase3-code.md](audits/phase3-code.md) | 第三阶段文件、认证、上传等代码审计记录。 |
| [docs/audits/release-aot-cache-repair.md](audits/release-aot-cache-repair.md) | Release AOT 崩溃与 SDK 平台缓存不一致的修复步骤。 |
| [docs/audits/source-overlay-migration.json](audits/source-overlay-migration.json) | 旧源码补丁到完整 Dart 覆盖文件的机器可读迁移记录。 |
| [docs/audits/source-overlay-migration.md](audits/source-overlay-migration.md) | 完整文件覆盖迁移说明及旧补丁编号对应关系；其中数量为历史快照。 |
| [docs/audits/startup-preferences-type-mismatch.md](audits/startup-preferences-type-mismatch.md) | 鸿蒙偏好整数值导致 double 类型异常的分析和修复记录。 |
| [docs/audits/startup.md](audits/startup.md) | 启动调用与初始化流程的审计记录。 |
| [docs/audits/upstream-reuse-assessment.md](audits/upstream-reuse-assessment.md) | 52 个历史 Dart 覆盖的上游复用评估及迁移结果。 |
| [docs/commit-plan.md](commit-plan.md) | 鸿蒙适配的提交整理计划与范围说明。 |
| [docs/compatibility/api20.md](compatibility/api20.md) | 最低 API 20 与高版本 API 功能的兼容性说明。 |
| [docs/dependencies/lock-inventory.md](dependencies/lock-inventory.md) | 根依赖锁和鸿蒙依赖锁的详细对比清单。 |
| [docs/dependencies/overview.md](dependencies/overview.md) | 鸿蒙依赖策略、来源及维护方式说明。 |
| [docs/dependencies/replacements.md](dependencies/replacements.md) | 上游插件与鸿蒙替代实现的对应关系。 |
| [docs/flutter-adaptation.md](flutter-adaptation.md) | Dart 覆盖、源码组装、依赖和插件补丁机制说明。 |
| [docs/phases/phase3.md](phases/phase3.md) | 第三阶段平台能力、认证和异常路径的实现及验收说明。 |
| [docs/phases/phase4.md](phases/phase4.md) | 第四阶段通知 WebView 布局、主题和加载行为说明。 |
| [docs/phases/phase5.md](phases/phase5.md) | 第五阶段动态图标、桌面卡片和环境信息说明。 |
| [docs/sync-plan.md](sync-plan.md) | 整体同步计划、各阶段状态及待验证项目。 |
| [flutter/README.md](../flutter/README.md) | 鸿蒙 Flutter 配置目录入口。 |
| [flutter/l10n/README.md](../flutter/l10n/README.md) | 鸿蒙翻译差异的维护与合并规则。 |
| [flutter/overrides/README.md](../flutter/overrides/README.md) | 完整 Dart 覆盖的维护、基线更新和分析规则。 |
| [flutter/patches/embedding/README.md](../flutter/patches/embedding/README.md) | Flutter OH HAR 补丁的目的、生成与验证方式。 |
| [flutter/patches/framework/README.md](../flutter/patches/framework/README.md) | 已移除 framework 诊断补丁的历史记录，当前不参与补丁应用。 |
| [flutter/patches/hvigor/README.md](../flutter/patches/hvigor/README.md) | SDK Hvigor 路径适配、哈希校验及本地产物说明。 |
| [flutter/patches/plugins/README.md](../flutter/patches/plugins/README.md) | 插件补丁、版本约束和旧缓存迁移说明。 |
| [tests/README.md](../tests/README.md) | Python、Flutter 模板及原生测试的运行位置与范围。 |
| [tool/README.md](../tool/README.md) | 构建工具参数、文件归属、DevEco 接入和故障排查说明。 |
