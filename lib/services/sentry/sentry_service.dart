import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:bugaoshan/utils/auth_logger.dart';

/// Sentry DSN，通过编译参数注入：
/// `flutter run --dart-define=SENTRY_DSN=https://xxx@oXXX.ingest.sentry.io/XXX`
/// 未配置时 Sentry 采集为禁用状态（本地开发不需要额外配置）。
const String kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// CI 注入的 Git tag，用作 Sentry release；本地构建为空。
const String _sentryRelease = String.fromEnvironment('GIT_TAG');

/// 反馈触发方式。
enum FeedbackTrigger { crash, manual }

/// 用户额外选择的日志附件。
class FeedbackLogAttachment {
  const FeedbackLogAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

/// 一次用户反馈的完整内容。
class FeedbackSubmission {
  const FeedbackSubmission({
    required this.description,
    required this.trigger,
    this.contact,
    this.errorSummary,
    this.screenshotBytes,
    this.logFiles = const [],
    this.includeAppLog = true,
  });

  final String description;
  final String? contact;
  final FeedbackTrigger trigger;

  /// 自动弹出时附带的异常摘要（不含完整堆栈，堆栈已随异常事件上报）。
  final String? errorSummary;

  /// 用户选择的截图（PNG/JPEG 字节）。
  final Uint8List? screenshotBytes;

  /// 用户额外选择的日志文件。
  final List<FeedbackLogAttachment> logFiles;

  /// 是否自动附带应用内置的认证运行日志。
  final bool includeAppLog;
}

/// Sentry 未配置（缺少 SENTRY_DSN）时提交反馈抛出。
class SentryNotConfiguredException implements Exception {
  const SentryNotConfiguredException();

  @override
  String toString() =>
      'Sentry DSN is not configured. Add --dart-define=SENTRY_DSN=...';
}

/// Sentry 初始化、异常上报与用户反馈提交的封装。
///
/// - [initialize] 必须在 `WidgetsFlutterBinding.ensureInitialized()` 之后调用；
/// - 自动异常弹窗由 [ErrorFeedbackCoordinator] 负责，本服务不依赖 UI。
class SentryService {
  SentryService(this._authLogger, {String Function()? versionProvider})
    : _versionProvider =
          versionProvider ??
          (() => _sentryRelease.isNotEmpty ? _sentryRelease : 'unknown');

  final AuthLogger _authLogger;
  final String Function() _versionProvider;

  bool _initialized = false;
  SentryId? _lastErrorEventId;

  bool get initialized => _initialized;

  /// 是否真正启用了 Sentry（已初始化且配置了 DSN）。
  bool get isEnabled => _initialized && kSentryDsn.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kSentryDsn.isEmpty) {
      if (kDebugMode) {
        debugPrint('SentryService: SENTRY_DSN 未配置，Sentry 已禁用');
      }
      return;
    }
    await SentryFlutter.init((options) {
      options
        ..dsn = kSentryDsn
        ..tracesSampleRate = 1.0
        ..attachStacktrace = true
        ..sendDefaultPii = false
        ..environment = kReleaseMode ? 'production' : 'development';
      if (_sentryRelease.isNotEmpty) {
        options.release = _sentryRelease;
      }
    });
    _initialized = true;
  }

  /// 上报异常，返回事件 id；未启用 Sentry 时返回 null。
  Future<SentryId?> captureException(
    Object exception,
    StackTrace? stackTrace, {
    String source = 'unknown',
  }) async {
    if (!isEnabled) return null;
    try {
      final eventId = await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('error.source', source);
        },
      );
      _lastErrorEventId = eventId;
      return eventId;
    } catch (err) {
      // 上报失败不能反过来影响应用运行。
      if (kDebugMode) {
        debugPrint('SentryService: captureException failed: $err');
      }
      return null;
    }
  }

  /// 以 Sentry User Feedback 事件提交用户反馈，并通过 scope 附带截图与日志。
  Future<void> submitFeedback(FeedbackSubmission submission) async {
    if (!isEnabled) {
      throw const SentryNotConfiguredException();
    }

    final contact = submission.contact;
    final feedback = SentryFeedback(
      message: submission.description,
      contactEmail: (contact != null && contact.contains('@')) ? contact : null,
    );
    if (_lastErrorEventId != null) {
      feedback.associatedEventId = _lastErrorEventId;
    }

    await Sentry.captureFeedback(
      feedback,
      withScope: (scope) {
        scope
          ..fingerprint = ['bugaoshan-user-feedback']
          ..setTag('feedback.kind', submission.trigger.name)
          ..setTag(
            'feedback.has_screenshot',
            (submission.screenshotBytes?.isNotEmpty ?? false).toString(),
          )
          ..setContexts('feedback', {
            'description': submission.description,
            'contact': contact ?? '',
            'error_summary': submission.errorSummary ?? '',
            'log_file_count': submission.logFiles.length,
          });

        if (submission.screenshotBytes?.isNotEmpty ?? false) {
          scope.addAttachment(
            SentryAttachment.fromScreenshotData(submission.screenshotBytes!),
          );
        }

        if (submission.includeAppLog) {
          final authLogText = _authLogger.exportToText(includeDate: true);
          scope.addAttachment(
            SentryAttachment.fromUint8List(
              Uint8List.fromList(utf8.encode(authLogText)),
              _buildAppLogFileName(),
              contentType: 'text/plain; charset=utf-8',
            ),
          );
        }

        for (final logFile in submission.logFiles) {
          scope.addAttachment(
            SentryAttachment.fromUint8List(
              logFile.bytes,
              logFile.fileName,
              contentType: 'text/plain; charset=utf-8',
            ),
          );
        }
      },
    );
  }

  /// 应用日志附件文件名：`yyyyMMdd-HHmmss-<版本>.log`。
  String _buildAppLogFileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return '$timestamp-${_versionProvider()}.log';
  }
}
