import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter/foundation.dart'
    show FlutterError, debugPrintSynchronously, kDebugMode;
import 'package:flutter/widgets.dart' show ErrorWidget;

/// Debug-only raw error reporting for startup failures with incomplete HiLog.
///
/// Do not use AppLog here: notifying its listeners can report another framework
/// error while Flutter is recovering from the original build/layout failure.
class OhosDebugDiagnostics {
  OhosDebugDiagnostics({void Function(String)? writeLine})
    : _writeLine = writeLine ?? debugPrintSynchronously;

  final void Function(String) _writeLine;
  int _sequence = 0;
  bool _reporting = false;

  void install() {
    if (!kDebugMode) return;
    FlutterError.onError = (details) {
      report('flutter', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report('platform', error, stack);
      return true;
    };
    // Keep a leaf error widget. Formatting the exception here would run on the
    // same deep build stack that may just have overflowed.
    ErrorWidget.builder = (_) => ErrorWidget.withDetails(
      message: '页面构建失败，请查看 HiLog 中的 BugaoshanDiagnostic。',
    );
  }

  void mark(String stage) {
    if (kDebugMode) _emit('stage', stage);
  }

  void report(String source, Object error, StackTrace? stack) {
    if (!kDebugMode || _reporting) return;
    final id = ++_sequence;
    // Unwind the failing build/layout stack before string conversion or logging.
    // Keep the supplied stack; StackTrace.current here would lose the failure.
    scheduleMicrotask(() {
      _reporting = true;
      try {
        _emit('$id', 'BEGIN $source ${error.runtimeType}');
        // Emit the raw VM stack first, without Flutter's defaultStackFilter or
        // details.toString()/informationCollector/Diagnostics tree rendering.
        _emit('$id stack', _asText(stack, '<no stack supplied>'));
        _emit('$id error', _asText(error, '<error text unavailable>'));
        _emit('$id', 'END');
      } finally {
        _reporting = false;
      }
    });
  }

  static String _asText(Object? value, String fallback) {
    if (value == null) return fallback;
    try {
      return value.toString();
    } catch (_) {
      // A broken toString must not replace the original error/stack.
      return fallback;
    }
  }

  void _emit(String label, String text) {
    try {
      // Redact before splitting so credentials cannot cross a chunk boundary.
      final safe = AuthLogRedactor.apply(text);
      for (final line in const LineSplitter().convert(safe)) {
        if (line.isEmpty) continue;
        // At most 1536 UTF-8 bytes of valid text per chunk, leaving room for
        // HiLog/engine prefixes. Do not truncate frames or collapse repetitions.
        const chunkLength = 512;
        for (var start = 0; start < line.length;) {
          var end = (start + chunkLength).clamp(0, line.length);
          if (end < line.length &&
              line.codeUnitAt(end - 1) >= 0xd800 &&
              line.codeUnitAt(end - 1) <= 0xdbff) {
            end--;
          }
          _writeLine('[BugaoshanDiagnostic $label] ${line.substring(start, end)}');
          start = end;
        }
      }
    } catch (_) {
      // Logging must not trigger another unhandled-error reporting cycle.
    }
  }
}
