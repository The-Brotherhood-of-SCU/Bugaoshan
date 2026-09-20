# 52 个 Dart 覆盖文件的上游复用评估

审计日期：2026-09-18。代码基线：`port/ohos` 分支提交 `4ade79d`（合并前 OH：`0fd213a`；合入 main：`7fab588`）。范围为 [源码清单](../../flutter/source-manifest.json) 登记的 52 个覆盖文件，不含 15 个 OH 新增 Dart 文件。对照当前根 `lib/` 和 `ohos/flutter/overrides/lib/`，结合锁定 SDK、插件缓存源码作静态判断。

**结论：可以显著减少整文件覆盖，但不能直接把这 52 个文件全部恢复为当前上游。** 不少差异是值得共享的业务修复；直接删覆盖会丢失认证隔离、上传保护、冷启动数值容错或懒加载行为。真正的平台差异应尽量集中在启动、插件和原生能力边界。

初次审计只整理评估文档；之后按用户选择实施了覆盖迁移，但未修改根业务源码、SDK 或依赖，也未执行依赖解析、构建及测试。可行性仍是静态结论，不是编译或真机验证承诺。根源码不为 OH 直接修改的约定仍然有效，文中的“合回共享源”是原审计建议，并非本次实施结果。

## 实施结果

用户选择不把通用修复合入根 `lib/`。5 个优先恢复候选和 18 个通用修复
文件均已取消鸿蒙覆盖，现在直接采用根共享源；根 `lib/` 保持提交
`4ade79d` 的现有实现。18 份通用修复的迁移前快照已经由维护者剪切出
当前仓库，不参与 Flutter／鸿蒙源码组装。

因此当前活动覆盖为 **28 个上游覆盖 + 15 个 OH 新增文件**。下表 A、B 的
“恢复条件与建议”保留原审计结论，用来说明这次选择放弃或暂存了哪些行为；
B 类只链接当前共享源；对应修复没有启用。C、D 类在审计时为活动覆盖，其中
`pages/campus/repair/repair_page.dart` 此后已移除，见下方「2.5.2 合并后的同步」。

### 2.5.2 合并后的同步

- `app.dart` 和 `theme.dart` 已采用上游新的 Dock／全局转场语义，同时保留
  OH 强调色，并为 `TargetPlatform.ohos` 配置原生
  `OpenRightwardsPageTransitionsBuilder` 及自定义进出时长。
- `injection/injector.dart` 已注册共享的 `ForgotPasswordService`，并保留
  OH 卡片服务注册。
- 登录页覆盖未恢复：共享登录页本身已经包含密码重置入口；恢复旧覆盖会依赖
  已剪切出仓库的 `sessionEpoch` 通用认证修复，导致接口不匹配。
- 课程复制和转场测试以 OH 模板维护。课程测试使用内存假数据库，不依赖
  `sqflite_common_ffi` 或原生数据库插件。
- `pages/campus/repair/repair_page.dart` 的覆盖已移除：提交 `f0d1910` 已把父库
  imports 还原为上游写法，文件与上游逐字节一致，不再构成有效覆盖，清单条目一并删除。

| 分类 | 数量 | 当前建议 |
| --- | ---: | --- |
| A：优先恢复候选 | 5 | 首页最明确；其余须保留失败提示或确认入口取舍 |
| B：通用修复 | 18 | 先把修复合回共享代码，再取消覆盖 |
| C：集中适配后共享 | 12 | 收敛主题、选图、文件打开等入口，保留必要修复 |
| D：当前保留覆盖 | 17 | 有 SDK、插件依赖或 OH 原生能力差异 |
| 合计 | 52 | 逐项评估，不能一键删除 |

A～C 共 35 个有逐步复用机会，**不表示现在即可从 52 个降到 17 个**，也不承诺拆分之后文件总数一定减少。维护目标是减少重复业务逻辑和合并冲突。

## 逐文件评估

表中左列名称相对 `lib/`，文件名链接指向 OH 覆盖，旁边“上游”链接指向当前共享源。

### A：优先评估恢复上游（5 个）

