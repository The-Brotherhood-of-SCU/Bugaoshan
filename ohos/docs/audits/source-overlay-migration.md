# 源码补丁迁移为 Dart 覆盖文件

2026-09-16，按用户要求将源码适配从顺序补丁迁移为完整 Dart 文件覆盖。持久修改仍限定在 `ohos/`。

## 当前维护入口

- [Dart 文件](../../flutter/overrides/README.md)：43 个，其中 28 个替换上游文件、15 个仅鸿蒙新增。
  数量变迁：迁移时 65 个 → 提交 `0fd213a` 补齐两个启动诊断文件后 67 个 →
  提交 `f7e0933`（2026-09-19）精简 23 个后 44 个 →
  移除已与上游字节一致的 `lib/pages/campus/repair/repair_page.dart` 后为当前 43 个。
- [源码清单](../../flutter/source-manifest.json)：记录逐文件上游 SHA-256，新增文件记录 `null`。
- [翻译条目](../../flutter/l10n/README.md)：每种语言 8 项，7 项新增、1 项替换；保留上游其他条目。
- [源码组装脚本](../../tool/ohos_sources.py)：只读基线检查及翻译合并，运行时不再应用源码补丁。
  后续通过 [链接工程脚本](../../tool/ohos_links.py) 直接引用共用及覆盖文件，替代整份源码复制。

迁移包含此前尚未提交的首页按需加载、开屏深色资源与启动调用清理；原生资源继续留在原位置。
源码文件来自本次根源码依次应用全部 26 个补丁后的结果，未从 DevEco 历史副本反向复制，
也未重新设计业务实现。为提取最终文件，本次仅在临时目录展开了一次旧补丁，随后删除临时目录。
未运行 Flutter、Pub、代码生成、格式化、分析、测试或 HAP 构建。新组装流程及真机验收待用户执行。

## 可追溯信息

- 迁移时仓库提交：`3b603e11d976e8495f1e9ad77e9d2a3297386451`。
- 原补丁清单记录的上游基线：`e5c38070e154ab1a62b701534055e03ab9c8861f`。
- [机器可读迁移记录](source-overlay-migration.json) 保存 26 个旧补丁的摘要、目标路径和最终文件摘要。
- Dart 摘要按 LF 字节计算，保留 BOM；ARB 记录的是原补丁链结果，迁移后按 JSON 键值比较等价性。
- 旧源码补丁及其清单已从当前维护目录移除；已提交版本可从 Git 历史查询。以下编号只用于定位历史工作。

## 后续维护

直接编辑覆盖目录中的 `.dart` 文件，在链接工程中验证。修改上游源码时，先将对应变化合并到覆盖文件，
再更新清单对应哈希；未覆盖文件继续跟随上游。插件和 Flutter 嵌入层补丁保持原工作方式。
`overrides/analysis_options.yaml` 仅排除维护目录，最终副本仍使用根工程的分析规则。
本记录不重置第三至五阶段的历史通过项，也不代表迁移后构建已经通过。

## 旧编号与当前文件

下表是迁移时（2026-09-16）的对应关系：编号为旧源码补丁，文件为当时转换出的覆盖。
其后部分文件已随上游合并取消覆盖（见上文「当前维护入口」的当前数量），
本表保留迁移时的快照，不代表当前活动覆盖集合。

### 0001

Flutter OH 3.41 排序回调和主题 import 兼容。

- [lib/pages/settings/set_dock_page.dart](../../flutter/overrides/lib/pages/settings/set_dock_page.dart)
- [lib/theme.dart](../../flutter/overrides/lib/theme.dart)

### 0002

隔离 OH 不使用的设备信息和桌面插件。

- [lib/pages/dev/environment_info_page.dart](../../flutter/overrides/lib/pages/dev/environment_info_page.dart)
- [lib/services/update_asset_selector.dart](../../flutter/overrides/lib/services/update_asset_selector.dart)
- [lib/services/exit_service.dart](../../flutter/overrides/lib/services/exit_service.dart)
- [lib/services/window_state_service.dart](../../flutter/overrides/lib/services/window_state_service.dart)
- [lib/utils/mobile_device_info.dart](../../flutter/overrides/lib/utils/mobile_device_info.dart)

### 0003

文件导出和相册保存使用 CPF 稳定实现。

