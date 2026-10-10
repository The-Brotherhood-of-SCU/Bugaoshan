# 本地提醒 Android 侧原生实现与架构设计

> 文档状态：设计说明与原型架构
> 
> **重要警告**：本模块目前为**设计与原型实现**，开发环境中未配置 Android 实机与模拟器测试环境，**未经真机编译与运行验证**。所有产出代码仅完成了静态结构对齐，部署前必须经由真实 Android 设备进行完整测试（测试项详见第 5 节）。

---

## 1. 概述与核心契约

本地提醒系统（Issue #358）负责在课前向用户发出系统通知。系统整体采用「Dart 侧纯函数计算绝对时刻 + 原生侧哑执行（Dumb Transport）」的分层架构：

- **Dart 侧（已实现并测试）**：负责课程、周次、提前量、免打扰时段的计算，生成包含绝对时刻（Epoch 毫秒 `fireAtMillis`）的 `ReminderPlan`；
- **Android 原生侧（本设计）**：通过 MethodChannel `bugaoshan/reminder` 接收指令，利用系统 `AlarmManager` 和 `NotificationManager` 完成定时排期、唤醒和横幅投递，原生侧不参与任何课程业务逻辑推断。

### MethodChannel 契约映射

| 方法名 | 参数 | 返回值 | 语义与 Android 端处理 |
|---|---|---|---|
| `syncPlan` | `Map<String, Any?>` (由 `ReminderPlan.toChannelPayload()` 生成) | `void`（失败抛 PlatformException） | **全量替换**：撤销上一批闹钟，持久化新计划，为未来提醒重新排期。未授权时返回 `NOT_AUTHORIZED`，不支持的 schema 返回 `UNSUPPORTED_SCHEMA`。 |
| `cancelAll` | 无 | `void` | 撤销所有已登记闹钟，清空持久化存储。 |
| `requestAuthorization` | `{"provisional": bool}` | `bool` | 申请 `POST_NOTIFICATIONS` 运行时权限（Android 13+）。Android 忽略 `provisional` 参数。 |
| `getPermissionStatus` | 无 | `String` | 返回 `authorized` / `denied` / `notDetermined` / `unknown`。Android 侧根据运行时权限与设置项状态映射。 |
| `getPendingCount` | 无 | `int` | 返回当前系统中有效且待触发的提醒条数（从本地持久化中核对未来时刻计算得出）。 |
| `openNotificationSettings` | 无 | `bool` | 跳转到系统的「应用通知设置」子页面（失败时降级到应用详情页）。 |

---

## 2. 模块结构与职责划分

代码位于 `android/app/src/main/kotlin/io/github/the_brotherhood_of_scu/bugaoshan/reminder/`：

```
reminder/
├── ReminderChannel.kt         # MethodChannel 适配入口，响应 Dart 请求，处理权限返回与参数校验
├── ReminderScheduler.kt       # 排期引擎：AlarmManager 闹钟注册/撤销、降级处理、SharedPreferences 落盘
├── ReminderAlarmReceiver.kt   # 闹钟触发 BroadcastReceiver：权限兜底、Doze 积压合并补偿、触发投递
├── ReminderNotification.kt    # 通知管理：创建独立高优先级通知渠道、构建并展示 heads-up 通知
└── ReminderBootReceiver.kt     # 系统广播接收器：开机/更新/时间变更后自动从存储中重建排期
```

---

## 3. 平台约束与应对策略

Android 平台的后台机制与定时任务在近几个大版本中有极强的限制和碎片化。下表梳理了核心约束及本原型的应对方案：