这组没有已确认的硬性编译障碍，但不等于全部无损。首页是最明确的优先候选；其余四项涉及失败提示或入口可见性的取舍。

| 文件 | 可行性 | 当前差异／直接恢复的影响 | 恢复条件与建议 |
| --- | --- | --- | --- |
| [pages/home_page.dart](../../../lib/pages/home_page.dart) | 高；优先候选 | 覆盖移除了更新检查和生命周期观察。上游更新服务在 OH 返回不支持；回前台小组件更新限定 Android／iOS／macOS。 | 可优先恢复上游页面；继续保留当前懒加载容器及 OH 独立卡片同步服务。需要验证前后台切换和卡片同步。 |
| [pages/about/about_page.dart](../../../lib/pages/about/about_page.dart) | 高；提示行为有差异 | 唯一适配是向链接工具传 context；上游调用仍兼容 OH 工具的可选参数，但失败时会少 SnackBar。 | 将失败反馈集中到链接工具的有效根上下文或注入回调，再取消整页覆盖；否则需接受提示差异。 |
| [pages/about/team_page.dart](../../../lib/pages/about/team_page.dart) | 高；提示行为有差异 | 同样仅为链接调用补 context，外部打开和日志不依赖整页覆盖。 | 与关于页共用集中反馈方案。 |
| [pages/profile/profile_menu_card.dart](../../../lib/pages/profile/profile_menu_card.dart) | 高；提示行为有差异 | 同样仅为链接调用补 context；直接恢复会减少失败反馈。 | 与关于页、团队页一起取消不必要的整页副本。 |
| [pages/dev/dev_page.dart](../../../lib/pages/dev/dev_page.dart) | 高；产品行为有差异 | 覆盖隐藏了 UiTile 和对应分隔线；上游 UI Preview 是普通 Flutter 对话框演示，未发现必须排除的新版 API。 | 若允许重新显示 UI Preview，可恢复；此前隐藏入口的选择不能自动当作可撤销。 |

### B：先合回通用修复，再取消覆盖（18 个）

这些差异主要是认证、上传、异步状态或错误反馈修复，不应长期由鸿蒙独享，也不能为减少文件数直接丢弃。按现有维护约定，本轮不修改根 lib/；合回共享源是后续建议。

