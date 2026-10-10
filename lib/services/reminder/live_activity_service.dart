import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 异常体系定义

/// 实时活动（Live Activity）基础异常类。
sealed class LiveActivityException implements Exception {
  const LiveActivityException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 运行环境不支持实时活动异常（非 iOS/Android 支持环境或系统版本不满足要求）。
class LiveActivityUnsupportedException extends LiveActivityException {
  const LiveActivityUnsupportedException([
    super.message = '当前系统或设备不支持实时活动/状态栏胶囊（需 iOS 16.1+ 或 Android 相应系统）',
  ]);
}

/// 用户未授予实时活动或通知权限异常。
class LiveActivityNotAuthorizedException extends LiveActivityException {
  const LiveActivityNotAuthorizedException([
    super.message = '用户未在系统设置中开启实时活动或通知权限',
  ]);
}

/// 非前台调用异常（系统约束实时活动仅允许在应用处于前台活跃状态时启动）。
class LiveActivityForegroundRequiredException extends LiveActivityException {
  const LiveActivityForegroundRequiredException([
    super.message = '实时活动只能在应用处于前台活跃状态时启动',
  ]);
}

/// 无活跃实时活动会话异常。
class LiveActivityNoActiveSessionException extends LiveActivityException {
  const LiveActivityNoActiveSessionException([super.message = '当前没有活跃中的实时活动']);
}

/// 原生层实时活动操作失败异常。
class LiveActivityOperationException extends LiveActivityException {
  const LiveActivityOperationException(
    super.message, {
    this.code,
    this.details,
  });

  final String? code;
  final dynamic details;

  @override
  String toString() {
    if (code != null) {
      return '$message (code: $code)';
    }
    return message;
  }
}

// 服务实现

/// 锁屏与灵动岛实时活动（Live Activity）通信服务。
///
/// 架构设计说明：
/// - 无状态通信服务：不直接依赖持久化存储，支持独立依赖注入与单元测试；
/// - 精确异常分类：细化并透出平台未支持、权限受限、非前台状态、无活跃会话及原生执行失败等异常类型；
/// - 视图自刷新机制：倒计时展示依赖系统级时间区间渲染，无需高频主动下发状态更新。
class LiveActivityService {
  LiveActivityService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('bugaoshan/live_activity');

  final MethodChannel _channel;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// 检查当前设备与系统是否支持且已启用实时活动/状态栏胶囊（需 iOS 16.1+ 或 Android 开启通知权限）。
  Future<bool> isSupported() async {
    if (!_isSupportedPlatform) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 在应用处于前台状态时启动课程的实时活动。
  ///
  /// - [courseName]：当前课程名称。
  /// - [location]：授课地点。
  /// - [endAt]：课程结束时间。
  /// - [startAt]：课程开始时间，为空时默认为当前时刻。
  /// - [nextCourseName]：后续关联课程名称（可选）。
  /// - [nextLocation]：后续关联课程地点（可选）。
  ///
  /// 成功时返回原生层生成的 Activity 唯一标识。
  ///
  /// 抛出异常：
  /// - [LiveActivityUnsupportedException]：平台或系统版本不支持。
  /// - [LiveActivityForegroundRequiredException]：应用未处于前台活跃状态。
  /// - [LiveActivityNotAuthorizedException]：系统设置中未开启权限。
  /// - [LiveActivityOperationException]：原生层会话启动失败。
  Future<String?> start({
    required String courseName,
    required String location,
    required DateTime endAt,
    DateTime? startAt,
    String? nextCourseName,
    String? nextLocation,
  }) async {
    if (!_isSupportedPlatform) {
      throw const LiveActivityUnsupportedException('当前平台不支持实时活动/状态栏胶囊');
    }

    try {
      final activityId = await _channel.invokeMethod<String>('start', {
        'courseName': courseName,
        'location': location,
        'endAtMillis': endAt.millisecondsSinceEpoch,
        if (startAt != null) 'startAtMillis': startAt.millisecondsSinceEpoch,
        'nextCourseName': ?nextCourseName,
        'nextLocation': ?nextLocation,
      });
      return activityId;
    } on MissingPluginException {
      throw const LiveActivityUnsupportedException('原生未提供 Live Activity 通道');
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'UNSUPPORTED_PLATFORM':
          throw LiveActivityUnsupportedException(e.message ?? '当前平台不支持实时活动');
        case 'NOT_IN_FOREGROUND':
          throw LiveActivityForegroundRequiredException(
            e.message ?? '实时活动必须在前台启动',
          );
        case 'NOT_AUTHORIZED':
          throw LiveActivityNotAuthorizedException(
            e.message ?? '系统设置未启用实时活动权限',
          );
        default:
          throw LiveActivityOperationException(
            e.message ?? '启动实时活动失败',
            code: e.code,
            details: e.details,
          );
      }
    }
  }