| 约束维度 | 平台机制与行为表现 | 对课前提醒的影响 | 本原型应对策略 |
|---|---|---|---|
| **精确闹钟权限 (SCHEDULE_EXACT_ALARM)** | Android 12 (API 31) 引入；**Android 14 (API 34) 起系统默认对非日历/闹钟类 App 不授予**。 | 若未获得授权直接调用 `setExactAndAllowWhileIdle()`，系统会直接抛出 `SecurityException` 导致 App 崩溃。 | 1. 排期前调用 `canScheduleExactAlarms()` 检查；<br>2. 支持时使用精确闹钟；<br>3. 不支持时**自动平滑降级**为 `setAndAllowWhileIdle()`，打印 Warning 日志并记录降级标记到存储；<br>4. 捕获潜在 `SecurityException` 兜底。 |
| **低电耗模式 (Doze Mode)** | 设备静止且灭屏一段时间后进入 Doze。即使使用 `*AndAllowWhileIdle`，系统也有唤醒频次上限（约 **9~15 分钟** 允许唤醒一次）。 | 若单个课程设置了多个密集提前量（如 15 分钟与 10 分钟），第二个闹钟可能被系统推迟到下一次窗口，无法准点提醒。 | 1. **时刻合并**：同一时刻（毫秒级）的多条提醒合并为单一 `AlarmManager` 闹钟，避免唤醒浪费；<br>2. **到期合并补发**：`ReminderAlarmReceiver` 触发时，扫描「<= 当前时刻 + 1分钟 且 在过去 2 小时内」的所有未投递条目集中补发，即使被 Doze 对齐推迟也不会漏掉。 |
| **重启与系统清理后闹钟丢失** | `AlarmManager` 登记的闹钟完全保存在内存/Linux 内核定时器中，**设备关机或重启后全部清空**；应用更新覆盖安装后也会被系统重置。 | 若重启后不恢复，未来所有提醒永久丢失，直到用户再次打开应用触发重排。 | 1. `ReminderScheduler` 将计划完整 JSON 持久化至 `SharedPreferences`；<br>2. `ReminderBootReceiver` 监听 `BOOT_COMPLETED`、`MY_PACKAGE_REPLACED`、`TIME_SET`、`TIMEZONE_CHANGED`，启动时从存储读取并重新向 `AlarmManager` 注册未来提醒。 |
| **运行时通知权限 (POST_NOTIFICATIONS)** | Android 13 (API 33) 起通知需要动态运行时授权；用户也可在系统设置中随时关闭整个应用或某个通知渠道。 | 权限被拒或关闭后，闹钟虽然能在后台触发，但通知栏无法弹出，造成「提醒已死」的假象。 | 1. `syncPlan` 执行前先校验 `areNotificationsEnabled()`，未授权时**直接返回 `NOT_AUTHORIZED`** 错误码阻断排期；<br>2. `ReminderAlarmReceiver` 唤醒时二次校验通知权限，避免无权限时做无用构建；<br>3. `requestAuthorization` 与 `getPermissionStatus` 提供精确的状态跟踪。 |
| **厂商 ROM 自启动与后台冻结** | 国内主流厂商（MIUI/HyperOS、ColorOS、OriginOS、EMUI/MagicOS 等）对后台广播和非白名单唤醒有极其激进的拦截。 | `BOOT_COMPLETED` 广播可能被系统拦截，导致开机无法重建；后台休眠时定时唤醒可能被推迟。 | 1. 复用项目中既有的 `BatteryOptimizationHandler` 引导用户忽略电池优化；<br>2. 在 Dev 调试页提供「系统实际登记条数（`getPendingCount`）」探针，供排查系统丢弃问题。 |

---

## 4. 与既有小组件调度的关系

### 4.1 现状分析

当前仓库在小组件模块已存在 `AlarmManager` 的使用（`io.github.the_brotherhood_of_scu.bugaoshan.widget.WidgetAlarmManager`）：
- **午夜跨天闹钟**：`REQUEST_CODE_MIDNIGHT = 20250101`，每天 00:00:01 唤醒更新组件；
- **课程边界闹钟**：`REQUEST_CODE_COURSE_BOUNDARY = 20250102`，最近下一节课开始/结束时刻唤醒更新组件；
- 目标 Receiver 为 `WidgetAlarmReceiver`。

### 4.2 冲突面分析与隔离机制

由于两者均依赖 `AlarmManager`，若 `PendingIntent` 区分不严密，可能导致：
1. **撤销覆盖**：调用 `alarmManager.cancel()` 时误将小组件的闹钟注销，或小组件注销了提醒闹钟；
2. **触发串线**：闹钟唤醒了错误的 Receiver。

**本原型采用的四重强隔离方案：**
1. **组件类名隔离**：提醒使用 `ReminderAlarmReceiver::class.java`，小组件使用 `WidgetAlarmReceiver::class.java`；
2. **Intent Action 隔离**：提醒声明独立 Action `io.github.the_brotherhood_of_scu.bugaoshan.action.REMINDER_ALARM`；
3. **Data URI 强隔离**：提醒的 `Intent.data` 设置为 `Uri.parse("bugaoshan-reminder://alarm/$fireAtMillis")`，确保在 `Intent.filterEquals()` 判断中绝对独立；
4. **RequestCode 空间隔离**：小组件使用固定编号 `20250101`、`20250102`，提醒使用 `0x52450000`（1380253696）高位掩码空间，两者数值范围完全不交叠。

### 4.3 架构演进建议（收敛到统一调度门面）

虽然当前通过命名空间和组件隔离解决了冲突，但长期看仍存在潜在问题：
- **资源浪费与 Doze 冲突**：小组件的「课程边界闹钟」与提醒的「课前 0 分钟提醒」时刻可能高度重合。系统在极短时间内连续收到两个唤醒请求，可能导致其中一个被 Doze 限频推迟。
- **系统事件监听冗余**：`widget.BootReceiver` 与 `reminder.ReminderBootReceiver` 同时监听 `BOOT_COMPLETED` 等 4 个相同 Action。

**未来建议演进方向：**
在后续重构中抽取统一的 `AppAlarmCoordinator`：
1. 统一管理应用内所有 `AlarmManager` 的注册与注销；
2. 实现**唤醒对齐（Wakeup Coalescing）**：若小组件刷新与课前提醒时刻差距在 1 分钟以内，合并为单一闹钟唤醒，并在广播处理中顺次分发给小组件与提醒模块；
3. 统一合并系统生命周期重启恢复。

---

## 5. Reviewer 真机测试验证清单