| 文件 | 可行性 | 当前差异／直接恢复的影响 | 恢复条件与建议 |
| --- | --- | --- | --- |
| [pages/auth/scu_login_page.dart](../../../lib/pages/auth/scu_login_page.dart) | 高；须与认证链一起迁移 | 包含会话恢复提示、mounted 和 sessionEpoch 校验；上游尚无这些接口。覆盖还遗漏本次 main 的密码重置入口。 | 共享认证接口和 UI 防竞态逻辑，并同步上游密码重置入口及其 DI 注册。 |
| [pages/campus/repair/repair_submit_tab.dart](../../../lib/pages/campus/repair/repair_submit_tab.dart) | 高；须按 part 文件组迁移 | 提交数据快照、账号切换清表单、拒绝旧结果、上传互斥和选图失败处理。依赖父库 imports 及子组件 key。 | 与 repair_page.dart、repair_widgets.dart 一起共享修复，不能单独删除。 |
| [pages/campus/repair/repair_widgets.dart](../../../lib/pages/campus/repair/repair_widgets.dart) | 高；改动很小 | 有效逻辑差异是 _ProjectSelector 构造函数增加 super.key，其余主要是缩进；OH 提交页传入 ValueKey。 | 先共享 key 参数，再取消覆盖；仅恢复此文件会破坏现有调用。 |
| [pages/campus/service_hall/service_form_page.dart](../../../lib/pages/campus/service_hall/service_form_page.dart) | 高；须保留状态保护 | 增加 sessionEpoch 校验、账号切换清理、上传草稿快照、防重复提交，并停止记录完整表单 payload。 | 将状态和日志修复共享；与认证 epoch 接口一起迁移。 |
| [pages/dev/auth_log/auth_log_viewer_page.dart](../../../lib/pages/dev/auth_log/auth_log_viewer_page.dart) | 高；与分享接口成组 | 检查分享返回 bool 和 mounted，避免失败或取消后仍提示已保存。 | 与 share_utils.dart 一起统一返回值及反馈语义。 |
| [pages/settings/background_crop_editor_page.dart](../../../lib/pages/settings/background_crop_editor_page.dart) | 高；可单独共享修复 | 图片尚未解码或背景已变化时拒绝保存，属于通用异步状态保护。 | 先将保存前检查合回共享页面，再去覆盖。 |
| [providers/passpoint_provider.dart](../../../lib/providers/passpoint_provider.dart) | 高；通用状态修复 | 添加／取消操作互斥、正确传播 UnauthenticatedException，并记录错误。 | 共享互斥和认证错误语义，保留失败后的可恢复状态。 |
| [providers/scu_auth_provider.dart](../../../lib/providers/scu_auth_provider.dart) | 高；认证组核心 | 提供 sessionEpoch、sessionRecoveryMessage，退出 single-flight，自动登录拒绝旧会话结果。 | 与 ScuAuth、登录页和依赖 epoch 的业务服务一起迁移。 |
| [services/api/api_request.dart](../../../lib/services/api/api_request.dart) | 高；认证组基础接口 | retryOnUnauthenticated 增加可选 isSessionCurrent，在调用前后及重试阶段检查会话。 | 共享可选参数及检查，不可先恢复而留下调用新参数的业务代码。 |
| [services/api/new_service_api_service.dart](../../../lib/services/api/new_service_api_service.dart) | 高；通用接口防护 | 绑定 sessionEpoch，校验 HTTP 状态和响应结构，不将缺少操作结果当作成功。 | 共享会话和响应校验，与 PasspointProvider 联合验证。 |
| [services/api/service_api_service.dart](../../../lib/services/api/service_api_service.dart) | 高；通用上传防护 | 会话 epoch、空文件拒绝、上传禁止重定向、发送和响应体超时、非 2xx 处理。 | 共享上传及会话修复，不退回旧上传流程。 |
| [services/api/zhhq_api_service.dart](../../../lib/services/api/zhhq_api_service.dart) | 高；通用上传与认证修复 | 会话绑定重试、空文件拒绝、重定向限制、超时和非 2xx 检查。 | 与 ZhhqAuth、通用重试接口一起共享。 |
| [services/auth/ccyl_auth.dart](../../../lib/services/auth/ccyl_auth.dart) | 高；通用存储容错 | 安全存储读取失败时只清内存，保留磁盘凭据，避免把临时读取失败当作清除授权的理由。 | 保留读取失败与确定失效的区别后取消覆盖。 |
| [services/auth/scu_auth.dart](../../../lib/services/auth/scu_auth.dart) | 高；不能单文件恢复 | sessionEpoch、登录尝试代次、持久化写入队列、退出标记、token 所属账号校验和凭据恢复提示。 | 作为整条认证链迁移的基础；处理已有 OH 持久标记兼容，保留账号隔离。 |
| [services/auth/sso_relay_auth.dart](../../../lib/services/auth/sso_relay_auth.dart) | 高；认证组配套 | 暴露 sessionEpoch，以 generation 拒绝旧 SSO 回写，并以 identical 判断待清理 future。 | 与 ScuAuth 及子系统服务同时共享。 |
| [services/auth/zhhq_auth.dart](../../../lib/services/auth/zhhq_auth.dart) | 高；有存储迁移前提 | token 与 principal 成对 JSON 持久化，写入队列和 generation／epoch 校验；不同于上游裸 tokenKey。 | 明确读取兼容和迁移策略，不能直接退回上游格式或丢弃账号绑定。 |
| [utils/share_utils.dart](../../../lib/utils/share_utils.dart) | 高；接口需成组统一 | Future<void> 改为 Future<bool>，增加文件存在性、互斥、取消／失败处理和提示。 | 共享返回值约定，更新依赖 bool 的日志查看器；不是仅有插件名称差异。 |
| [widgets/common/auth_scoped_indexed_stack.dart](../../../lib/widgets/common/auth_scoped_indexed_stack.dart) | 高；通用性能修复 | 首次访问才创建页面，隐藏页暂停 TickerMode，保留页面状态和账号隔离。 | 共享懒加载行为后取消覆盖；直接恢复会重新预建所有标签页。 |

