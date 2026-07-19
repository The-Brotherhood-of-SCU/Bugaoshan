import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 安卓下载进度通知服务。
///
/// 通过 [MethodChannel] `bugaoshan/update` 与原生 Kotlin 端通信,通过
/// [EventChannel] `bugaoshan/download_cancel` 接收通知栏"取消"按钮事件。
///
/// 所有方法在非 Android 平台静默 no-op([isSupported] 为 false 时直接 return),
/// 不会抛异常。调用方无需做平台守卫。
///
/// 权限处理:[requestPermission] 在 Android 13+ 请求 `POST_NOTIFICATIONS` 运行时权限;
/// 权限被拒绝时不阻断下载,仅不显示通知。
class DownloadNotificationService {
  static const _methodChannel = MethodChannel('bugaoshan/update');
  static const _cancelEventChannel = EventChannel('bugaoshan/download_cancel');

  StreamSubscription<void>? _cancelSub;
  StreamController<void>? _cancelController;

  /// 是否在当前平台支持通知栏进度条(仅 Android)。
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 请求 POST_NOTIFICATIONS 运行时权限(Android 13+)。
  ///
  /// 返回 true 表示已获得权限(已授予、API < 33 无需请求、或本次请求成功)。
  /// 在下载开始前调用;失败不阻断下载,仅不显示通知。
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 显示下载通知并设置初始进度。
  ///
  /// [indeterminate] 为 true 时显示不确定进度的滚动条(总大小未知)。
  /// [progress] / [max] 在 indeterminate=false 时使用,通常 max=100。
  Future<void> showDownloadNotification({
    required String content,
    int progress = 0,
    int max = 100,
    bool indeterminate = false,
  }) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('showDownloadNotification', {
        'content': content,
        'progress': progress,
        'max': max,
        'indeterminate': indeterminate,
      });
    } on PlatformException {
      // 通知权限被拒或系统问题,忽略 — App 内对话框照常工作
    }
  }

  /// 更新下载进度通知。
  Future<void> updateProgress({
    required String content,
    int progress = 0,
    int max = 100,
    bool indeterminate = false,
  }) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('updateDownloadProgress', {
        'content': content,
        'progress': progress,
        'max': max,
        'indeterminate': indeterminate,
      });
    } on PlatformException {
      // 忽略
    }
  }

  /// 下载完成:显示"正在安装"且无进度条,允许滑动清除。
  Future<void> showCompleted({required String content}) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('showDownloadCompleted', {
        'content': content,
      });
    } on PlatformException {
      // 忽略
    }
  }

  /// 下载失败:显示错误内容,允许滑动清除。
  Future<void> showError({required String content}) async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('showDownloadError', {
        'content': content,
      });
    } on PlatformException {
      // 忽略
    }
  }

  /// 取消下载:取消通知。
  Future<void> cancel() async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod<void>('cancelDownloadNotification');
    } on PlatformException {
      // 忽略
    }
  }

  /// 监听来自 Kotlin 端的"取消"按钮事件(通过 EventChannel)。
  ///
  /// 返回 [Stream<void>];调用方订阅,收到事件时调 cancelDownload()。
  /// 单订阅 — 内部用 [StreamController.broadcast] 转发,允许多个监听者。
  Stream<void> get onCancelButtonPressed {
    if (!isSupported) {
      return const Stream<void>.empty();
    }
    // 确保 controller 已初始化并订阅 EventChannel
    _ensureCancelController();
    return _cancelController!.stream;
  }

  void _ensureCancelController() {
    if (_cancelController != null) return;
    _cancelController = StreamController<void>.broadcast();
    _cancelSub = _cancelEventChannel.receiveBroadcastStream().listen(
      (_) => _cancelController?.add(null),
      onError: (Object _) {
        // 忽略 EventChannel 错误
      },
    );
  }

  /// 清理订阅。在 UpdateProvider.dispose 中调用。
  void dispose() {
    _cancelSub?.cancel();
    _cancelSub = null;
    _cancelController?.close();
    _cancelController = null;
  }
}
