# 第五阶段：原生能力实现与验收

2026-09-22 变更：第三方插件补丁和旧缓存迁移已移除，安全存储改用 OH 包自带接口。
本文此前关于插件补丁及其验证的内容保留为历史记录，不能代表当前原版插件已通过验证。
当前接入方式见 [Flutter 适配说明](../flutter-adaptation.md)。

日期：2026-09-16。用户已明确要求“直接开始第5阶段”，按审核后的安卓对齐方案实施。
状态：第五阶段已完成，用户于 2026-09-16 确认“第五阶段没有问题了”。
课表服务卡片、动态图标及确认文案、开发者页环境信息和 UI Preview 入口移除均纳入本次验收。
本轮仅修改 `ohos/` 下的原生代码、资源、源码补丁、补丁应用脚本及文档；
未执行依赖解析、补丁应用、代码生成、格式化、分析、测试或构建。
第三、四阶段代码与用户通过记录保留。按用户最新要求，鸿蒙应用内自更新及其专用通知通道已移除，相关任务不再放入阶段七。

## 1. 范围与安排

| 项目 | 第五阶段代码交付 | 运行验收 |
| --- | --- | --- |
| 课表服务卡片 | 原生 FormExtension、卡片布局、当前课表快照、数据同步、系统刷新及应用内添加入口 | 用户确认小组件完成，卡片验收已勾选 |
| 动态图标 | 接入 API 26 官方备用图标接口，支持旧图标与恢复默认图标；确认文案去掉重启提示 | 按用户第五阶段整体验收确认通过 |
| 开发者页环境信息 | 鸿蒙原生设备信息、复制全部、失败提示及重试 | 按用户第五阶段整体验收确认通过 |
| 开发者页 UI Preview | 移除入口、分隔线及不再使用的 import | 按用户第五阶段整体验收确认通过 |

实施顺序：动态图标 → 课表服务卡片 → 文档与能力矩阵。

## 2. 维护边界

- 持久改动仅位于 `ohos/`，继续同一分支、稳定 Flutter OH SDK 和 API 26 工具链。
- Dart 和设置入口现在以完整文件保存到 `flutter/overrides/lib/`，文案差异保存到 `flutter/l10n/`，
  经 `source-manifest.json` 基线检查后仅组装到构建副本；原补丁编号见 [迁移记录](../audits/source-overlay-migration.md)。
- 原生能力分别放入独立 ArkTS 文件，`EntryAbility.ets` 只负责通道注册、分发和生命周期清理。
- 不新增第三方插件，不修改已通过的 WebView/嵌入层补丁；本机路径及签名材料不写入仓库。
- 代理负责代码与文档，用户负责依赖解析、构建和真机测试；代码完成与真机通过分开标记。

## 3. 课表服务卡片

### 显示与交互

按用户要求，以当前安卓 `CourseGlanceWidget.UnifiedWidget` / `CourseCard` 的实际实现
为显示与交互基线。安卓三个 Receiver 使用同一组件，按可用宽高切换布局；
课程通过 `LazyColumn` 展示，未按 small/medium/large 固定截断为一门、两门或若干门。
鸿蒙同样提供一个自适应课表卡片类型，三种规格映射如下：

| 鸿蒙规格 | 对应安卓规格 | 对齐行为 |
| --- | --- | --- |
| `2*2` | Small，宽 2 格 × 高 2 格 | 窄版布局，标题/日期按宽度换行，课程信息紧凑显示；全部未结束课程可纵向滚动 |
| `2*4` | Medium，宽 4 格 × 高 2 格 | 横向宽版布局，空间足够时标题和日期同一行；全部未结束课程可纵向滚动 |
| `4*4` | Large，宽 4 格 × 高 4 格 | 较高布局，空间足够时分行展示时间、节次和地点；全部未结束课程可纵向滚动 |

鸿蒙 `2*4` 对应安卓的宽 4 格、高 2 格。表中紧凑/宽版是通常效果，最终根据宿主提供的
实际可用宽高决定布局，不按规格名称写死显示条数。取消前版“一门/两门”的限制和
“内容放不下只能打开应用”的交互，采用 ArkUI 卡片支持的纵向 List 展示完整列表。

具体对齐规则：