### C：集中适配或小幅共享改造后复用（12 个）

这组主要适合让页面使用统一的平台能力入口，或将小型通用修复合回共享代码。集中适配不等于将差异转成更多脚本替换补丁。

| 文件 | 可行性 | 当前差异／直接恢复的影响 | 恢复条件与建议 |
| --- | --- | --- | --- |
| [app.dart](../../flutter/overrides/lib/app.dart) · [上游](../../../lib/app.dart) | 高；主题策略集中后 | 真实平台差异是系统强调色回退；Dock 开关耦合则是此次合并未同步的上游修复。 | 统一强调色来源，并与 theme.dart 一起同步上游 Dock 动画作用域修复。 |
| `pages/campus/repair/repair_page.dart` · [上游](../../../lib/pages/campus/repair/repair_page.dart)（覆盖已移除） | 高；part 组配套 | 父库 imports 改为选图 helper，增加 AppLog 和认证异常引用，服务于两个 part 的修复。 | 将选图和错误处理封装共享，与两个 part 一起恢复共享源。 |
| [pages/campus/downloads/attachments_sheet.dart](../../flutter/overrides/lib/pages/campus/downloads/attachments_sheet.dart) · [上游](../../../lib/pages/campus/downloads/attachments_sheet.dart) | 高；统一文件打开入口后 | OpenFilex.open 改为 openLocalFile(path, context)，底层仍调用同一插件，主要增加结果检查和提示。 | 共享文件打开封装及调用，不必为错误处理保留整页副本。 |
| [pages/campus/downloads/notice_downloaded_page.dart](../../flutter/overrides/lib/pages/campus/downloads/notice_downloaded_page.dart) · [上游](../../../lib/pages/campus/downloads/notice_downloaded_page.dart) | 高；统一文件打开入口后 | 同样是文件打开结果和失败反馈的封装差异。 | 与附件面板共享 openLocalFile，保留原有错误反馈。 |
| [pages/campus/service_hall/service_field_widgets.dart](../../flutter/overrides/lib/pages/campus/service_hall/service_field_widgets.dart) · [上游](../../../lib/pages/campus/service_hall/service_field_widgets.dart) | 高；统一选图入口后 | ImagePicker 改为 pickGalleryImage(context)，补 mounted；helper 底层仍为 ImagePicker。 | 共享选图互斥、文件检查和提示，避免整页覆盖。 |
| [pages/settings/set_course_style_page.dart](../../flutter/overrides/lib/pages/settings/set_course_style_page.dart) · [上游](../../../lib/pages/settings/set_course_style_page.dart) | 高；先保留文件安全修复 | 混合选图 helper、背景复制成功后才替换旧图、失败清理和强调色回退。 | 共享背景替换事务逻辑，集中选图及主题策略，再取消覆盖。 |
| [pages/settings/set_theme_color_page.dart](../../flutter/overrides/lib/pages/settings/set_theme_color_page.dart) · [上游](../../../lib/pages/settings/set_theme_color_page.dart) | 高；统一主题来源后 | 仅将 SystemTheme.accentColor 改为 OH 回退色。 | 集中强调色来源，页面使用共享接口。 |
| [providers/app_config_provider.dart](../../flutter/overrides/lib/providers/app_config_provider.dart) · [上游](../../../lib/providers/app_config_provider.dart) | 高；数值读取修复是硬前提 | 主题回退之外，4 项偏好读取由 getDouble 改为 get + safeDouble + finite 检查，包含近期冷启动修复。 | 先共享宽松数值读取，保留历史整数／浮点兼容及非有限值处理；再集中主题来源。 |
| [providers/environment_info/native.dart](../../flutter/overrides/lib/providers/environment_info/native.dart) · [上游](../../../lib/providers/environment_info/native.dart) | 中高；平台分类初始化后 | OH 跳过 OS.isPCOS／isMobileOS；os_type 在未初始化 OH 设备类型时可能 assert。 | 由原生设备信息初始化或建立统一平台分类后复用，不能直接删掉保护。 |
| [providers/set_theme_color_provider.dart](../../flutter/overrides/lib/providers/set_theme_color_provider.dart) · [上游](../../../lib/providers/set_theme_color_provider.dart) | 高；主题策略集中后 | SystemTheme.load／accentColor 改为回退色，不是包缺失。 | 统一强调色加载与回退，业务 Provider 不承担平台差异。 |
| [theme.dart](../../flutter/overrides/lib/theme.dart) · [上游](../../../lib/theme.dart) | 高；与 app.dart 配套 | 原适配只是 cupertino import 的 unnecessary_import 忽略；当前其他差异主要是未同步 main 的 Dock 修复。 | 同步共享主题并处理 app.dart 参数；若要 OH 使用自定义转场，另补平台映射，不能把旧逻辑视作 SDK 限制。 |
| [widgets/eula_content.dart](../../flutter/overrides/lib/widgets/eula_content.dart) · [上游](../../../lib/widgets/eula_content.dart) | 高；统一链接策略后 | 上游直接使用 launchUrl 默认模式；OH 改为统一外部打开和失败反馈。 | 共享链接入口后取消覆盖；不能无条件恢复默认模式，否则 HTTP 链接可能改走内置 WebView。 |

