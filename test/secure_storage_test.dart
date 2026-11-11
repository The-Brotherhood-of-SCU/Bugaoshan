import 'package:bugaoshan/utils/secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Mac credential operations never probe the legacy login keychain',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final storage = SecureStorageProvider.instance;
      await storage.read(key: 'session');
      await storage.write(key: 'session', value: 'test-token');
      await storage.delete(key: 'session');
      expect(calls.map((call) => call.method), ['read', 'write', 'delete']);
      for (final call in calls) {
        final options = (call.arguments as Map)['options'] as Map;
        expect(options['usesDataProtectionKeychain'], 'true');
        expect(
          options['accountName'],
          'io.github.thebrotherhoodofscu.bugaoshan.ios.credentials',
        );
        expect(options['accessibility'], 'first_unlock_this_device');
        expect(options['synchronizable'], 'false');
      }
    },
  );

  test('iOS keeps its existing credential service and accessibility', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await SecureStorageProvider.instance.read(key: 'session');
    final options = (calls.single.arguments as Map)['options'] as Map;
    expect(options['accountName'], 'flutter_secure_storage_service');
    expect(options['accessibility'], 'first_unlock_this_device');
    expect(options.containsKey('usesDataProtectionKeychain'), isFalse);
  });
}
