import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/utils/constants.dart';

class WidgetUpdateService {
  static const _channel = kUpdateMethodChannel;
  static const String _kDisposedMessage = 'WidgetUpdateService disposed';
  Timer? _debounceTimer;
  Completer<void>? _pendingCompleter;
  Duration _debounceDuration = const Duration(milliseconds: 500);
  bool _inFlight = false;
  bool _needsRunAgain = false;
  bool _disposed = false;
  final bool Function() _platformChecker;
  final StreamController<String> _widgetPinnedController =
      StreamController<String>.broadcast();

  WidgetUpdateService({
    Duration? debounceDuration,
    bool Function()? platformChecker,
  }) : _platformChecker =
           platformChecker ??
           (() =>
               !kIsWeb &&
               (defaultTargetPlatform == TargetPlatform.android ||
                   defaultTargetPlatform == TargetPlatform.iOS ||
                   defaultTargetPlatform == TargetPlatform.macOS)) {
    _debounceDuration = debounceDuration ?? _debounceDuration;
    // 接收原生侧推送的 widget pin 成功事件(用户真正确认添加后由系统回调)
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// 用户真正确认 Pin 小组件后触发(参数为尺寸 small/medium/large)。
  ///
  /// 注意 `pinWidget` 的返回值只表示"请求已提交",是否添加成功以此事件为准。
  Stream<String> get onWidgetPinned => _widgetPinnedController.stream;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onWidgetPinned') {
      final size = call.arguments is Map
          ? (call.arguments as Map)['size'] as String?
          : null;
      if (size != null && !_widgetPinnedController.isClosed) {
        _widgetPinnedController.add(size);
      }
    }
    return null;
  }

  /// Request a widget data update.
  ///
  /// - If [force] is true, attempts to run the platform update immediately
  ///   (subject to `_inFlight` guard). Otherwise calls are debounced by
  ///   `_debounceDuration` and coalesced.
  Future<void> updateWidgetData({bool force = false}) async {
    debugPrint(
      'BugaoShan WidgetUpdateService: updateWidgetData called, force: $force',
    );
    if (!_platformChecker()) {
      debugPrint(
        'BugaoShan WidgetUpdateService: platform check failed, skipping',
      );
      return Future.value();
    }
    if (_disposed) {
      return Future.error(StateError(_kDisposedMessage));
    }

    _pendingCompleter ??= Completer<void>();

    // If force immediate requested, cancel pending timer and try to run now.
    if (force) {
      debugPrint('BugaoShan WidgetUpdateService: force update requested');
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _scheduleRun();
      return _pendingCompleter!.future;
    }

    // Normal (debounced) path: reset debounce timer
    debugPrint('BugaoShan WidgetUpdateService: debounced update scheduled');
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () => _scheduleRun());
    return _pendingCompleter!.future;
  }

  /// Sync the widget show tomorrow setting to App Group and update widget.
  Future<void> syncWidgetShowTomorrow(bool value) async {
    debugPrint(
      'BugaoShan WidgetUpdateService: syncWidgetShowTomorrow called with value: $value',
    );
    if (!_platformChecker()) {
      debugPrint(
        'BugaoShan WidgetUpdateService: platform check failed for syncWidgetShowTomorrow',
      );
      return Future.value();
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        debugPrint(
          'BugaoShan WidgetUpdateService: calling native syncWidgetShowTomorrow',
        );
        await _channel.invokeMethod<void>('syncWidgetShowTomorrow', {
          'value': value,
        });
        debugPrint(
          'BugaoShan WidgetUpdateService: native syncWidgetShowTomorrow completed',
        );
      }
      // On Android, the setting is already in SharedPreferences which is accessible to widget
      if (defaultTargetPlatform == TargetPlatform.android) {
        await updateWidgetData(force: true);
      }
    } catch (e, stack) {
      debugPrint('WidgetUpdate: syncWidgetShowTomorrow FAILED: $e');
      debugPrint('WidgetUpdate: stack: $stack');
    }
  }

  /// Syncs the visual style used by the iOS WidgetKit extension.
  Future<void> syncWidgetAppearance({
    required WidgetColorStyle colorStyle,
    required WidgetDensity density,
  }) async {
    if (!_platformChecker() || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('syncWidgetAppearance', {
        'colorStyle': colorStyle.index,
        'density': density.index,
      });
    } catch (e, stack) {
      debugPrint('WidgetUpdate: syncWidgetAppearance FAILED: $e');
      debugPrint('WidgetUpdate: stack: $stack');
    }
  }

  void _scheduleRun() {
    if (_disposed) {
      if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
        _pendingCompleter!.completeError(StateError(_kDisposedMessage));
      }
      _pendingCompleter = null;
      return;
    }

    if (_inFlight) {
      // An update is already running; mark that we need another run afterwards.
      _needsRunAgain = true;
      return;
    }

    // Not in flight -> run now
    _runOnce();
  }

  Future<void> _runOnce() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_disposed) return;
    _inFlight = true;
    debugPrint('BugaoShan WidgetUpdateService: running _runOnce');
    // Keep the current completer so callers that awaited get resolved
    final completer = _pendingCompleter;
    try {
      var continueRun = true;
      while (continueRun) {
        try {
          debugPrint(
            'BugaoShan WidgetUpdateService: calling native updateWidget',
          );
          await _channel.invokeMethod('updateWidget');
          debugPrint(
            'BugaoShan WidgetUpdateService: native updateWidget completed successfully',
          );
        } catch (e, stack) {
          debugPrint('BugaoShan WidgetUpdateService: updateWidget FAILED: $e');
          debugPrint('BugaoShan WidgetUpdateService: stack: $stack');
          // Clear follow-up flag to avoid stale state causing extra runs
          _needsRunAgain = false;
          // Propagate error to awaiting callers and stop further runs
          if (completer != null && !completer.isCompleted) {
            completer.completeError(e, stack);
          }
          return;
        }

        // After a successful run, decide whether to run again
        if (_needsRunAgain) {
          debugPrint(
            'BugaoShan WidgetUpdateService: needsRunAgain is true, looping to run again',
          );
          _needsRunAgain = false;
          // loop to run again
          continueRun = true;
        } else {
          continueRun = false;
        }
      }
      // All runs finished successfully
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    } finally {
      // Clear pending completer only after completing it
      _pendingCompleter = null;
      // Ensure follow-up flag is cleared to avoid leaking state
      _needsRunAgain = false;
      _inFlight = false;
      debugPrint('BugaoShan WidgetUpdateService: _runOnce finished');
    }
  }

  /// Cancel any pending timers and prevent future updates. Completes any
  /// pending futures with a [StateError]. Call when disposing the service.
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _widgetPinnedController.close();
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.completeError(
        StateError('WidgetUpdateService disposed'),
      );
      _pendingCompleter = null;
    }
  }

  Future<bool> pinWidget(String size) async {
    if (kIsWeb ||
        (![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform))) {
      return false;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _channel.invokeMethod<bool>('pinWidget', {
          'size': size,
        });
        return result ?? false;
      } else {
        // iOS/macOS 不支持直接 pin widget，仅返回 false
        return false;
      }
    } catch (e) {
      debugPrint('WidgetUpdate: pinWidget FAILED: $e');
      return false;
    }
  }

  /// 查询当前已添加到桌面的全部小组件 id(用于 pin 前后 diff 验证真实结果)。
  Future<Set<int>> getPinnedWidgetIds() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {};
    }
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getWidgetIds');
      return result?.whereType<int>().toSet() ?? {};
    } catch (e) {
      debugPrint('WidgetUpdate: getWidgetIds FAILED: $e');
      return {};
    }
  }

  /// 打开本应用的系统详情设置页(引导用户开启「创建桌面快捷方式」等权限)。
  Future<bool> openAppSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('openAppSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetUpdate: openAppSettings FAILED: $e');
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetUpdate: isIgnoringBatteryOptimizations FAILED: $e');
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetUpdate: requestIgnoreBatteryOptimizations FAILED: $e');
      return false;
    }
  }
}
