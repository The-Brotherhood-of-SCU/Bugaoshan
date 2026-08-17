import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bugaoshan/pages/feedback/feedback_page.dart';
import 'package:bugaoshan/services/sentry/sentry_service.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// 全局异常 → Sentry → 反馈弹窗的协调器。
///
/// [attach] 会在 Sentry 初始化后包一层全局错误处理器：
/// - Flutter 框架异常由 Sentry 自带的 FlutterErrorIntegration 上报，这里只负责弹窗；
/// - Zone/异步未捕获异常由本协调器调用 SentryService 上报后再弹窗。
class ErrorFeedbackCoordinator {
  ErrorFeedbackCoordinator(this._sentry);

  final SentryService _sentry;

  static const Duration _cooldown = Duration(seconds: 15);

  bool _pageShowing = false;
  DateTime? _lastShownAt;

  void attach() {
    final previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterErrorHandler?.call(details);
      _handleFlutterError(details);
    };

    final previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      final handled = previousPlatformErrorHandler?.call(error, stack) ?? true;
      unawaited(_handlePlatformError(error, stack));
      return handled;
    };
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // Sentry 的 FlutterErrorIntegration 已经完成上报，避免重复 capture。
    _showFeedbackPage(
      trigger: FeedbackTrigger.crash,
      errorSummary: details.exceptionAsString(),
    );
  }

  Future<void> _handlePlatformError(Object error, StackTrace? stack) async {
    await _sentry.captureException(error, stack, source: 'platform');
    _showFeedbackPage(
      trigger: FeedbackTrigger.crash,
      errorSummary: error.toString(),
    );
  }

  /// 用户主动打开反馈页（“我的”页面入口）。
  Future<void> openFeedbackPage({BuildContext? context}) async {
    if (_pageShowing) return;
    final rootContext = context ?? navigatorKey.currentContext;
    if (rootContext == null) return;

    _pageShowing = true;
    try {
      await popupOrNavigate(
        rootContext,
        FeedbackPage(sentryService: _sentry, trigger: FeedbackTrigger.manual),
      );
    } catch (err) {
      if (kDebugMode) {
        debugPrint('ErrorFeedbackCoordinator: open feedback page failed: $err');
      }
    } finally {
      _pageShowing = false;
    }
  }

  void _showFeedbackPage({
    required FeedbackTrigger trigger,
    required String errorSummary,
  }) {
    if (!_sentry.isEnabled || _pageShowing) return;
    final now = DateTime.now();
    if (_lastShownAt != null && now.difference(_lastShownAt!) < _cooldown) {
      return;
    }
    _lastShownAt = now;
    _pageShowing = true;

    unawaited(_openWhenNavigatorReady(trigger, errorSummary));
  }

  Future<void> _openWhenNavigatorReady(
    FeedbackTrigger trigger,
    String errorSummary,
  ) async {
    // 异常可能发生在首帧构建前，此时 navigatorKey 还没有 context，
    // 轮询等待 MaterialApp 挂载后再弹。
    BuildContext? rootContext;
    for (var attempt = 0; attempt < 20; attempt++) {
      rootContext = navigatorKey.currentContext;
      if (rootContext != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (rootContext == null || !rootContext.mounted) {
      _pageShowing = false;
      return;
    }

    try {
      await popupOrNavigate(
        rootContext,
        FeedbackPage(
          sentryService: _sentry,
          trigger: trigger,
          initialErrorSummary: errorSummary,
        ),
      );
    } catch (err) {
      if (kDebugMode) {
        debugPrint('ErrorFeedbackCoordinator: auto feedback page failed: $err');
      }
    } finally {
      _pageShowing = false;
    }
  }
}
