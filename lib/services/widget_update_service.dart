import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WidgetUpdateService {
  static const _channel = MethodChannel('bugaoshan/update');
  static const String _kDisposedMessage = 'WidgetUpdateService disposed';
  Timer? _debounceTimer;
  Completer<void>? _pendingCompleter;
  Duration _debounceDuration = const Duration(milliseconds: 500);
  bool _inFlight = false;
  bool _needsRunAgain = false;
  bool _disposed = false;
  final bool Function() _platformChecker;

  WidgetUpdateService({
    Duration? debounceDuration,
    bool Function()? platformChecker,
  }) : _platformChecker = platformChecker ??
           (() => !kIsWeb &&
               (defaultTargetPlatform == TargetPlatform.android ||
                   defaultTargetPlatform == TargetPlatform.iOS ||
                   defaultTargetPlatform == TargetPlatform.macOS)) {
    _debounceDuration = debounceDuration ?? _debounceDuration;
  }

  /// Request a widget data update.
  ///
  /// - If [force] is true, attempts to run the platform update immediately
  ///   (subject to `_inFlight` guard). Otherwise calls are debounced by
  ///   `_debounceDuration` and coalesced.
  Future<void> updateWidgetData({bool force = false}) async {
    debugPrint('BugaoShan WidgetUpdateService: updateWidgetData called, force: $force');
    if (!_platformChecker()) {
      debugPrint('BugaoShan WidgetUpdateService: platform check failed, skipping');
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
    debugPrint('BugaoShan WidgetUpdateService: syncWidgetShowTomorrow called with value: $value');
    if (!_platformChecker()) {
      debugPrint('BugaoShan WidgetUpdateService: platform check failed for syncWidgetShowTomorrow');
      return Future.value();
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        debugPrint('BugaoShan WidgetUpdateService: calling native syncWidgetShowTomorrow');
        await _channel.invokeMethod<void>('syncWidgetShowTomorrow', {
          'value': value,
        });
        debugPrint('BugaoShan WidgetUpdateService: native syncWidgetShowTomorrow completed');
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
          debugPrint('BugaoShan WidgetUpdateService: calling native updateWidget');
          await _channel.invokeMethod('updateWidget');
          debugPrint('BugaoShan WidgetUpdateService: native updateWidget completed successfully');
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
          debugPrint('BugaoShan WidgetUpdateService: needsRunAgain is true, looping to run again');
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
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.completeError(
        StateError('WidgetUpdateService disposed'),
      );
      _pendingCompleter = null;
    }
  }

  Future<bool> pinWidget(String size) async {
    if (kIsWeb ||
        (![TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]
            .contains(defaultTargetPlatform))) {
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