- [lib/utils/calendar_export_utils.dart](../../flutter/overrides/lib/utils/calendar_export_utils.dart)
- [lib/widgets/common/image_viewer.dart](../../flutter/overrides/lib/widgets/common/image_viewer.dart)
- [lib/utils/file_save.dart](../../flutter/overrides/lib/utils/file_save.dart)
- [lib/utils/gallery_save.dart](../../flutter/overrides/lib/utils/gallery_save.dart)

### 0004

OH WebView 入口和 CPF 6.1.5 下载回调。

- [lib/widgets/webview/captcha_webview_dialog.dart](../../flutter/overrides/lib/widgets/webview/captcha_webview_dialog.dart)
- [lib/widgets/webview/webview_notice_handlers.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_handlers.dart)
- [lib/widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)
- [lib/widgets/webview/download_webview.dart](../../flutter/overrides/lib/widgets/webview/download_webview.dart)

### 0005

第三阶段：外链统一交给系统应用并处理打开失败。

- [lib/utils/open_link.dart](../../flutter/overrides/lib/utils/open_link.dart)
- [lib/pages/about/about_page.dart](../../flutter/overrides/lib/pages/about/about_page.dart)
- [lib/pages/about/team_page.dart](../../flutter/overrides/lib/pages/about/team_page.dart)
- [lib/pages/profile/profile_menu_card.dart](../../flutter/overrides/lib/pages/profile/profile_menu_card.dart)
- [lib/widgets/eula_content.dart](../../flutter/overrides/lib/widgets/eula_content.dart)

### 0006

第三阶段：选图、附件打开、分享及背景保存失败处理。

- [lib/utils/image_pick.dart](../../flutter/overrides/lib/utils/image_pick.dart)
- [lib/utils/open_file.dart](../../flutter/overrides/lib/utils/open_file.dart)
- [lib/pages/campus/repair/repair_page.dart](../../flutter/overrides/lib/pages/campus/repair/repair_page.dart)
- [lib/pages/campus/service_hall/service_field_widgets.dart](../../flutter/overrides/lib/pages/campus/service_hall/service_field_widgets.dart)
- [lib/pages/settings/set_course_style_page.dart](../../flutter/overrides/lib/pages/settings/set_course_style_page.dart)
- [lib/pages/campus/repair/repair_submit_tab.dart](../../flutter/overrides/lib/pages/campus/repair/repair_submit_tab.dart)
- [lib/pages/campus/downloads/attachments_sheet.dart](../../flutter/overrides/lib/pages/campus/downloads/attachments_sheet.dart)
- [lib/pages/campus/downloads/notice_downloaded_page.dart](../../flutter/overrides/lib/pages/campus/downloads/notice_downloaded_page.dart)
- [lib/utils/share_utils.dart](../../flutter/overrides/lib/utils/share_utils.dart)
- [lib/pages/dev/auth_log/auth_log_viewer_page.dart](../../flutter/overrides/lib/pages/dev/auth_log/auth_log_viewer_page.dart)

### 0007

第三阶段：启用鸿蒙日历入口并调用现有 ICS 原生通道。

- [lib/utils/calendar_export_utils.dart](../../flutter/overrides/lib/utils/calendar_export_utils.dart)

### 0008

第三阶段：Passpoint 操作互斥、失败结果与响应结构处理。

- [lib/providers/passpoint_provider.dart](../../flutter/overrides/lib/providers/passpoint_provider.dart)
- [lib/services/api/new_service_api_service.dart](../../flutter/overrides/lib/services/api/new_service_api_service.dart)

### 0009

第三阶段：旧凭据恢复、登录持久化及退出和续期的并发保护。

- [lib/services/auth/scu_auth.dart](../../flutter/overrides/lib/services/auth/scu_auth.dart)
- [lib/providers/scu_auth_provider.dart](../../flutter/overrides/lib/providers/scu_auth_provider.dart)
- [lib/pages/auth/scu_login_page.dart](../../flutter/overrides/lib/pages/auth/scu_login_page.dart)

### 0010

第三阶段：SSO 和业务重试绑定当前会话，报修 token 绑定账号。

