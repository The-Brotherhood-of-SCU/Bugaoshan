import 'dart:async';

import 'package:bugaoshan/platform/platform_adapter.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _OhosAdapter extends PlatformAdapter {
  Future<int?> Function() readApiVersion = () async => 26;

  @override
  bool get isOhos => true;

  @override
  Future<int?> getOhosApiVersion() => readApiVersion();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bugaoshan/reminder');
  late MethodChannelReminderTransport transport;
  late PlatformAdapter original;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    original = PlatformAdapter.instance;
    transport = MethodChannelReminderTransport();
  });

  tearDown(() {
    PlatformAdapter.instance = original;
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('OHOS pending limit', () {
    late _OhosAdapter adapter;
    setUp(() {
      adapter = _OhosAdapter();
      PlatformAdapter.instance = adapter;
    });

    test('Dart selects the budget at the API 26 boundary', () async {
      for (final entry in {20: 30, 25: 30, 26: 64, 27: 64}.entries) {
        adapter.readApiVersion = () async => entry.key;
        expect(
          await MethodChannelReminderTransport().getPendingLimit(),
          entry.value,
        );
      }
    });

    test(
      'concurrent reads share one API query and cache the computed budget',
      () async {
        final response = Completer<int>();
        var calls = 0;
        adapter.readApiVersion = () async {
          calls++;
          return response.future;
        };

        final results = Future.wait([
          transport.getPendingLimit(),
          transport.getPendingLimit(),
        ]);
        await pumpEventQueue();
        expect(calls, 1);
        response.complete(26);
        expect(await results, [64, 64]);
        expect(await transport.getPendingLimit(), 64);
        expect(calls, 1);
      },
    );

    test(
      'invalid responses fail instead of disabling the limit and can retry',
      () async {
        for (final invalid in <int?>[null, 0, -1]) {
          adapter.readApiVersion = () async => invalid;
          await expectLater(transport.getPendingLimit(), throwsStateError);
        }
        adapter.readApiVersion = () async => 25;
        expect(await transport.getPendingLimit(), 30);
      },
    );

    test(
      'missing method and native failures propagate without caching',
      () async {
        adapter.readApiVersion = () async => throw MissingPluginException();
        await expectLater(
          transport.getPendingLimit(),
          throwsA(isA<MissingPluginException>()),
        );
        adapter.readApiVersion = () async =>
            throw PlatformException(code: 'DEVICE_INFO_FAILED');
        await expectLater(
          transport.getPendingLimit(),
          throwsA(isA<PlatformException>()),
        );
        adapter.readApiVersion = () async => 26;
        expect(await transport.getPendingLimit(), 64);
      },
    );
  });

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