  /// 启动一条示例实时活动，用于在真机上验证灵动岛与锁屏的渲染形态。
  ///
  /// 与 [start] 的差别有两处：课程内容由调用方以示例文案给出，结束时刻按
  /// [duration] 相对当前时刻推算。因此无需构造课表数据即可触发一条会话。
  ///
  /// 启动前先结束既有会话：原生端的 update 采用字段增量合并语义，
  /// 复用既有会话会使新内容继承上一次的课程字段。
  Future<String?> startSample({
    required String courseName,
    required String location,
    String? nextCourseName,
    Duration duration = const Duration(minutes: 60),
  }) async {
    final now = DateTime.now();
    await end();
    return start(
      courseName: courseName,
      location: location,
      startAt: now,
      endAt: now.add(duration),
      nextCourseName: nextCourseName,
    );
  }

  /// 更新进行中的实时活动状态。
  ///
  /// 抛出异常：
  /// - [LiveActivityUnsupportedException]：平台不支持。
  /// - [LiveActivityNoActiveSessionException]：当前不存在活跃会话。
  /// - [LiveActivityOperationException]：原生层更新失败。
  Future<void> update({
    String? courseName,
    String? location,
    DateTime? endAt,
    DateTime? startAt,
    String? nextCourseName,
    String? nextLocation,
  }) async {
    if (!_isSupportedPlatform) {
      throw const LiveActivityUnsupportedException('当前平台不支持实时活动/状态栏胶囊');
    }

    try {
      await _channel.invokeMethod<void>('update', {
        'courseName': ?courseName,
        'location': ?location,
        if (endAt != null) 'endAtMillis': endAt.millisecondsSinceEpoch,
        if (startAt != null) 'startAtMillis': startAt.millisecondsSinceEpoch,
        'nextCourseName': ?nextCourseName,
        'nextLocation': ?nextLocation,
      });
    } on MissingPluginException {
      throw const LiveActivityUnsupportedException('原生未提供 Live Activity 通道');
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'UNSUPPORTED_PLATFORM':
          throw LiveActivityUnsupportedException(e.message ?? '当前平台不支持实时活动');
        case 'NO_ACTIVE_ACTIVITY':
          throw LiveActivityNoActiveSessionException(
            e.message ?? '没有进行中的实时活动可更新',
          );
        default:
          throw LiveActivityOperationException(
            e.message ?? '更新实时活动失败',
            code: e.code,
            details: e.details,
          );
      }
    }
  }

  /// 结束所有进行中的 Live Activity。
  ///
  /// 若当前平台不支持，静默返回无操作。
  Future<void> end() async {
    if (!_isSupportedPlatform) return;

    try {
      await _channel.invokeMethod<void>('end');
    } on MissingPluginException {
      // 原生通道缺失时执行安全回退，不阻断主流程。
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED_PLATFORM') return;
      throw LiveActivityOperationException(
        e.message ?? '结束实时活动失败',
        code: e.code,
        details: e.details,
      );
    }
  }
}