- 标题使用应用名称“不高山上 / Bugaoshan”，日期包含月/日和星期，旁边显示周次；显示明天时增加明天标记。
- 扣除两侧内边距后空间足够，标题和日期同一行；窄卡片分成两行。
- 课程名称单行，左侧保留课程自定义颜色色条；无效颜色回退默认强调色。
- 紧凑布局显示时间与地点；窄宽度只显示开始时间，宽度足够显示起止时间。较高布局将时间和地点分行，空间足够时补充节次。
- 当前正在上课的课程名称加粗、时间使用课程色强调；已结束课程移除，其他课程按开始节次排列。
- 明天课程使用安卓对应的灰色层级，深浅模式分别配色；保持外层圆角、内层课程卡片、字号和间距的视觉层级。
- 安卓卡片实际显示名称、时间/节次和地点，没有教师行，也没有读取应用的教师/地点显示开关；本方案按相同字段展示，不额外增加教师行。
- 列表可滚动，点击卡片打开应用。安卓未提供独立刷新按钮或“打开应用”底栏，鸿蒙卡片也不添加这两行控件。

沿用安卓当前选中课表、有效教学周/单双周、课程结束时间、“显示明天课程”和空状态规则。
区分“打开 App 同步课表”“今天没有课程”“今天的课都上完啦”“明天没课”“放假中”。
假期判定也按安卓实现：当前学期结束且存在尚未开始的下一学期；不将所有学期外日期
统一改成前版的“当前不在所选学期内”。前后日期的周次边界处理继续与安卓一致。
下学期元数据只用于假期判断，课程仍来自用户当前选中的课表，不自动切到其他课表。

视觉参数参考安卓当前值：外层圆角 16、内边距 12、课程圆角 12、课程内边距 8；
标题字号 15、课程名 14、辅助文字 13/11。Android dp/sp 转为鸿蒙 vp/fp，
按实际可用空间适配，保留系统字体缩放。浅/深色与明天课程颜色以安卓资源表为参照。
布局判断同样参考安卓阈值：总宽减 24 后至少 180 时标题同行；总高减去标题估算 80
和纵向边距 24 后大于 100 时使用分行课程信息；紧凑模式总宽小于 200 时只显示开始时间。
这些是布局空间阈值，不是某台设备的固定像素尺寸，也不决定列表课程总数。

设置页提供“打开服务卡片管理”入口，通过系统卡片管理页由用户选择尺寸并添加。
打开管理页只记为请求成功，不提示已经添加。添加和刷新调度使用鸿蒙系统接口；
卡片内容、滚动及点击打开应用的行为与安卓对齐，不新增课程详情跳转。

### 数据来源与保存

沿用 `CourseProvider` 和 `AppConfigProvider`，由 Dart 按上述安卓规则准备当前课表的
展示快照，通过现有更新 MethodChannel 交给原生。快照包含按周/星期整理的有效课程、
起止时间、节次、颜色，以及学期边界和下一学期开始日期等最少元数据。
原生按当前日期选择周次、今天/明天和上课中状态，应用不运行时也可跨天刷新。
日历与时间边界的计算以安卓 `WidgetDataLoader` 为对照，不另查认证接口或维护第二份业务数据库。

快照保存到本应用私有文件目录，以带版本号的 JSON 记录，用临时文件加原子替换避免读取半份内容。
其中只包含卡片展示所需字段；教师信息、认证 token 和密码不进入卡片快照。
清空或删除当前课表时写入明确的空快照，避免桌面继续显示旧课表。
保留上游本地课表与账号的共享约定，不将退出登录自动等同于删除课表。

### 同步与刷新

- 应用启动、返回前台、课表增删改/切换，以及卡片相关设置变化时同步；复用现有更新服务的防抖与串行逻辑。
- 原生记录本应用卡片实例，更新全部已添加实例；删除一个实例不会影响其他实例。
- `FormExtensionAbility.onAddForm` 提供初始快照；`onUpdateForm` 重新按日期计算显示，卡片表面不增加安卓没有的刷新按钮。
- 系统常规周期刷新以 30 分钟为基础，可按课程边界申请下一次刷新；`setFormNextRefreshTime` 最短 5 分钟，受系统调度和配额约束。
- 刷新读取本地课表快照，不在后台启动 Flutter 或联网重新拉取教务课表；应用内更新课表后才同步新数据。

