import 'dart:async';

import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/reminder/reminder_plan_builder.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:flutter/foundation.dart';

/// 提醒排期协调服务。
///
/// 监听课表数据与用户提醒配置的变更，重新计算排期计划并同步至原生宿主。
///
/// 架构约束：
/// - 单向通道：本服务与原生平台仅通过 [ReminderTransport] 交互，原生层不包含业务推断逻辑；
/// - 全量覆盖：每次同步均执行全量替换策略，避免增量 diff 在课程删除或周次调整时产生残留通知；
/// - 哈希短路：计划特征哈希未变化时直接短路返回，避免前台唤醒等高频事件触发冗余系统排期调度。
///
/// 依赖设计：
/// 监听 [CourseProvider] 的 ValueNotifier 字段而非复用 [CourseProvider.onCoursesChanged]，
/// 是由于后者为单一回调，已在依赖注入层由桌面小组件更新服务占用，二次赋值会导致小组件数据同步失效。
class ReminderService {
  ReminderService({
    required CourseProvider courseProvider,
    required AppConfigProvider appConfig,
    required ReminderTransport transport,
    Duration? debounceDuration,
  }) : _courseProvider = courseProvider,
       _appConfig = appConfig,
       _transport = transport,
       _debounceDuration =
           debounceDuration ?? const Duration(milliseconds: 800);

  final CourseProvider _courseProvider;
  final AppConfigProvider _appConfig;
  final ReminderTransport _transport;
  final Duration _debounceDuration;

  /// 最近一次成功同步的计划哈希标识，用于短路重复下发。
  String? _lastPushedPlanId;

  /// 最近一次下发的排期计划，供设置界面展示当前排期状态。
  final ValueNotifier<ReminderPlan?> lastPlan = ValueNotifier<ReminderPlan?>(
    null,
  );

  /// 排期同步异常信息。供设置界面呈现错误原因与引导操作。
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  /// 通知权限缺失状态（包含未授权与权限被撤销）。
  ///
  /// 与 [lastError] 状态解耦：权限缺失属于常规交互状态而非系统故障，
  /// 用于驱动设置界面的授权引导。授权完成时调用 [onPermissionGranted] 触发重新排期。
  final ValueNotifier<bool> needsPermission = ValueNotifier<bool>(false);

  Timer? _debounceTimer;
  bool _inFlight = false;
  bool _needsRunAgain = false;
  bool _disposed = false;

  /// 注册数据源监听并触发初始排期同步。
  ///
  /// 注册时课表可能仍在异步加载：首轮同步的是一份空计划，待课表加载完成后再由
  /// 监听回调触发一次，补齐完整排期。因此这里无需等待数据就绪。
  Future<void> start() async {
    if (_disposed) return;
    _courseProvider.courses.addListener(_onSourceChanged);
    _courseProvider.scheduleConfig.addListener(_onSourceChanged);
    _appConfig.reminderEnabled.addListener(_onSourceChanged);
    _appConfig.reminderLeadMinutes.addListener(_onSourceChanged);
    _appConfig.reminderQuietStart.addListener(_onSourceChanged);
    _appConfig.reminderQuietEnd.addListener(_onSourceChanged);
    _appConfig.reminderWindowDays.addListener(_onSourceChanged);
    // 隐私配置变更会影响通知文本的脱敏展示，需要重新构建排期计划。
    _appConfig.showLocation.addListener(_onSourceChanged);
    _appConfig.showTeacherName.addListener(_onSourceChanged);
    await reschedule(force: true);
  }

