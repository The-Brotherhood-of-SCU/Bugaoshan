import 'dart:async';

import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/reminder/live_activity_service.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/semester_week.dart';
import 'package:flutter/material.dart';

/// 当前进行中课程与后续课程解析结果快照。
///
/// 封装课程解析状态以解耦业务计算与活动生命周期调度，并支持独立单元测试。
@immutable
class LiveCourseSnapshot {
  /// 当前进行中的课程，无进行中课程时为 null。
  final Course? current;

  /// 当前课程的上课时刻与下课时刻。
  final DateTime? startAt;
  final DateTime? endAt;

  /// 当天后续最近的一节课程，无后续课程时为 null。
  final Course? next;

  /// 下一节课程开始时刻。
  final DateTime? nextStartAt;

  /// 当前课程会话的稳定标识，[current] 为 null 时为 null。
  ///
  /// 用于判断两次解析结果是否指向同一节课。课程名不足以承担这一判断：同一天
  /// 两节同名的课（如两节「体育」）名称相同但起止节次不同。若仅按名称比对，
  /// 第二节不会触发状态下发，倒计时将停留在第一节的结束时刻。
  final String? sessionKey;

  const LiveCourseSnapshot({
    this.current,
    this.startAt,
    this.endAt,
    this.next,
    this.nextStartAt,
    this.sessionKey,
  });

  static const LiveCourseSnapshot empty = LiveCourseSnapshot();

  bool get hasCurrent => current != null;
}

/// 当前课程状态解析器。纯函数设计：无时钟依赖（基准时间 [now] 显式注入）、不访问存储且不抛出异常。
///
/// 遵循与 [ReminderPlanBuilder] 一致的周次判定规则（校历周日成行口径）与
/// [Course.isActiveInWeek] 活跃性判定，保证业务计算口径统一。
class LiveCourseResolver {
  const LiveCourseResolver._();

  static LiveCourseSnapshot resolve({
    required List<Course> courses,
    required ScheduleConfig? config,
    required DateTime now,
  }) {
    if (config == null || courses.isEmpty) return LiveCourseSnapshot.empty;

    final today = DateTime(now.year, now.month, now.day);
    final semesterStart = config.semesterStartDate;
    if (today.isBefore(
      DateTime(semesterStart.year, semesterStart.month, semesterStart.day),
    )) {
      return LiveCourseSnapshot.empty;
    }
    final week = courseWeekOf(semesterStart, today);
    if (week < 1 || week > config.totalWeeks) return LiveCourseSnapshot.empty;

    final todayCourses = <Course>[];
    for (final course in courses) {
      if (course.dayOfWeek != today.weekday) continue;
      if (!course.isActiveInWeek(week)) continue;
      if (_startAt(config, course, today) == null) continue;
      todayCourses.add(course);
    }
    if (todayCourses.isEmpty) return LiveCourseSnapshot.empty;

    Course? current;
    DateTime? currentStartAt;
    DateTime? endAt;
    for (final course in todayCourses) {
      final start = _startAt(config, course, today)!;
      final end = _endAt(config, course, today);
      if (end == null) continue;
      // 采用左闭右开区间 [start, end) 进行匹配：到达下课时刻即视为已结束，
      // 避免实时活动在下课后短暂残留为剩余 0:00 的结束倒计时。
      if (!now.isBefore(start) && now.isBefore(end)) {
        current = course;
        currentStartAt = start;
        endAt = end;
        break;
      }
    }

    Course? next;
    DateTime? nextStartAt;
    for (final course in todayCourses) {
      final start = _startAt(config, course, today)!;
      if (!start.isAfter(now)) continue;
      if (nextStartAt == null || start.isBefore(nextStartAt)) {
        next = course;
        nextStartAt = start;
      }
    }

    // 「下节」只保留在当前课程结束之后才开始的课。开始时刻落在当前课程区间内的课
    // （课表冲突，或同一门课被录入成多条重叠记录）不构成「下节」：它与下课倒计时
    // 互相矛盾，界面会同时显示「距下课 20 分钟」与「下一节已开始」。
    if (current != null &&
        nextStartAt != null &&
        !nextStartAt.isAfter(endAt!)) {
      next = null;
      nextStartAt = null;
    }

    // 同一天内可能存在内容相同的多条记录（如按周段拆分录入）。以课程名与起止节次
    // 组合成会话标识，保证同一节课的判定稳定，同时能区分起止节次不同的同名课程。
    final sessionKey = current == null
        ? null
        : '${current.name}|${current.startSection}-${current.endSection}';

    return LiveCourseSnapshot(
      current: current,
      startAt: currentStartAt,
      endAt: endAt,
      next: next,
      nextStartAt: nextStartAt,
      sessionKey: sessionKey,
    );
  }

  static DateTime? _startAt(
    ScheduleConfig config,
    Course course,
    DateTime day,
  ) {
    final slot = _slotOf(config, course.startSection);
    if (slot == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      slot.startTime.hour,
      slot.startTime.minute,
    );
  }

  static DateTime? _endAt(ScheduleConfig config, Course course, DateTime day) {
    final slot = _slotOf(config, course.endSection);
    if (slot == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      slot.endTime.hour,
      slot.endTime.minute,
    );
  }

  static TimeSlot? _slotOf(ScheduleConfig config, int section) {
    if (section < 1 || section > config.timeSlots.length) return null;
    return config.timeSlots[section - 1];
  }
}