### D：当前 SDK／插件／原生能力下保留（17 个）

这组暂时需要独立适配边界，但不代表整份文件永远不能共享。将来可拆出平台注册、启动或插件能力接口；目前直接恢复会缺少功能、解析失败或遇到 API 不兼容。

| 文件 | 可行性 | 当前差异／直接恢复的影响 | 恢复条件与建议 |
| --- | --- | --- | --- |
| [injection/injector.dart](../../flutter/overrides/lib/injection/injector.dart) · [上游](../../../lib/injection/injector.dart) | 暂保留；未来可抽注册钩子 | 注入 OH 卡片快照、同步和销毁逻辑；上游没有这些注册。当前覆盖还漏了上游 ForgotPasswordService 注册。 | 保留平台注册，补齐上游新增注册；将来以小型平台注册入口代替整份 DI 覆盖。 |
| [main.dart](../../flutter/overrides/lib/main.dart) · [上游](../../../lib/main.dart) | 暂保留；未来可拆启动入口 | 裁剪已排除的桌面依赖与其他平台初始化，增加 OH 启动错误报告和诊断。 | 保持 OH 小入口，逐步共享通用 bootstrap；不能仅加运行时 Platform 判断掩盖缺包 import。 |
| [pages/dev/environment_info_page.dart](../../flutter/overrides/lib/pages/dev/environment_info_page.dart) · [上游](../../../lib/pages/dev/environment_info_page.dart) | 暂保留；设备插件不同 | 上游直接依赖被 OH 排除的 device_info_plus，且无 OH 原生字段。覆盖提供设备信息、复制和重试。 | 保留原生信息适配；未来将数据源抽离，页面可争取共享。 |
| [pages/settings/add_widget/add_widget_page.dart](../../flutter/overrides/lib/pages/settings/add_widget/add_widget_page.dart) · [上游](../../../lib/pages/settings/add_widget/add_widget_page.dart) | 暂保留；系统卡片能力 | 提供 OH 课表卡片管理入口及说明，上游其他平台流程无法替代。 | 共享可复用外壳，保留 OH 卡片操作实现。 |
| [pages/settings/set_dock_page.dart](../../flutter/overrides/lib/pages/settings/set_dock_page.dart) · [上游](../../../lib/pages/settings/set_dock_page.dart) | 暂保留；明确 SDK API 差异 | 上游使用 onReorderItem；锁定 OH SDK 只有 onReorder，且索引调整语义不同。 | 保留 onReorder 及 newIndex 调整；SDK 支持新接口或共享代码采用兼容接口后再合并。 |
| [pages/settings/software_setting_page.dart](../../flutter/overrides/lib/pages/settings/software_setting_page.dart) · [上游](../../../lib/pages/settings/software_setting_page.dart) | 暂保留；原生能力入口 | 显示 OH 动态图标和卡片入口，包含 API < 26 的保护。 | 保留能力判断；未来以平台能力描述驱动共享设置页。 |
| [services/dynamic_icon_service.dart](../../flutter/overrides/lib/services/dynamic_icon_service.dart) · [上游](../../../lib/services/dynamic_icon_service.dart) | 暂保留；原生方法差异 | OH 支持判定及 supportsAlternateIcons 方法；上游仅 Android 且吞掉 MissingPlugin。 | 保留 OH 通道能力查询，不能恢复为 Android-only。 |
| [services/exit_service.dart](../../flutter/overrides/lib/services/exit_service.dart) · [上游](../../../lib/services/exit_service.dart) | 暂保留；缺包 import | 上游直接导入被 OH 排除的 window_manager。 | 通过明确的平台实现隔离桌面依赖，之后共享调用接口。 |
| [services/update_asset_selector.dart](../../flutter/overrides/lib/services/update_asset_selector.dart) · [上游](../../../lib/services/update_asset_selector.dart) | 暂保留；缺包 import | 上游导入被 OH 排除的 device_info_plus；OH 不自更新也无法消除静态依赖链。 | 保留兼容实现，或从 OH 的完整源码及分析依赖中隔离该模块。 |
| [services/widget_update_service.dart](../../flutter/overrides/lib/services/widget_update_service.dart) · [上游](../../../lib/services/widget_update_service.dart) | 暂保留；OH 卡片接口 | 增加 OH 快照 payload、支持平台、系统管理及 dispose 等接口，被 DI、设置页和同步服务调用。 | 保留功能组；未来共享服务接口、分平台实现。 |
| [services/window_state_service.dart](../../flutter/overrides/lib/services/window_state_service.dart) · [上游](../../../lib/services/window_state_service.dart) | 暂保留；桌面依赖隔离 | OH 为无操作实现；上游依赖已排除的 window_manager、screen_retriever。 | 先隔离桌面源码及完整分析范围，再考虑去掉替代实现；仅入口不可达不足以解决。 |
| [utils/calendar_export_utils.dart](../../flutter/overrides/lib/utils/calendar_export_utils.dart) · [上游](../../../lib/utils/calendar_export_utils.dart) | 暂保留；插件和结果语义不同 | 上游 file_picker 被排除；OH 用 ICS 原生交接，且打开日历不代表导入成功。 | 保留原生导出／交接接口和准确的结果提示。 |
| [utils/open_link.dart](../../flutter/overrides/lib/utils/open_link.dart) · [上游](../../../lib/utils/open_link.dart) | 暂保留；集中适配边界 | 统一 externalApplication 和打开失败处理；OH 插件默认模式的 HTTP 链接走内置 WebView。 | 先保留这个小边界，优先消除为传 context 而存在的页面覆盖；未来可将策略通用化。 |
| [widgets/common/image_viewer.dart](../../flutter/overrides/lib/widgets/common/image_viewer.dart) · [上游](../../../lib/widgets/common/image_viewer.dart) | 暂保留；图片保存插件不同 | 上游 gal 被 OH 排除；OH 使用 image_gallery_saver_plus 封装。 | 抽图库保存能力后可共享大部分 UI，现阶段不能直接恢复原文件。 |
| [widgets/webview/captcha_webview_dialog.dart](../../flutter/overrides/lib/widgets/webview/captcha_webview_dialog.dart) · [上游](../../../lib/widgets/webview/captcha_webview_dialog.dart) | 暂保留；插件下载 API 不兼容 | 上游 onDownloadStarting／DownloadStartResponse 在锁定插件中不存在。 | 保留当前插件兼容回调；插件升级后再评估统一。 |
| [widgets/webview/webview_notice_handlers.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_handlers.dart) · [上游](../../../lib/widgets/webview/webview_notice_handlers.dart) | 暂保留；插件下载 API 不兼容 | 上游新下载 API 类型缺失，覆盖移除了相关封装。 | 与验证码和通知页成组迁移下载事件适配。 |
| [widgets/webview/webview_notice_page.dart](../../flutter/overrides/lib/widgets/webview/webview_notice_page.dart) · [上游](../../../lib/widgets/webview/webview_notice_page.dart) | 暂保留；平台主动禁用及 API 差异 | 上游遇到 OS.isHarmony 直接显示不支持；另有新下载 API 不兼容。OH 还有首帧、美化、移动布局、原生主题及生命周期修复。 | 保留可运行 OH 实现；先拆出下载及平台能力，再将通用 WebView 修复合共享。 |

