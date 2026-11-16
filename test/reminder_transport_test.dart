import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bugaoshan/reminder');
  const transport = MethodChannelReminderTransport();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'native grant and denial remain distinct authorization results',
    () async {
      for (final granted in [true, false]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestAuthorization');
          expect(call.arguments, {'provisional': false});
          return granted;
        });
        expect(await transport.requestAuthorization(), granted);
      }
    },
  );

  test('missing native channel is unavailable, not denied', () async {
    await expectLater(
      transport.requestAuthorization(),
      throwsA(isA<ReminderTransportUnavailable>()),
    );
  });

  test(
    'unsupported host and empty response are unavailable, not denied',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(
          code: MethodChannelReminderTransport.unsupportedPlatformCode,
        ),
      );
      await expectLater(
        transport.requestAuthorization(),
        throwsA(isA<ReminderTransportUnavailable>()),
      );
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await expectLater(
        transport.requestAuthorization(),
        throwsA(isA<ReminderTransportUnavailable>()),
      );
    },
  );

  test('native authorization errors reach the caller', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(
        code: 'AUTHORIZATION_FAILED',
        message: 'System authorization failed',
      ),
    );
    await expectLater(
      transport.requestAuthorization(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'AUTHORIZATION_FAILED',
        ),
      ),
    );
  });
}