不承诺应用关闭后在课程结束的瞬间准点刷新。过期/异常快照应显示可理解的打开应用提示，
不能依靠长期驻留后台或高频定时器维持卡片。

### 实现位置

- 原生：`entry/src/main/ets/cards/`、`entry/src/main/resources/base/profile/course_card.json`、`entry/src/main/module.json5`。
- 资源：`entry/src/main/resources/` 的中英文文案和主题资源。
- Dart 补丁目标：`WidgetUpdateService`、DI 中的初始化与设置监听、OH 快照生成辅助文件、添加组件页面和设置入口。
- 验收重点：三种规格对照安卓的布局、完整列表滚动、课程色和上课中状态，多实例、当前课表切换、跨天/跨周/单双周、明天/假期/空状态、清空数据及深浅主题；刷新时效另按鸿蒙调度限制验证。

## 4. 动态图标

本机 API 26 声明提供公开接口：

- `bundleManager.getAlternateIcons()`：读取应用声明的备用图标及 `enabled` 状态。
- `bundleManager.setAlternateIcon(name)`：设置备用图标；传空字符串恢复默认图标。
- `AppScope/app.json5` 的 `alternateIcons`：声明备用图标名称及资源。

方案是保留默认图标，增加上游已有 `assets/icon_old.png` 对应的备用资源，名称继续使用 `old`。
原生实现现有 `bugaoshan/dynamic_icon` 通道的三个图标方法及运行版本支持查询；Dart 通过 OH 补丁启用
`DynamicIconService` 和现有设置页，沿用预览、确认及失败提示。
用户确认鸿蒙切换图标无需重启；`0022` 将中英文确认文案改为仅询问是否切换，去掉应用重启提示。

当前图标以系统返回的 `enabled` 为准，不使用本地偏好假定切换成功；连续切换串行处理。
低于 API 26 的设备点击“应用图标”入口时提示“鸿蒙 7 以下不支持该功能”，停留在设置页；
原生切换方法仍保留低版本保护，不调用不存在的系统接口。此入口提示由后续 `0024` 补丁增加，待用户验收。
资源复用上游图像，不重新设计图标，也不新增 Android 式 Activity alias。

实现位置：`AppScope/app.json5`、`AppScope/resources/base/media/`、
`entry/src/main/ets/platform/DynamicIconChannel.ets`、`EntryAbility.ets` 及对应 Dart 补丁。
验收包含切旧图标、恢复默认、手动重启后状态一致、重复点击及系统拒绝；手动重启仅用于验证状态保持。

### 开发者页环境信息

`0021` 将第二阶段 `mobile_device_info.dart` 的空结果接到新通道
`bugaoshan/environment_info` 的 `getDeviceInfo` 方法，原生实现位于
`entry/src/main/ets/platform/EnvironmentInfoChannel.ets`，由 `EntryAbility` 注册并清理。
使用 API 6 起公开的 `deviceInfo` 常量，兼容当前 API 20 最低版本，不引回 `device_info_plus`。

设备卡片展示品牌、厂商、市场名称、型号、设备类型、系统全名、显示版本、系统发布类型、
SDK API 等级、出厂 API 等级、ABI、安全补丁日期和系统构建类型。
不读取 SN、UDID 或账号标识，不新增权限。实际值来自当前设备，不写入本机 SDK 路径或固定版本值。

原有应用、Dart、系统、文件目录、运行标志和 Git 构建信息继续显示。
鸿蒙设备分类改用 Device 中的原生 `deviceType`，避免直接调用尚未初始化的
`os_type.isPCOS/isMobileOS` 在调试模式触发断言。
“复制全部”包含所有显示分区；应用环境与设备信息分别捕获读取失败，5 秒超时后提示失败并支持重试，
成功读取的另一分区仍可显示和复制。失败日志通过 `AppLog` 记录。
`0023` 按用户要求移除开发者页的 UI Preview 入口、对应分隔线及 import。

## 5. SDK 与上游依据

以下 SDK 路径相对于本机 API 26 的 `openharmony/`，只读参考，不作为硬编码构建路径。