## 判断依据与容易误判的地方

1. **SDK 版本确实不同。** [工具链锁](../../flutter/toolchain.lock.json) 固定 Flutter `3.41.10-ohos-1.0.1`／Dart `3.11.5`，上游要求 Flutter 3.44。锁定 OH SDK 的 ReorderableListView 没有 `onReorderItem`，不能靠删覆盖消除这个差异。另一方面，它支持转场 builder 的时长读取，不能把 theme.dart 的所有差异都归因于 SDK 太旧。
2. **WebView 有明确的不兼容点。** 当前锁定插件源码存在 `onDownloadStartRequest`，不存在上游使用的 `onDownloadStarting`／`DownloadStartResponse`。上游通知页还主动拒绝 Harmony 平台，这不是仅换一份依赖就能恢复的页面。
3. **缺包和运行时不可达是两回事。** [依赖配置](../../flutter/pubspec_dependencies.json) 排除了 `device_info_plus`、`sqflite_common_ffi`、`window_manager`、`screen_retriever`、`file_picker`、`gal`。源码仍导入这些包时，仅增加 Platform 分支不能解决解析和分析问题；应隔离对应实现与分析范围，不应制造空壳包蒙混通过。
4. **system_theme 不是缺包。** OH 依赖仍有 system_theme 3.2.0。它初始化 accentColor 时调用 load，load 会发 MethodChannel，再捕获 MissingPluginException；默认回退色是 cyan，当前 OH 回退为 blue。直接恢复所有主题访问不一定编译失败，但可能改变回退色和通道调用。可以集中主题策略，或在首次访问 accentColor 前统一设置回退色，不能声称恢复后完全等价。
5. **链接打开模式有实际差异。** url_launcher_ohos 的 platformDefault 对 HTTP(S) 使用内置 WebView，externalApplication 才交给外部应用。因此可以减少只传 context 的页面副本，但应保留统一链接策略。
6. **选图、打开文件不全是插件 API 差异。** OH 选图 helper 底层仍是 ImagePicker；文件打开 helper 底层仍是 OpenFilex。主要价值是互斥、文件检查、结果判断和用户反馈，适合共享，没必要长期复制完整业务页面。
7. **主题平台映射另有不足。** 当前共享主题与 OH 主题均未显式配置 TargetPlatform.ohos，锁定 SDK 会回退 Zoom 转场；自定义转场时长并不会因此自动作用到 OH。恢复主题覆盖和完善 OH 转场是两个需分别验证的动作。