- [lib/services/auth/sso_relay_auth.dart](../../flutter/overrides/lib/services/auth/sso_relay_auth.dart)
- [lib/services/api/api_request.dart](../../flutter/overrides/lib/services/api/api_request.dart)
- [lib/services/api/service_api_service.dart](../../flutter/overrides/lib/services/api/service_api_service.dart)
- [lib/services/api/new_service_api_service.dart](../../flutter/overrides/lib/services/api/new_service_api_service.dart)
- [lib/services/auth/zhhq_auth.dart](../../flutter/overrides/lib/services/auth/zhhq_auth.dart)
- [lib/services/api/zhhq_api_service.dart](../../flutter/overrides/lib/services/api/zhhq_api_service.dart)
- [lib/services/auth/ccyl_auth.dart](../../flutter/overrides/lib/services/auth/ccyl_auth.dart)

### 0011

第三阶段：表单上传快照、账号切换清理及裁剪保存检查。

- [lib/pages/campus/service_hall/service_form_page.dart](../../flutter/overrides/lib/pages/campus/service_hall/service_form_page.dart)
- [lib/pages/campus/repair/repair_page.dart](../../flutter/overrides/lib/pages/campus/repair/repair_page.dart)
- [lib/pages/campus/repair/repair_submit_tab.dart](../../flutter/overrides/lib/pages/campus/repair/repair_submit_tab.dart)
- [lib/pages/campus/repair/repair_widgets.dart](../../flutter/overrides/lib/pages/campus/repair/repair_widgets.dart)
- [lib/pages/settings/background_crop_editor_page.dart](../../flutter/overrides/lib/pages/settings/background_crop_editor_page.dart)

### 0012

第三阶段：上传空文件、响应状态和响应体超时处理。

- [lib/services/api/service_api_service.dart](../../flutter/overrides/lib/services/api/service_api_service.dart)
- [lib/services/api/zhhq_api_service.dart](../../flutter/overrides/lib/services/api/zhhq_api_service.dart)

### 0013

第四阶段：青春川大移动布局和禁用缩放；首帧遮挡、等待正文、确认美化后显示及失败重试。

- [lib/widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)
- [lib/widgets/webview/tuanwei_mobile_layout.dart](../../flutter/overrides/lib/widgets/webview/tuanwei_mobile_layout.dart)
- [lib/widgets/webview/tuanwei_notice_loader.dart](../../flutter/overrides/lib/widgets/webview/tuanwei_notice_loader.dart)

### 0014

第四阶段：三个通知页 ForceDark.AUTO 跟随系统；鸿蒙共用 WebView 全局禁用边缘回弹。

- [lib/widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)
- [lib/widgets/webview/download_webview.dart](../../flutter/overrides/lib/widgets/webview/download_webview.dart)

### 0015

第四阶段：教务处搜索框动态配色、青春川大空消息离页确认、保留 WebView 实例及主题切换诊断。

- [lib/widgets/webview/download_webview.dart](../../flutter/overrides/lib/widgets/webview/download_webview.dart)
- [lib/widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)
- [lib/widgets/webview/notice_webview_scripts.dart](../../flutter/overrides/lib/widgets/webview/notice_webview_scripts.dart)

### 0016

第四阶段：三个通知页首帧遮罩、文档开始隐藏及美化和布局稳定后展示。

- [lib/widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)
- [lib/widgets/webview/download_webview.dart](../../flutter/overrides/lib/widgets/webview/download_webview.dart)
- [lib/widgets/webview/tuanwei_notice_loader.dart](../../flutter/overrides/lib/widgets/webview/tuanwei_notice_loader.dart)
- [lib/widgets/webview/tuanwei_mobile_layout.dart](../../flutter/overrides/lib/widgets/webview/tuanwei_mobile_layout.dart)
- [lib/widgets/webview/notice_layout_ready.dart](../../flutter/overrides/lib/widgets/webview/notice_layout_ready.dart)

### 0017

第四阶段：历史主题刷新实现；后续 0018 移除自动刷新，保留手动重试的遮罩时序。

- [lib/widgets/webview/download_webview.dart](../../flutter/overrides/lib/widgets/webview/download_webview.dart)
- [lib/widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)
- [lib/widgets/webview/tuanwei_notice_loader.dart](../../flutter/overrides/lib/widgets/webview/tuanwei_notice_loader.dart)

### 0018

第四阶段：ArkWeb AUTO 原生跟随系统主题，保留上游深浅 CSS；移除主题刷新和通知页切换探测。

- [lib/widgets/webview/download_webview.dart](../../flutter/overrides/lib/widgets/webview/download_webview.dart)
- [lib/widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart)

### 0019

第五阶段：启用鸿蒙官方备用图标通道及现有设置入口。

