import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/utils/platform_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 系统通知授权状态。
///
/// 与原生平台状态枚举一一对应，并补充两个跨平台语义值：
/// - [unsupported]：当前平台不具备本地提醒投递能力（Noop 通道或原生通道未接线），
///   属预期降级，调用方应据此隐藏授权引导而非反复请求；
/// - [unknown]：通道可用但无法读取原生状态，属可疑故障，按未授权保守处理。
enum ReminderPermissionStatus {
  authorized,
  provisional,

  /// iOS 临时授权（仅 App Clip 场景），生命周期受限但期间可投递通知。
  ephemeral,
  denied,
  notDetermined,
  unsupported,
  unknown;

  /// 是否可实际投递通知。`ephemeral` 属临时授权，同样可投递。
  bool get isGranted =>
      this == authorized || this == provisional || this == ephemeral;

  /// 由原生返回字符串解析；未知字符串一律回退 [unknown]。
  static ReminderPermissionStatus fromNative(String? raw) => switch (raw) {
    'authorized' => authorized,
    'provisional' => provisional,
    'ephemeral' => ephemeral,
    'denied' => denied,
    'notDetermined' => notDetermined,
    _ => unknown,
  };
}

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
  /// （`authorized`、`provisional`、`ephemeral`、`denied`、`notDetermined`、`unknown`）。
  Future<ReminderPermissionStatus> getPermissionStatus();

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
      if (granted == null) throw const ReminderTransportUnavailable();
      return granted;
    } on MissingPluginException {
      throw const ReminderTransportUnavailable();
    } on PlatformException catch (e) {
      if (e.code == unsupportedPlatformCode) {
        throw const ReminderTransportUnavailable();
      }
      // A host/API failure is not a user denying notification permission.
      rethrow;
    }
  }

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async {
    try {
      final status = await _channel.invokeMethod<String>('getPermissionStatus');
      return ReminderPermissionStatus.fromNative(status);
    } on MissingPluginException {
      throw const ReminderTransportUnavailable();
    } on PlatformException {
      return ReminderPermissionStatus.unknown;
    }
  }

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
  /// OHOS 原生通道采用 30 条预算；Android 不使用这里的硬性配额。
  @override
  int? get pendingLimit {
    if (isOhos) return 30;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS => ReminderSettings.iosPendingNotificationLimit,
      _ => null,
    };
  }
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
  Future<bool> requestAuthorization({bool provisional = false}) async =>
      throw const ReminderTransportUnavailable();

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async =>
      ReminderPermissionStatus.unsupported;

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
  // CPF adds enum members absent in upstream Flutter. Do not exhaustively
  // switch over that SDK enum or refer to TargetPlatform.ohos in shared code.
  if (isOhos ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return const MethodChannelReminderTransport();
  }
  return const NoopReminderTransport();
}
