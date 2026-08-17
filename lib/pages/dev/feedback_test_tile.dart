import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/sentry/error_feedback_coordinator.dart';

/// TestPage 入口：问题反馈调试。
/// 可直接打开反馈页，或抛出一个未捕获异常验证自动弹窗链路。
class FeedbackTestTile extends StatelessWidget {
  const FeedbackTestTile({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final coordinator = getIt<ErrorFeedbackCoordinator>();

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: Text(localizations.feedbackTestOpen),
          subtitle: Text(localizations.feedback),
          onTap: () => coordinator.openFeedbackPage(context: context),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: Text(localizations.feedbackTestCrash),
          onTap: () {
            // 触发 FlutterError.onError → Sentry 上报 → 自动弹出反馈页。
            throw StateError('Bugaoshan feedback test exception');
          },
        ),
      ],
    );
  }
}
