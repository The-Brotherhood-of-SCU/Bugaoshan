import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/utils/semester_week.dart';
import 'package:flutter/material.dart';

/// 提醒通知文本生成接口。
///
/// 解耦文案构建以保证 [ReminderPlanBuilder] 维持无副作用纯函数特性。
/// 生产环境注入基于 `AppLocalizations` 的本地化实现，测试环境可使用 [DefaultReminderNarrator] 或测试桩。
abstract class ReminderNarrator {
  /// 生成通知标题，默认使用课程名称。
  String titleFor(Course course);

  /// 生成通知正文内容。
  ///
  /// 地点与教师字段受 [withLocation] 与 [withTeacher] 控制，
  /// 配置源须与应用全局隐私设置保持一致，确保系统锁屏等外部展示遵循隐私限制。
  String bodyFor({
    required Course course,
    required TimeSlot slot,
    required bool withLocation,
    required bool withTeacher,
  });
}

/// 默认中文文案生成器，不依赖应用本地化上下文。生产环境应注入基于 `AppLocalizations` 的实现。
class DefaultReminderNarrator implements ReminderNarrator {
  const DefaultReminderNarrator();

  @override
  String titleFor(Course course) => course.name;

  @override
  String bodyFor({
    required Course course,
    required TimeSlot slot,
    required bool withLocation,
    required bool withTeacher,
  }) {
    final buffer = StringBuffer(_hhmm(slot.startTime));
    if (withLocation && course.location.isNotEmpty) {
      buffer.write(' · ${course.location}');
    }
    if (withTeacher && course.teacher.isNotEmpty) {
      buffer.write(' · ${course.teacher}');
    }
    return buffer.toString();
  }