- [lib/services/dynamic_icon_service.dart](../../flutter/overrides/lib/services/dynamic_icon_service.dart)
- [lib/pages/settings/software_setting_page.dart](../../flutter/overrides/lib/pages/settings/software_setting_page.dart)

### 0020

第五阶段：当前课表展示快照、启动及前台同步、安卓对齐服务卡片和系统管理入口。

- [lib/services/ohos_course_card_snapshot.dart](../../flutter/overrides/lib/services/ohos_course_card_snapshot.dart)
- [lib/services/ohos_course_card_sync.dart](../../flutter/overrides/lib/services/ohos_course_card_sync.dart)
- [lib/services/widget_update_service.dart](../../flutter/overrides/lib/services/widget_update_service.dart)
- [lib/injection/injector.dart](../../flutter/overrides/lib/injection/injector.dart)
- [lib/pages/settings/software_setting_page.dart](../../flutter/overrides/lib/pages/settings/software_setting_page.dart)
- [lib/pages/settings/add_widget/add_widget_page.dart](../../flutter/overrides/lib/pages/settings/add_widget/add_widget_page.dart)
- [lib/l10n/app_en.arb](../../flutter/l10n/app_en.arb)
- [lib/l10n/app_zh.arb](../../flutter/l10n/app_zh.arb)

### 0021

第五阶段：鸿蒙原生设备信息、设备类型、开发者页完整复制及读取失败重试。

- [lib/utils/mobile_device_info.dart](../../flutter/overrides/lib/utils/mobile_device_info.dart)
- [lib/pages/dev/environment_info_page.dart](../../flutter/overrides/lib/pages/dev/environment_info_page.dart)
- [lib/providers/environment_info/native.dart](../../flutter/overrides/lib/providers/environment_info/native.dart)
- [lib/l10n/app_en.arb](../../flutter/l10n/app_en.arb)
- [lib/l10n/app_zh.arb](../../flutter/l10n/app_zh.arb)

### 0022

第五阶段：鸿蒙图标切换确认文案移除应用重启提示。

- [lib/l10n/app_en.arb](../../flutter/l10n/app_en.arb)
- [lib/l10n/app_zh.arb](../../flutter/l10n/app_zh.arb)

### 0023

鸿蒙开发者页移除 UI Preview 入口及对应分隔线。

- [lib/pages/dev/dev_page.dart](../../flutter/overrides/lib/pages/dev/dev_page.dart)

### 0024

点击应用图标入口时检查运行 API；低于 26 提示鸿蒙 7 以下不支持该功能。

- [lib/services/dynamic_icon_service.dart](../../flutter/overrides/lib/services/dynamic_icon_service.dart)
- [lib/pages/settings/software_setting_page.dart](../../flutter/overrides/lib/pages/settings/software_setting_page.dart)
- [lib/l10n/app_en.arb](../../flutter/l10n/app_en.arb)
- [lib/l10n/app_zh.arb](../../flutter/l10n/app_zh.arb)

### 0025

首页导航页首次访问时创建，保留已访问页面状态及认证隔离，暂停隐藏页动画以减少启动布局和初始化开销。

- [lib/widgets/common/auth_scoped_indexed_stack.dart](../../flutter/overrides/lib/widgets/common/auth_scoped_indexed_stack.dart)

### 0026

清理鸿蒙入口中的桌面 FFI、窗口恢复、安卓安装包清理及非 OH 小组件回调；系统强调色直接使用已有回退色。

- [lib/main.dart](../../flutter/overrides/lib/main.dart)
- [lib/pages/home_page.dart](../../flutter/overrides/lib/pages/home_page.dart)
- [lib/app.dart](../../flutter/overrides/lib/app.dart)
- [lib/providers/app_config_provider.dart](../../flutter/overrides/lib/providers/app_config_provider.dart)
- [lib/providers/set_theme_color_provider.dart](../../flutter/overrides/lib/providers/set_theme_color_provider.dart)
- [lib/pages/settings/set_theme_color_page.dart](../../flutter/overrides/lib/pages/settings/set_theme_color_page.dart)
- [lib/pages/settings/set_course_style_page.dart](../../flutter/overrides/lib/pages/settings/set_course_style_page.dart)
- [lib/utils/ohos_system_accent_color.dart](../../flutter/overrides/lib/utils/ohos_system_accent_color.dart)