| 依据 | 结论 |
| --- | --- |
| `ets/api/@ohos.app.form.FormExtensionAbility.d.ts` | 提供卡片添加、更新、事件和删除生命周期 |
| `ets/api/@ohos.app.form.formProvider.d.ts` | `updateForm`；API 18 起可用 `openFormManager`；下一次刷新最短 5 分钟 |
| `toolchains/modulecheck/forms.json` | `2*2`/`2*4`/`4*4` 规格、自动主题、30 分钟为单位的周期刷新配置 |
| `ets/api/@ohos.bundle.bundleManager.d.ts`、`bundleManager/BundleInfo.d.ts` | API 26 备用图标设置与当前启用状态 |
| `ets/api/@ohos.deviceInfo.d.ts` | 本轮选用的 13 项设备常量均从 API 6 起公开可用，不需要设备标识权限 |
| `toolchains/modulecheck/app.json` | `alternateIcons` 的 `name`/`icon` 配置 |
| 根 `lib/services/widget_update_service.dart`、`lib/injection/injector.dart` | 现有卡片防抖、更新回调与 DI 接入位置 |
| 安卓 `CourseGlanceWidget.kt` 的 `WidgetDataLoader`、`UnifiedWidget`、`CourseCard` | 当前课表筛选、明天/假期/空状态、统一自适应布局、完整滚动列表、课程状态与视觉样式 |
| 安卓 `res/xml/widget_small_info.xml`、`widget_medium_info.xml`、`widget_large_info.xml` | Small 2×2、Medium 4×2、Large 4×4 的初始网格规格，均支持调整大小 |
| 安卓 `res/values/colors.xml`、`values-night/colors.xml` 和本地化 strings | 卡片深浅配色、明天课程灰色层级与展示文案 |
| SDK `ets/component/list.d.ts`、`ets/build-tools/ets-loader/form_components/list.json` | ArkUI List 的卡片支持及滚动相关属性，作为完整列表的原生实现依据 |
| SDK `ets/component/common.d.ts`、`ets/build-tools/ets-loader/form_components/common_attrs.json` | `onSizeChange` 从 API 12 起支持服务卡片，用于获取实际宽高；`onAreaChange` 不支持服务卡片 |
| 根 `lib/services/dynamic_icon_service.dart`、`lib/pages/settings/set_app_icon_page.dart` | 图标通道接口和既有页面 |

## 6. 审核与完成标准

- [x] 用户明确授权开始第五阶段，课表卡片按安卓实际行为对齐。
- [x] 动态图标代码完成，已获用户验收确认。
- [x] 课表服务卡片代码完成，已获用户验收确认。
- [x] 鸿蒙图标切换确认去掉重启文案，开发者页设备信息、完整复制及失败重试代码完成。
- [x] 更新能力矩阵和开发说明，未验证项保持未勾选。
- [x] 用户确认第五阶段构建与功能验收无问题；代码生成、格式、分析的持续检查在阶段六跟踪。
- [x] 真机确认旧图标/默认图标切换、当前选择状态、手动重启后的状态保持及失败提示；确认文案不再提示重启，按用户第五阶段整体验收反馈标记。
- [x] 三种卡片尺寸与安卓对照的布局、滚动、点击、深浅配色和上课中状态：按用户小组件完成反馈标记。
- [x] 课表切换/清空、单双周、跨日、明天/假期/空态、多实例及系统刷新：按用户小组件完成反馈标记。
- [x] 真机确认环境页设备字段与当前设备相符，复制内容包含 APP/Environment/Flag/Build/Device；读取失败可重试，退出后无异步 UI 报错，按用户第五阶段整体验收反馈标记。
- [x] 开发者页 UI Preview 入口已移除，按用户第五阶段整体验收反馈标记。

## 7. 本轮实现记录

原生入口保留已有 ICS 通道，同时注册图标、设备信息和卡片数据通道；FlutterEngine 清理时释放通道。