由于当前开发环境缺乏 Android 真机与完整 SDK 编译工具链，以下清单必须由具备 Android 真机环境的 Reviewer 逐项测试验证：

### 5.1 基础授权与权限流程
- [ ] **Android 13+ (API 33+) 首次授权**：在 Android 13 及以上设备上安装，触发提醒时是否正常弹出系统通知权限请求对话框；同意后 `getPermissionStatus` 是否返回 `"authorized"`。
- [ ] **权限被拒后的状态流转**：点击拒绝后，`getPermissionStatus` 是否正确返回 `"denied"`；再次同步计划是否正确捕获 `PlatformException(code: "NOT_AUTHORIZED")`。
- [ ] **系统设置跳转**：调用 `openNotificationSettings` 是否能准确跳转至该 App 的系统通知子页面；关闭通知后返回 App，状态是否同步更新。

### 5.2 Android 14 (API 34) 精确闹钟降级验证
- [ ] **默认未授权下的平滑降级**：在 Android 14 纯净设备上安装（系统设置中「闹钟和提醒」默认应为关闭），同步课前计划，观察 logcat 是否输出 `SCHEDULE_EXACT_ALARM permission not granted. Downgrading to setAndAllowWhileIdle` 警告，且**应用不发生 SecurityException 崩溃**。
- [ ] **手动开启精确闹钟后的表现**：在系统设置 -> 应用 -> 特殊应用权限 -> 闹钟和提醒 中授予本应用权限，再次同步计划，确认日志中 `exact=true`。

### 5.3 计划同步与全量覆盖（I2 语义）
- [ ] **新计划替换旧计划**：
  1. 同步计划 A（包含 10 分钟后提醒 A1，20 分钟后提醒 A2）；
  2. 随后同步计划 B（仅包含 15 分钟后提醒 B1，移除了 A1 和 A2）；
  3. 验证时刻 A1 到达时**不会弹出通知**，而 B1 到达时**正常弹出通知**。
- [ ] **清空全部计划 (`cancelAll`)**：
  同步计划后调用 `cancelAll()`，通过 `getPendingCount()` 验证返回值是否为 0，且后续不再有提醒弹出。

### 5.4 重启与系统事件恢复
- [ ] **关机重启恢复**：
  1. 下发一条 15 分钟后的课程提醒；
  2. 将手机重启；
  3. 重启完成后不打开 App，观察该提醒到达预定时间时是否依然能正常弹出横幅通知。
- [ ] **系统时钟/时区更改**：
  在手机设置中手动修改系统时间，验证 `ReminderBootReceiver` 是否正确触发，且未来的提醒没有错乱。

### 5.5 Doze 低电耗与后台压测
- [ ] **ADB 模拟 Doze 模式**：
  通过命令进入 Doze：
  ```bash
  adb shell dumpsys battery unplug
  adb shell dumpsys deviceidle step deep
  adb shell dumpsys deviceidle force-idle
  ```
  观察在设备处于深度 Doze 状态时，精确闹钟是否能正常点亮屏幕/唤醒设备并展示横幅。
- [ ] **密集提醒合并投递**：
  设置两个相同时间触发的提醒，验证触发时是否能同时投递两条通知，且通知栏通过 `collapseKey` 正确归类成组。

### 5.6 厂商 ROM 专项测试
- [ ] **HyperOS / MIUI（小米）**：验证开机自启动是否被限制，神隐模式/智能省电下是否会被延迟超过 15 分钟；
- [ ] **ColorOS（OPPO / 一加）**：验证后台冻结策略对闹钟的影响；
- [ ] **HarmonyOS（华为）**：验证应用熄屏后定时器精度。

---

## 6. 已知未决问题与风险备忘

1. **Android 14+ 精确闹钟权限用户引导链路**：
   目前当用户处于 Android 14 且没有 `SCHEDULE_EXACT_ALARM` 时，系统自动降级为不精确的 `setAndAllowWhileIdle`。不精确闹钟可能会有 5~15 分钟的延迟漂移。未来是否需要在设置页向用户提示「为了准时提醒，请开启精确闹钟权限」，并提供 `Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM` 专属跳转 Intent？
2. **Doze 模式下多提前量挤占的物理极限**：
   若用户同时配置了「提前 5 分钟」和「提前 15 分钟」，在深度 Doze 下系统硬件时钟唤醒间隔被强行拉大到 9~15 分钟，即使代码逻辑写了补发，第一条被推迟的提醒也可能在上课后才送达。这属于 Android 操作系统物理级电源策略约束，无法通过纯前台/普通后台应用绕过（除非使用前台常驻 Service，但这会破坏用户体验并增加耗电）。
3. **夏令时与跨时区本地时间解析**：
   目前 Dart 传给原生的是绝对时刻 Epoch 毫秒 `fireAtMillis`。若用户在开学期间跨越时区（如从东八区飞往其他时区），墙钟时间改变会导致基于原时区推导出的绝对时刻与现实中的上课时间错位。此时依赖用户重新打开 App 触发课表同步与重新排期。