/// 课程实时活动（Live Activity）生命周期协调器。
///
/// 负责将当前课程快照转换为实时活动的 start、update 与 end 操作。
///
/// 平台约束与调度策略：
/// 1. 前台启动约束（ActivityKit 系统限制）：实时活动仅允许在应用处于前台活跃状态时启动，
///    因此生命周期由前台唤醒事件与课表数据变更驱动，而非后台定时任务；
/// 2. 进程依赖约束：未启动过应用时系统无法自动激活活动；
/// 3. 系统级倒计时渲染：剩余时间倒计时由系统组件基于时间区间独立渲染，
///    本服务仅在课程发生切换或状态实质性变更时触发同步，不维持分钟级更新心跳。
class LiveActivityCoordinator {
  LiveActivityCoordinator({
    required CourseProvider courseProvider,
    LiveActivityService? service,
    Duration? pollInterval,
  }) : _courseProvider = courseProvider,
       _service = service ?? LiveActivityService(),
       _pollInterval = pollInterval ?? const Duration(seconds: 60);

  final CourseProvider _courseProvider;
  final LiveActivityService _service;
  final Duration _pollInterval;

  Timer? _timer;
  bool _running = false;
  bool _disposed = false;

  /// 当前活跃会话的标识（[LiveCourseSnapshot.sessionKey]）。用于判断是否需要下发
  /// 状态更新，避免前台恢复事件重复调用原生 update 产生无谓的系统开销。
  String? _activeSessionKey;

  /// 当前运行环境是否可用。在非 iOS 环境或用户关闭实时活动后标记为不可用，
  /// 避免后续重复触发通道调用并输出冗余日志。
  bool _available = true;

  bool get isActive => _activeSessionKey != null;

  /// 启动协调器调度。在非 iOS 平台时将捕获 [LiveActivityUnsupportedException] 并自动禁用后续调度。
  Future<void> start() async {
    if (_disposed || _running) return;
    _running = true;
    _available = await _service.isSupported();
    if (!_available) {
      AppLog.d('LiveActivity', '当前设备不支持实时活动，协调器停用');
      return;
    }
    _courseProvider.courses.addListener(_onSourceChanged);
    _courseProvider.scheduleConfig.addListener(_onSourceChanged);
    // 定时轮询仅用于在应用处于前台时发现课程结束并结束活动；
    // 课程切换由课表数据监听覆盖，应用恢复前台由生命周期监听覆盖。
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(tick()));
    await tick();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    if (_running) {
      _courseProvider.courses.removeListener(_onSourceChanged);
      _courseProvider.scheduleConfig.removeListener(_onSourceChanged);
    }
    _running = false;
  }

  void _onSourceChanged() => unawaited(tick());

  /// 根据当前时间评估课程状态，执行活动启动、更新或结束的生命周期对齐。
  Future<void> tick() async {
    if (_disposed || !_available) return;

    final snapshot = LiveCourseResolver.resolve(
      courses: _courseProvider.courses.value,
      config: _courseProvider.scheduleConfig.value,
      now: DateTime.now(),
    );

    try {
      final current = snapshot.current;
      if (current == null) {
        // 无进行中课程（课间或当日课程已结束）：结束当前会话。后续调度匹配到新课程时将重新启动。
        if (_activeSessionKey != null) await _end();
        return;
      }

      if (_activeSessionKey == snapshot.sessionKey) return;

      final next = snapshot.next;
      if (_activeSessionKey == null) {
        await _service.start(
          courseName: current.name,
          location: current.location,
          startAt: snapshot.startAt,
          endAt: snapshot.endAt!,
          nextCourseName: next?.name,
          nextLocation: (next?.location.isEmpty ?? true)
              ? null
              : next!.location,
        );
      } else {
        // 课程切换时复用既有会话下发更新，而非重建会话，避免锁屏与灵动岛界面出现闪烁。
        await _service.update(
          courseName: current.name,
          location: current.location,
          startAt: snapshot.startAt,
          endAt: snapshot.endAt,
          nextCourseName: next?.name,
          nextLocation: (next?.location.isEmpty ?? true)
              ? null
              : next!.location,
        );
      }
      _activeSessionKey = snapshot.sessionKey;
    } on LiveActivityUnsupportedException catch (e) {
      AppLog.d('LiveActivity', '设备不支持，停止后续尝试：$e');
      _available = false;
    } on LiveActivityNotAuthorizedException catch (e) {
      // 用户在系统设置中关闭了实时活动权限。结束当前会话但不记为错误，
      // 后续前台唤醒时重新检测，权限恢复后即可继续下发。
      AppLog.d('LiveActivity', '用户未开启实时活动：$e');
      await _end(swallowErrors: true);
    } on LiveActivityForegroundRequiredException catch (e) {
      // 应用非前台活跃状态，跳过本轮调度。
      AppLog.d('LiveActivity', '非前台，跳过本轮：$e');
    } on LiveActivityNoActiveSessionException {
      // 原生端活跃会话已不存在（如被用户手动划掉），重置本地状态以便下轮重新创建。
      _activeSessionKey = null;
    } catch (e) {
      AppLog.w('LiveActivity', '同步实时活动失败：$e');
    }
  }

  Future<void> _end({bool swallowErrors = false}) async {
    _activeSessionKey = null;
    try {
      await _service.end();
    } catch (e) {
      if (!swallowErrors) AppLog.w('LiveActivity', '结束实时活动失败：$e');
    }
  }
}