## 必须成组处理的依赖

| 文件组 | 不能拆开恢复的原因 |
| --- | --- |
| ScuAuth → ScuAuthProvider／SsoRelayAuth → api_request → 业务 API／表单／登录页 | OH 新增 sessionEpoch、isSessionCurrent、sessionRecoveryMessage 等接口。先恢复底层会使调用方失配；先恢复调用方则可能丢掉账号切换保护。 |
| ZhhqAuth 与相关 API／表单 | OH 使用 `ohos_zhhq_session_v1` 保存 principal 与 tokenKey 的 JSON；上游是裸 tokenKey。应有兼容读取或明确迁移，不能丢失账号归属。 |
| ScuAuth 持久化与退出流程 | OH 已使用 `ohos_session_signed_out_v1` 退出标记及顺序写入。回退旧实现前必须考虑旧凭据重新恢复和并发写入。 |
| repair_page + repair_submit_tab + repair_widgets | 属于同一个 part 库，imports 与私有组件共享；提交页依赖新增 key 参数。 |
| share_utils + auth_log_viewer_page | OH 返回 Future<bool>，日志页依赖结果；上游返回 Future<void>。 |
| injector + widget_update_service + OH 卡片同步／设置入口 | 存在新增服务、方法及销毁接口依赖；单删会缺少注册、接口或卡片同步。 |
| app + theme | 参数及 Dock 动画作用域必须一致；不能只恢复其中一个。 |
| WebView 通知页 + handlers + 验证码弹窗 | 需统一当前插件下载回调与新版 API 的差异，不宜逐文件混用。 |

