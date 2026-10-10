import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 排期计划投递传输层接口。
///
/// 解耦排期计算与平台原生调度，使 [ReminderService] 依赖抽象接口以便于测试与多平台适配。
abstract class ReminderTransport {
  /// 执行计划全量同步：原生端全量覆盖现有计划，撤销在新计划中不存在的通知 ID。
  Future<void> syncPlan(ReminderPlan plan);

  /// 撤销所有已挂起的排期提醒（在提醒主开关关闭时调用）。
  Future<void> cancelAll();

  /// 请求系统通知权限，返回授权结果。
  ///
  /// [provisional] 为 true 时请求临时静默通知权限（Provisional Authorization，不触发系统弹窗，
  /// 通知仅进入通知中心；仅 iOS 支持，Android 忽略该参数）。
  Future<bool> requestAuthorization({bool provisional = false});

  /// 查询当前系统通知授权状态。返回值与原生平台状态枚举对应
  /// （`authorized`、`provisional`、`denied`、`notDetermined`、`unknown`）。
  Future<String> getPermissionStatus();

  /// 获取原生系统当前实际注册的待投递通知数量。
  ///
  /// 与下发计划条数的差异可用于度量被系统丢弃或已过期的通知数量，提供排期可观测性。
  Future<int> getPendingCount();

  /// 跳转当前应用的系统通知设置页面。
  ///
  /// 用于系统权限被拒绝后引导用户手动开启授权。返回是否成功唤起设置界面。
  Future<bool> openNotificationSettings();

  /// 当前平台支持的最大待投递通知数量上限，`null` 表示无硬性限制。
  ///
  /// iOS / macOS 的 `UNUserNotificationCenter` 限制每个应用最多挂起 64 条待投递通知，
  /// 超额项将被系统按未定义顺序丢弃。将容量配额前置注入排期构建阶段，
  /// 保证在 Dart 侧按时间升序显式截断，并准确记录 [ReminderPlan.droppedCount]。
  int? get pendingLimit;
}

/// 基于 MethodChannel 的跨平台通知投递实现。
///
/// 平台能力由原生宿主返回错误码裁决，未支持平台返回 `UNSUPPORTED_PLATFORM` 错误，
/// 本层统一转换为 [ReminderTransportUnavailable] 异常。
class MethodChannelReminderTransport implements ReminderTransport {
  static const MethodChannel _channel = MethodChannel('bugaoshan/reminder');

  const MethodChannelReminderTransport();

  @override
  Future<void> syncPlan(ReminderPlan plan) async {
    try {
      await _channel.invokeMethod<void>('syncPlan', plan.toChannelPayload());
    } on MissingPluginException {
      throw const ReminderTransportUnavailable();
    } on PlatformException catch (e) {
      if (e.code == unsupportedPlatformCode) {
        throw const ReminderTransportUnavailable();
      }
      if (e.code == notAuthorizedCode) {
        throw const ReminderPermissionDenied();
      }
      rethrow;
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } on MissingPluginException {
      throw const ReminderTransportUnavailable();
    } on PlatformException catch (e) {
      if (e.code == unsupportedPlatformCode) {
        throw const ReminderTransportUnavailable();
      }
      rethrow;
    }
  }

  /// 原生端未实现通道或平台不支持时返回的错误码。
  static const String unsupportedPlatformCode = 'UNSUPPORTED_PLATFORM';

  /// 原生端未获得通知权限时返回的错误码。
  static const String notAuthorizedCode = 'NOT_AUTHORIZED';

  @override
  Future<bool> requestAuthorization({bool provisional = false}) async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestAuthorization',
        {'provisional': provisional},
      );
      return granted ?? false;
    } on MissingPluginException {
      throw const ReminderTransportUnavailable();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String> getPermissionStatus() async {
    try {
      final status = await _channel.invokeMethod<String>('getPermissionStatus');
      return status ?? permissionUnknown;
    } on MissingPluginException {
      throw const ReminderTransportUnavailable();
    } on PlatformException {
      return permissionUnknown;
    }
  }

  /// 无法获取原生授权状态时的回退值。默认不假定已授权，防止界面显示开启但实际无法投递。
  static const String permissionUnknown = 'unknown';

  @override
  Future<int> getPendingCount() async {
    try {
      final count = await _channel.invokeMethod<int>('getPendingCount');
      return count ?? 0;
    } on MissingPluginException {
      throw const ReminderTransportUnavailable();
    } on PlatformException {
      return 0;
    }
  }

  @override
  Future<bool> openNotificationSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openNotificationSettings',
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// iOS 与 macOS 基于 `UNUserNotificationCenter`，受系统 64 条待投递上限约束；
  /// Android 等其他平台采用独立调度机制，不受此硬性配额限制。
  @override
  int? get pendingLimit => switch (defaultTargetPlatform) {
    TargetPlatform.iOS ||
    TargetPlatform.macOS => ReminderSettings.iosPendingNotificationLimit,
    _ => null,
  };
}

/// 系统通知权限缺失异常。
///
/// 标识未获得系统通知权限。属于常规业务引导状态，调用方应引导用户授权并避免记录为错误日志。
class ReminderPermissionDenied implements Exception {
  const ReminderPermissionDenied();

  @override
  String toString() => '尚未获得通知权限';
}

/// 原生通道未就绪或当前平台不支持通知投递异常。
///
/// 标识平台能力缺失或处于开发过渡期。调用方应将其作为平台降级处理，不中断业务流程。
class ReminderTransportUnavailable implements Exception {
  const ReminderTransportUnavailable();

  @override
  String toString() => '原生侧未提供提醒投递能力（尚未接线或平台不支持）';
}

/// 无操作的空实现（用于桌面端、Web 端或尚未接入原生调度的环境）。
///
/// 保证跨平台排期逻辑与状态可观测性正常运行，但不向系统投递物理通知。
class NoopReminderTransport implements ReminderTransport {
  const NoopReminderTransport();

  @override
  Future<void> syncPlan(ReminderPlan plan) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> requestAuthorization({bool provisional = false}) async => false;

  @override
  Future<String> getPermissionStatus() async =>
      MethodChannelReminderTransport.permissionUnknown;

  @override
  Future<int> getPendingCount() async => 0;

  @override
  Future<bool> openNotificationSettings() async => false;

  /// 无原生投递能力时不设上限，避免产生虚假的截断计数。
  @override
  int? get pendingLimit => null;
}

/// 根据运行平台构造对应的 [ReminderTransport] 实例。
///
/// 集中平台判定逻辑，收敛平台差异分支。
ReminderTransport createReminderTransport() {
  if (kIsWeb) return const NoopReminderTransport();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return const MethodChannelReminderTransport();
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return const NoopReminderTransport();
  }
}