  /// 释放服务资源并解绑监听。重复调用无副作用。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _courseProvider.courses.removeListener(_onSourceChanged);
    _courseProvider.scheduleConfig.removeListener(_onSourceChanged);
    _appConfig.reminderEnabled.removeListener(_onSourceChanged);
    _appConfig.reminderLeadMinutes.removeListener(_onSourceChanged);
    _appConfig.reminderQuietStart.removeListener(_onSourceChanged);
    _appConfig.reminderQuietEnd.removeListener(_onSourceChanged);
    _appConfig.reminderWindowDays.removeListener(_onSourceChanged);
    _appConfig.showLocation.removeListener(_onSourceChanged);
    _appConfig.showTeacherName.removeListener(_onSourceChanged);
    lastPlan.dispose();
    lastError.dispose();
    needsPermission.dispose();
  }

  void _onSourceChanged() {
    // 防抖合并连续触发的数据变更（如批量导入课表），保证设置修改及时生效并减少调度开销。
    unawaited(reschedule());
  }

  /// 重新计算并同步排期计划。同一时刻只允许一次同步在执行，期间到达的请求
  /// 不排队、只标记，待当前同步结束后合并为一次补跑。
  Future<void> reschedule({bool force = false}) async {
    if (_disposed) return;
    _debounceTimer?.cancel();
    if (!force) {
      _debounceTimer = Timer(_debounceDuration, () => unawaited(_runOnce()));
      return;
    }
    await _runOnce();
  }

  Future<void> _runOnce() async {
    if (_disposed) return;
    if (_inFlight) {
      // 当前任务执行中标记补跑，避免丢弃在异步间隙内发生的最后一次数据变更。
      _needsRunAgain = true;
      return;
    }
    _inFlight = true;
    try {
      do {
        _needsRunAgain = false;
        await _pushOnce();
        // 循环处理执行期间积压的数据变更，直至无待处理请求。
      } while (_needsRunAgain && !_disposed);
    } finally {
      _inFlight = false;
    }
  }

  /// 校验当前实例是否允许写入状态。
  ///
  /// 防止在异步执行间隙触发 [dispose] 后，后续逻辑继续更新已销毁的 [ValueNotifier] 引发异常。
  bool get _canWrite => !_disposed;

  Future<void> _pushOnce() async {
    final plan = buildPlan(now: DateTime.now());

    // 提醒开关关闭时撤销全部待投递通知，防止残留通知继续触发。
    if (!_appConfig.reminderEnabled.value) {
      try {
        await _transport.cancelAll();
        if (!_canWrite) return;
        lastPlan.value = plan;
        lastError.value = null;
        _lastPushedPlanId = plan.planId;
      } catch (e, stack) {
        if (!_canWrite) return;
        if (e is ReminderTransportUnavailable) {
          AppLog.w('ReminderService', 'cancelAll 跳过：$e');
          lastPlan.value = plan;
          return;
        }
        AppLog.e('ReminderService', 'cancelAll FAILED: $e\n$stack');
        lastError.value = '$e';
      }
      return;
    }

    if (plan.planId == _lastPushedPlanId) {
      if (!_canWrite) return;
      lastPlan.value = plan;
      return;
    }

    try {
      await _transport.syncPlan(plan);
      if (!_canWrite) return;
      _lastPushedPlanId = plan.planId;
      lastPlan.value = plan;
      lastError.value = null;
      needsPermission.value = false;
      if (plan.droppedCount > 0) {
        AppLog.w(
          'ReminderService',
          '排期被平台上限裁剪 ${plan.droppedCount} 条（原 ${plan.reminders.length + plan.droppedCount} 条）',
        );
      }
    } catch (e, stack) {
      // 同步失败时不更新 _lastPushedPlanId，确保后续触发能够重试当前计划。
      //
      // 区分权限缺失、通道不可用与系统投递异常：前两者属于预期交互或平台降级状态，
      // 仅记录警告日志，避免将预期状态标记为 lastError。
      if (!_canWrite) return;
      if (e is ReminderPermissionDenied) {
        AppLog.w('ReminderService', 'syncPlan 跳过：$e');
        lastPlan.value = plan;
        needsPermission.value = true;
        return;
      }
      if (e is ReminderTransportUnavailable) {
        AppLog.w('ReminderService', 'syncPlan 跳过：$e');
        lastPlan.value = plan;
        return;
      }
      AppLog.e('ReminderService', 'syncPlan FAILED: $e\n$stack');
      lastError.value = '$e';
    }
  }

  /// 基于当前课表与配置构建排期计划。公开此方法供设置页预览与单元测试调用。
  ///
  /// [now]：基准时间注入参数，单元测试可指定时间，生产调用使用当前时钟。
  ReminderPlan buildPlan({required DateTime now}) => ReminderPlanBuilder.build(
    courses: _courseProvider.courses.value,
    config: _courseProvider.scheduleConfig.value,
    settings: _appConfig.reminderSettings,
    now: now,
    // 在计划构建阶段应用系统容量截断，避免由系统按未定义顺序丢弃通知，
    // 同时保证 droppedCount 精确反映截断数量。
    maxReminders: _transport.pendingLimit,
  );

  /// 通知权限授予后的回调入口，用于强制触发即时排期同步。
  Future<void> onPermissionGranted() => reschedule(force: true);

  /// 请求通知权限并在获取成功后执行排期同步。
  ///
  /// 返回授权结果布尔值。若权限已被系统持久化拒绝，调用方应引导用户跳转系统设置界面。
  Future<bool> requestPermission({bool provisional = false}) async {
    try {
      final granted = await _transport.requestAuthorization(
        provisional: provisional,
      );
      if (granted) {
        needsPermission.value = false;
        await reschedule(force: true);
      } else {
        needsPermission.value = true;
      }
      return granted;
    } on ReminderTransportUnavailable catch (e) {
      AppLog.w('ReminderService', 'requestPermission 跳过：$e');
      return false;
    }
  }

  /// 查询当前系统的通知授权状态（如 authorized、provisional、denied、notDetermined、unknown）。
  Future<String> permissionStatus() async {
    try {
      return await _transport.getPermissionStatus();
    } on ReminderTransportUnavailable {
      return MethodChannelReminderTransport.permissionUnknown;
    }
  }

  /// 获取原生系统当前实际挂起的通知数量。
  Future<int> pendingCount() async {
    try {
      return await _transport.getPendingCount();
    } on ReminderTransportUnavailable {
      return 0;
    }
  }

  /// 跳转当前应用的系统通知设置界面，用于引导用户手动授予权限。
  Future<bool> openNotificationSettings() async {
    try {
      return await _transport.openNotificationSettings();
    } on ReminderTransportUnavailable {
      return false;
    }
  }

  /// 通过真实同步链路调度一条在 [delay] 后触发的探针通知，用于端到端验证宿主投递能力。
  ///
  /// 探针通知在短延迟后触发，用于验证原生通道与系统通知调度是否正常工作，
  /// 以隔离权限缺失、平台上限截断与宿主未接入等不同故障原因。
  ///
  /// 关键约束：
  /// 1. 探针计划必须合并当前排期中的真实提醒：由于原生层采用全量替换策略，
  ///    仅下发探针会导致既有课表排期被全量撤销；
  /// 2. 必须重置 [_lastPushedPlanId]：探针同步后重置短路哈希，
  ///    确保后续数据变更触发重排时能正确覆盖探针并重新同步标准计划。
  ///
  /// 返回原生层是否成功接收并登记排期。
  Future<bool> fireProbe({
    Duration delay = const Duration(seconds: 15),
    required String title,
    required String body,
  }) async {
    if (_disposed) return false;
    final now = DateTime.now();
    final fireAt = now.add(delay);
    final base = buildPlan(now: now);

    final probe = ReminderItem(
      id: 'probe:${now.millisecondsSinceEpoch}',
      kind: ReminderKind.courseStart,
      fireAt: fireAt,
      title: title,
      body: body,
      collapseKey: 'probe',
    );

    // 与 buildPlan 保持一致的排序、截断与哈希规则，确保探针与常规排期的截断标准一致。
    final plan = ReminderPlanBuilder.compose(
      reminders: [...base.reminders, probe],
      generatedAt: now,
      windowStart: base.windowStart,
      windowEnd: fireAt.isAfter(base.windowEnd) ? fireAt : base.windowEnd,
      channel: base.channel,
      maxReminders: _transport.pendingLimit,
    );

    // 先行重置短路标识：即使后续下发异常，下一次重排也能重新构建并下发计划，避免被历史哈希短路。
    _lastPushedPlanId = null;

    await _transport.syncPlan(plan);
    if (_canWrite) {
      lastPlan.value = plan;
      lastError.value = null;
    }
    return true;
  }
}