这些存储 key 是现有兼容事实，不是建议继续增加平台专属业务数据格式。若将认证实现共享，应在后续迁移中消化历史差异。

## 本次 main 合并需要先补齐的四处

这些属于上游改动尚未同步到覆盖，**不构成保留旧覆盖逻辑的理由**：

| 文件 | 上游应保留的变化 | 与 OH 修复的合并方式 |
| --- | --- | --- |
| app.dart | Dock 动画开关作用域修复 | 保留上游作用域，集中 OH 强调色来源 |
| theme.dart | 与 Dock 配套的主题／动画逻辑 | 与 app.dart 一起同步，避免参数不一致 |
| injection/injector.dart | ForgotPasswordService 注册 | 加回上游注册，同时保留 OH 卡片服务 |
| pages/auth/scu_login_page.dart | 密码重置入口 | 合入入口，同时保留会话恢复提示及异步状态校验 |

[source-manifest.json](../../flutter/source-manifest.json) 是历史覆盖基线；不能只把哈希改成新值而跳过合并。

## 原审计建议（本次未合入通用修复）

1. **先同步四处合并遗漏。** 明确上游新增行为与 OH 修复同时存在，再更新对应清单基线。
2. **从最小候选开始。** 优先验证首页恢复；将链接失败反馈集中后处理三个只传 context 的 UI 覆盖。开发者 UI Preview 入口按产品选择处理。
3. **先共享小型通用修复，再迁移认证组。** 背景裁剪检查、组件 key、懒加载、分享结果可以较小批次处理。认证、持久化和上传则以完整依赖组迁移。
4. **收敛页面对平台的依赖。** 主题色、选图、文件打开、链接打开采用共享入口，避免每个页面维护副本。偏好数值读取必须保留 get + safeDouble + finite 的兼容修复。
5. **最后评估较重的平台组。** DI、启动、图库、日历、卡片、WebView 保留清晰的 OH 实现；待 SDK／插件 API 对齐或能力接口拆分完成后再取消对应整文件覆盖。
6. **每批取消覆盖时维护真实来源。** 删除覆盖文件与对应 manifest 项，由既有组装脚本重建链接，确保最终指向根共享文件。不要把上游文件原样复制进覆盖目录，也不要用字符串补丁掩盖差异。

## 后续验证重点（由用户执行）

| 改动组 | 必须覆盖的行为 |
| --- | --- |
| 首页／懒加载 | 首次打开、标签页状态、退出及切换账号、前后台切换、卡片更新 |
| 认证与存储 | 旧版本数据升级、读取失败、退出并发登录、切换账号时请求返回、令牌过期重试 |
| 偏好与启动 | 历史整数／浮点值、缺失或异常类型、非有限值、冷启动 |
| 上传与报修 | 空文件、取消选图、重复提交、账号切换、超时／重定向／非 2xx、迟到响应 |
| 主题和链接 | 主题回退色、Dock 开关、失败提示、EULA／网站打开的目标应用 |
| 插件和原生功能 | Dock 排序索引、WebView 验证码及附件、图库保存、ICS 交接、卡片管理、API 版本保护 |

静态审计可以确认以上依赖和恢复风险，实际启动、渲染及原生功能结果仍需使用锁定工具链构建并在目标设备验证。
