import 'package:bugaoshan/ohos_bootstrap/ohos_platform_adapter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _OhosHost extends OhosPlatformAdapter {
  @override
  bool get isOhos => true;
}

class _NonOhosHost extends OhosPlatformAdapter {
  @override
  bool get isOhos => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const picker = MethodChannel('bugaoshan/file_picker');
  const environment = MethodChannel('bugaoshan/environment_info');
  final adapter = _OhosHost();

  tearDown(() {
    messenger.setMockMethodCallHandler(picker, null);
    messenger.setMockMethodCallHandler(environment, null);
  });

  test(
    'selected document snapshots preserve names and distinct local paths',
    () async {
      messenger.setMockMethodCallHandler(picker, (call) async {
        expect(call.method, 'pickFiles');
        expect(call.arguments, {
          'allowedExtensions': ['pdf', 'docx'],
        });
        return [
          {'name': '讲义.pdf', 'path': '/cache/selection/0/讲义.pdf'},
          {'name': '讲义.pdf', 'path': '/cache/selection/1/讲义.pdf'},
        ];
      });
      final files = await adapter.pickFiles(allowedExtensions: ['pdf', 'docx']);
      expect(files.map((file) => file.name), ['讲义.pdf', '讲义.pdf']);
      expect(files.map((file) => file.path), [
        '/cache/selection/0/讲义.pdf',
        '/cache/selection/1/讲义.pdf',
      ]);
    },
  );

  test('canceling the native file picker returns an empty selection', () async {
    messenger.setMockMethodCallHandler(picker, (_) async => []);
    expect(await adapter.pickFiles(allowedExtensions: ['pdf']), isEmpty);
  });

  test(
    'native picker failures remain failures for the printing page',
    () async {
      messenger.setMockMethodCallHandler(picker, (_) async {
        throw PlatformException(code: 'PICK_FAILED');
      });
      await expectLater(
        adapter.pickFiles(allowedExtensions: ['pdf']),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'PICK_FAILED',
          ),
        ),
      );
    },
  );

  test('device info uses the app-owned OHOS channel', () async {
    messenger.setMockMethodCallHandler(environment, (call) async {
      expect(call.method, 'getDeviceInfo');
      return {'brand': 'Huawei', 'model': 'test-device', 'sdkApiVersion': '26'};
    });
    expect(await adapter.getDeviceInfo(), {
      'brand': 'Huawei',
      'model': 'test-device',
      'sdkApiVersion': '26',
    });
    expect(await adapter.getOhosApiVersion(), 26);
  });

  test('OHOS API reading accepts numbers and rejects malformed device info', () async {
    messenger.setMockMethodCallHandler(environment, (_) async => {'sdkApiVersion': 25});
    expect(await adapter.getOhosApiVersion(), 25);
    for (final invalid in <Object?>[null, 'invalid', 26.5]) {
      messenger.setMockMethodCallHandler(environment, (_) async => {'sdkApiVersion': invalid});
      expect(await adapter.getOhosApiVersion(), isNull);
    }
  });

  test('non-OHOS hosts do not query the OHOS API channel', () async {
    messenger.setMockMethodCallHandler(environment, (_) async {
      fail('OHOS channel must not be called');
    });
    expect(await _NonOhosHost().getOhosApiVersion(), isNull);
  });
}
