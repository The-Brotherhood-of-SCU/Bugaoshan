import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

import 'package:bugaoshan/utils/app_log.dart';

typedef ImageFailureCallback = void Function(Object? error, StackTrace? stack);

/// 一次图片展示只记录同一来源的首次失败，避免 errorBuilder 随重建刷屏。
class ImageErrorReporter {
  Object? _source;
  bool _reported = false;

  void reset() {
    _source = null;
    _reported = false;
  }

  void report(
    Object source,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_source != source) {
      _source = source;
      _reported = false;
    }
    if (_reported) return;
    _reported = true;
    void write() =>
        AppLog.e(tag, message, error: error, stackTrace: stackTrace);
    // errorBuilder 在 build 中执行；日志订阅者的重建应留到本帧构建完成后。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => write());
    } else {
      write();
    }
  }
}

/// 给 StatelessWidget 中的图片保留去重状态，生命周期跟随当前图片位置。
class ImageErrorLog extends StatefulWidget {
  const ImageErrorLog({
    super.key,
    required this.source,
    required this.tag,
    required this.message,
    required this.builder,
  });

  final Object source;
  final String tag;
  final String message;
  final Widget Function(ImageFailureCallback report) builder;

  @override
  State<ImageErrorLog> createState() => _ImageErrorLogState();
}

class _ImageErrorLogState extends State<ImageErrorLog> {
  final _reporter = ImageErrorReporter();

  @override
  void didUpdateWidget(covariant ImageErrorLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _reporter.reset();
  }

  @override
  Widget build(BuildContext context) => widget.builder((error, stack) {
    _reporter.report(
      widget.source,
      widget.tag,
      widget.message,
      error: error,
      stackTrace: stack,
    );
  });
}
