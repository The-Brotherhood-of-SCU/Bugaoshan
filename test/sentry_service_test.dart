import 'package:flutter_test/flutter_test.dart';

import 'package:bugaoshan/services/sentry/sentry_service.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

void main() {
  test(
    'SentryService disables submission when DSN is not configured',
    () async {
      final service = SentryService(AuthLogger());

      expect(service.isEnabled, isFalse);
      await expectLater(
        service.submitFeedback(
          const FeedbackSubmission(
            description: 'test',
            trigger: FeedbackTrigger.manual,
          ),
        ),
        throwsA(isA<SentryNotConfiguredException>()),
      );
    },
  );
}
