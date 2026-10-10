# ADR-0008：提醒排期在 Dart 预计算，原生只按表投递

- 状态：已接受并实施
- 决策日期：2026-10-07

## 背景

桌面小组件（Android Glance / iOS·macOS WidgetKit）暴露了一个已发生过的问题：课程查询、教学周换算、放假判定这些业务规则在 Dart、Kotlin、Swift 里各实现了一遍。任何规则变更要同步三处，且平台代码不在 Dart 测试覆盖范围内——ADR-0006 记的那次「周日起点的学期里小组件把周日的课查早一周」正是这种漂移的产物。

issue #358 提出新增本地提醒（课前提醒等）。提醒比小组件更进一步：它需要精确到分钟地决定「什么时候弹」，如果沿用「原生自己算」的路线，这套业务逻辑会出现第四份实现，而且这份实现直接决定用户会不会迟到。

## 决策

**提醒的「何时提醒」完全在 Dart 计算，原生层只负责在给定时刻投递一次。**

1. `ReminderPlanBuilder`（`lib/services/reminder/reminder_plan_builder.dart`）是纯函数：输入课表 + 设置 + `now`，输出绝对时刻的提醒列表。不读时钟、不碰存储、不抛异常。
2. 产物经 `ReminderPlan.toChannelPayload()` 跨 `bugaoshan/reminder` channel 下发。**所有时刻都是 epoch 毫秒整数**，不带 ISO 字符串——原生侧不需要、也不允许做时区换算。
3. 原生层不实现任何课程/周次/假期推断。它只保证「在 `fireAtMillis` 附近投递一次」。
4. 下发是**全量替换**：原生按标识前缀撤销上一批，再登记新一批。计划里没有的 `id` 自然消失，因此 Dart 侧不需要做增量 diff。
5. 计划内容哈希（`planId`）不变时短路，避免每次前台恢复都惊动系统调度器。

## 理由

1. **可测试性**：排期逻辑是纯函数，能对着固定日期做完整断言。教学周口径（ADR-0006）、离散周次、单双周、免打扰、平台条数上限都在 Dart 单测里覆盖，不必依赖真机。
2. **规则只有一处**：改「提前量」的语义或增加新的提醒类型，只改 Dart。
3. **原生层可替换**：Android 与 iOS 各自只需实现「读表 → 投递」，两端行为差异被限制在投递机制本身（精确闹钟权限、Doze 限频），而不是业务规则。

## 后果

正面影响：

- 排期逻辑可完整单测；教学周口径不会在原生侧再次漂移。
- 新增平台（如上海外平台的桌面端）只需实现投递。

代价与约束：

- **原生侧必须持久化计划**（Android 用 SharedPreferences、iOS 用落盘摘要），否则进程重启后无法重建排期。
- **窗口长度成为显式权衡**：iOS 只保留每个应用最近的 64 条待投递通知，窗口越长越容易被系统丢弃。默认 7 天并由 `ReminderPlanBuilder` 按 `maxReminders` 裁剪，被裁条数记入 `droppedCount` 并展示出来——静默截断会读成「功能坏了」。
- **iOS 没有后台重算的保证**：`BGTaskScheduler` 由系统择机调度，不像 Android 有 `BOOT_COMPLETED` 这类确定性事件。窗口走完后若用户长期不开应用，就不会有后续提醒。这是方案已知的最弱一环。
- 提醒会显示在锁屏上，因此正文必须与既有隐私开关同源（`showTeacherName` / `showLocation`），见 `AppConfigProvider.reminderSettings`。

## 相关实现

- `lib/models/reminder_plan.dart`、`lib/services/reminder/reminder_plan_builder.dart`、`lib/services/reminder/reminder_service.dart`、`lib/services/reminder/reminder_transport.dart`
- `ios/Runner/ReminderChannel.swift`（iOS 投递端）
- Android 投递端见 issue #359（原型，未验证）
- `lib/pages/settings/reminder_setting_page.dart`（设置界面）
- 上游讨论：issue #358（本决策）、#253 / #254（小组件架构重构，同一思路的来源）