  static String _hhmm(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

/// 将课表数据展开计算为具有绝对时间戳的提醒排期计划。
///
/// 本类为纯函数设计：无外部时钟依赖、不访问持久化存储且不抛出异常。
/// 给定相同输入保证生成确定性输出，便于单元测试验证。
///
/// 时间与周次展开规范：
/// - 教学周与自然日的映射遵循 [courseWeekOf]（校历周日成行规则），禁止使用固定的 7 天周期换算；
/// - 课程在指定周次的活跃性判断统一调用 [Course.isActiveInWeek]，覆盖离散周次 `customWeeks` 的判定逻辑；
/// - 节次与具体时刻的映射读取 [ScheduleConfig.timeSlots]。
///
/// 注：不调用 `selectVisibleCoursesForDay`，避免其包含未来周次占位课程而在非活跃周次产生误触发。
class ReminderPlanBuilder {
  const ReminderPlanBuilder._();

  /// 构建提醒排期计划。
  ///
  /// - [now]：基准时间，由调用方显式注入以避免隐式时钟依赖。
  /// - [maxReminders]：非空时按触发时间升序保留最近项，超出上限被截断的数量记录于
  ///   [ReminderPlan.droppedCount]。iOS 平台需传入
  ///   [ReminderSettings.iosPendingNotificationLimit]。
  /// - [config] 为 null（未配置课表）时返回空排期计划，不抛出异常。
  static ReminderPlan build({
    required List<Course> courses,
    required ScheduleConfig? config,
    required ReminderSettings settings,
    required DateTime now,
    ReminderNarrator narrator = const DefaultReminderNarrator(),
    String channel = defaultChannel,
    int? maxReminders,
  }) {
    final generatedAt = now;
    final firstDay = DateTime(now.year, now.month, now.day);
    final windowEnd = firstDay.add(Duration(days: settings.windowDays));

    if (config == null || !settings.courseReminderEnabled || courses.isEmpty) {
      return compose(
        reminders: const [],
        generatedAt: generatedAt,
        windowStart: firstDay,
        windowEnd: windowEnd,
        channel: channel,
      );
    }

    final leads = settings.normalizedLeadMinutes;
    final semesterStart = config.semesterStartDate;
    final byId = <String, ReminderItem>{};

    for (var offset = 0; offset < settings.windowDays; offset++) {
      final day = firstDay.add(Duration(days: offset));
      if (day.isBefore(
        DateTime(semesterStart.year, semesterStart.month, semesterStart.day),
      )) {
        continue;
      }
      // 假期阶段 courseWeekOf 返回值超出总周数，超出范围的日期直接跳过。
      final week = courseWeekOf(semesterStart, day);
      if (week > config.totalWeeks) continue;

      final dayOfWeek = day.weekday; // 1=周一 .. 7=周日，与 Course.dayOfWeek 取值范围一致
      for (final course in courses) {
        if (course.dayOfWeek != dayOfWeek) continue;
        if (!course.isActiveInWeek(week)) continue;

        final slot = _slotOf(config, course.startSection);
        if (slot == null) continue;

        final startAt = DateTime(
          day.year,
          day.month,
          day.day,
          slot.startTime.hour,
          slot.startTime.minute,
        );

        for (final lead in leads) {
          final fireAt = startAt.subtract(Duration(minutes: lead));
          if (!fireAt.isAfter(now)) continue;
          if (fireAt.isAfter(windowEnd)) continue;
          if (settings.isQuiet(
            TimeOfDay(hour: fireAt.hour, minute: fireAt.minute),
          )) {
            continue;
          }

          final item = ReminderItem(
            id: _reminderId(course, day, course.startSection, lead),
            kind: ReminderKind.courseStart,
            fireAt: fireAt,
            title: narrator.titleFor(course),
            body: narrator.bodyFor(
              course: course,
              slot: slot,
              withLocation: settings.includeLocation,
              withTeacher: settings.includeTeacher,
            ),
            // 聚合折叠键按「课程 + 日期」维度划分：仅将同一课程同日的多个提前提醒聚合，
            // 避免仅按日期聚合导致当日不同课程的通知合并在同一通知组中。
            collapseKey: 'course:${_courseKey(course)}:${_yyyymmdd(day)}',
          );
          // 数据库中同课程可能按周段分拆为多条记录，相同唯一标识的项执行覆盖去重。
          byId[item.id] = item;
        }
      }
    }

    return compose(
      reminders: byId.values,
      generatedAt: generatedAt,
      windowStart: firstDay,
      windowEnd: windowEnd,
      channel: channel,
      maxReminders: maxReminders,
    );
  }

  /// 基于指定的提醒集合组装排期计划。[build] 与本方法共享相同的
  /// 「时间排序 -> 容量截断 -> 特征哈希」管线，确保生成的计划均满足全量替换契约。
  ///
  /// 此方法公开用于支持增量提醒合成：在既有计划基础上追加新条目后，
  /// 统一以全量覆盖方式同步至原生宿主，避免误撤销历史排期。
  static ReminderPlan compose({
    required Iterable<ReminderItem> reminders,
    required DateTime generatedAt,
    required DateTime windowStart,
    required DateTime windowEnd,
    String channel = defaultChannel,
    int? maxReminders,
  }) {
    final all = reminders.toList()
      ..sort((a, b) {
        // 触发时间相同时按 ID 二次排序，保证排序稳定性，避免相同数据集计算出不同的 planId。
        final byTime = a.fireAt.compareTo(b.fireAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    // 非正数容量视为不设上限，避免负数索引导致 RangeError。保持纯函数异常安全约定。
    final limit = maxReminders != null && maxReminders > 0
        ? maxReminders
        : null;
    final dropped = limit != null && all.length > limit
        ? all.length - limit
        : 0;
    final kept = dropped > 0 ? all.sublist(0, limit) : all;

    return ReminderPlan(
      planId: _planId(kept, windowEnd, channel),
      generatedAt: generatedAt,
      windowStart: windowStart,
      windowEnd: windowEnd,
      channel: channel,
      reminders: kept,
      droppedCount: dropped,
    );
  }

  /// 默认通知渠道标识。
  static const String defaultChannel = 'bugaoshan_reminder';

  static TimeSlot? _slotOf(ScheduleConfig config, int section) {
    if (section < 1 || section > config.timeSlots.length) return null;
    return config.timeSlots[section - 1];
  }

  /// 生成提醒唯一标识：课程名 + 日期 + 起始节次 + 提前量。
  ///
  /// 基于业务属性生成确定性标识，而不依赖 [Course.id]。
  /// 因 [Course.id] 重新导入课表时会重新生成，使用动态 ID 会导致相同课程在重排时被误判为新通知而重复投递。
  static String _reminderId(
    Course course,
    DateTime day,
    int startSection,
    int leadMinutes,
  ) => 'course:${course.name}:${_yyyymmdd(day)}:$startSection:$leadMinutes';

  static String _yyyymmdd(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// 聚合折叠键中的课程标识，遵循提醒 ID 命名规则。
  static String _courseKey(Course course) => course.name;

  /// 计算计划特征哈希（包含提醒内容与有效时间窗口）。
  ///
  /// 时间窗口纳入哈希计算：当提醒列表未变但覆盖时间窗口滚动推移时，
  /// 必须下发新计划以更新原生端的有效截止时间 windowEnd，防止原生端提前停止投递。
  static String _planId(
    List<ReminderItem> reminders,
    DateTime windowEnd,
    String channel,
  ) => planContentHash([
    ...reminders,
    ReminderItem(
      id: '_window:$channel',
      kind: ReminderKind.courseStart,
      fireAt: windowEnd,
      title: '',
      body: '',
      collapseKey: '',
    ),
  ]);
}