| 文件或补丁 | 职责 |
| --- | --- |
| `entry/src/main/ets/platform/DynamicIconChannel.ets` | 读取系统启用图标，API 26 备用图标切换，重复请求返回忙碌 |
| `entry/src/main/ets/platform/EnvironmentInfoChannel.ets` | 读取公开设备常量，通过标准 Map 返回设备与系统环境信息 |
| `entry/src/main/ets/cards/CourseCardModel.ets` | 展示结构、格式校验、课程日期/状态/明天/假期计算；无 Flutter 或文件 API |
| `entry/src/main/ets/cards/CourseCardStore.ets` | 私有快照、原子写入、独立实例记录及系统刷新 |
| `entry/src/main/ets/cards/CourseFormAbility.ets` | 添加、更新、转正式卡片及删除生命周期 |
| `entry/src/main/ets/cards/CourseCard.ets` | 按实际宽高调整布局，完整 List、课程色、系统深浅资源及点击打开应用 |
| `entry/src/main/ets/cards/CourseCardChannel.ets` | 串行接收快照、刷新各实例、打开系统卡片管理 |
| `0019-ohos-dynamic-icon.patch` | 启用现有图标服务和设置项；原生通道缺失不伪报切换成功 |
| `0020-ohos-course-cards.patch` | 快照生成、启动/前台/课表/设置同步、系统管理入口及中英文文案 |
| `0021-ohos-environment-info.patch` | 补齐设备查询、环境页读取与复制/重试，避免未初始化的设备分类断言 |
| `0022-ohos-icon-confirmation.patch` | 鸿蒙中英文图标切换确认仅询问是否切换，不再提示应用重启 |
| `0023-ohos-remove-ui-preview.patch` | 移除开发者页 UI Preview 入口、对应分隔线及 import |
| `0024-ohos-icon-api-gate.patch` | 点击图标入口时检查 API；低于 26 提示鸿蒙 7 以下不支持并阻止进入 |

快照 `schemaVersion=1` 保存在应用私有 `filesDir/course_cards/snapshot-v1.json`；
文件最大 2 MiB，最多 5000 条课程记录、60 个教学周，异常数据回退同步提示。
每条课程包含星期和由上游 `Course.isActiveInWeek()` 计算的有效周列表，避免在原生重复单双周规则；
只保存名称、地点、节次、起止分钟及颜色，不保存教师或认证信息。
课表快照不设置任意天数的过期清除，允许长期离线显示已同步学期；未知版本或无效格式视为不可读。
卡片绑定数据只发送当前日期所需的课程。每个实例以独立 `.form` 文件记录，删除不会重写共享索引。

默认图标保留，备用 `old` 资源直接复制上游 `assets/icon_old.png`。
卡片颜色位于 `resources/base/element/color.json` 和 `resources/dark/element/color.json`，
文案支持中文和英文，卡片随系统切换深浅资源，应用不必驻留。

`ohos/tool/ohos_patches.py` 为新增文案允许两个精确的 ARB 目标：
`lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`，仅在隔离副本处理；
`app_zh_Hans_CN.arb` 和根源码不修改，生成本地化仍由既有构建入口完成。

系统卡片刷新以 30 分钟为基础，临近课程边界时申请最短 5 分钟的刷新，实际时间服从系统调度。

课表卡片先按用户“小组件也补齐了”的反馈标记；随后用户确认“第五阶段没有问题了”，
第五阶段其余功能验收据此勾选，整体标为完成。以上为用户验收记录，代理未执行构建或测试，
也未另行记录逐项命令结果；持续检查与双 SDK 验证继续在阶段六开展。

## 8. 构建问题修复记录

2026-09-16 用户构建副本 `run-53hzz0qa` 在 `entry:default@CompileArkTS` 失败。
Hvigor 日志明确记录 `11706006: 'onAreaChange' can't support form application`，
位置为卡片布局 `CourseCard.ets`。Flutter 的 `ProcessException` 是这次编译失败的外层报告；
Android SDK / Visual Studio 的 doctor 提示不是这次 HAP 失败原因。

已将布局测量改为 SDK 明确支持卡片的 `onSizeChange` 和 `SizeOptions`，
仅在收到有效且变化的宽高时更新布局状态，继续按实际空间适配三种规格和完整课程列表。
修复时只修改维护目录中的源码并核对 SDK 声明，未执行构建或测试。
用户随后确认小组件已补齐，课表卡片验收据此标记完成。
