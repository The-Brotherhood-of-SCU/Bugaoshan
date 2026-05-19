import 'dart:async';
import 'dart:io';

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
  }) : _platformChecker =
           platformChecker ?? (() => !kIsWeb && Platform.isAndroid) {
    _debounceDuration = debounceDuration ?? _debounceDuration;
  }

  /// Request a widget data update.
  ///
  /// - If [force] is true, attempts to run the platform update immediately
  ///   (subject to `_inFlight` guard). Otherwise calls are debounced by
  ///   `_debounceDuration` and coalesced.
  Future<void> updateWidgetData({bool force = false}) {
    if (!_platformChecker()) return Future.value();
    if (_disposed) {
      return Future.error(StateError(_kDisposedMessage));
    }

    _pendingCompleter ??= Completer<void>();

    // If force immediate requested, cancel pending timer and try to run now.
    if (force) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _scheduleRun();
      return _pendingCompleter!.future;
    }

    // Normal (debounced) path: reset debounce timer
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () => _scheduleRun());
    return _pendingCompleter!.future;
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
    // Keep the current completer so callers that awaited get resolved
    final completer = _pendingCompleter;
    try {
      var continueRun = true;
      while (continueRun) {
        try {
          debugPrint('WidgetUpdate: starting update...');
          await _channel.invokeMethod('updateWidget');
          debugPrint('WidgetUpdate: completed successfully');
        } catch (e, stack) {
          debugPrint('WidgetUpdate: FAILED: $e');
          debugPrint('WidgetUpdate: stack: $stack');
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
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('pinWidget', {
        'size': size,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetUpdate: pinWidget FAILED: $e');
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return false;
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
    if (kIsWeb || !Platform.isAndroid) return false;
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
