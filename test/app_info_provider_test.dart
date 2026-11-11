import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockProbe(Future<Object?>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kUpdateMethodChannel, handler);
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    mockProbe(null);
  });

  test('已知客户端包名直接判定，不触发原生探测', () async {
    var probed = false;
    mockProbe((call) async {
      probed = true;
      return false;
    });

    expect(
      await AppInfoProvider.resolveFdroidInstall('org.fdroid.fdroid'),
      isTrue,
    );
    expect(probed, isFalse);
  });

  test('installer 未知时采用原生探测结果', () async {
    MethodCall? received;
    mockProbe((call) async {
      received = call;
      return true;
    });

    expect(
      await AppInfoProvider.resolveFdroidInstall('com.example.otherstore'),
      isTrue,
    );
    expect(received?.method, 'isFdroidInstaller');
    expect(received?.arguments, {'installer': 'com.example.otherstore'});
  });

  test('原生探测返回 null 时判定为非 F-Droid', () async {
    mockProbe((call) async => null);

    expect(
      await AppInfoProvider.resolveFdroidInstall('com.example.otherstore'),
      isFalse,
    );
  });

  test('installer 为空时判定为非 F-Droid', () async {
    expect(await AppInfoProvider.resolveFdroidInstall(null), isFalse);
    expect(await AppInfoProvider.resolveFdroidInstall(''), isFalse);
  });

  test('探测失败时 fail-open，判定为非 F-Droid', () async {
    mockProbe((call) async => throw PlatformException(code: 'boom'));

    expect(
      await AppInfoProvider.resolveFdroidInstall('com.github.android'),
      isFalse,
    );
  });

  test('非 Android 平台不探测，直接判定为非 F-Droid', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    var probed = false;
    mockProbe((call) async {
      probed = true;
      return true;
    });

    expect(
      await AppInfoProvider.resolveFdroidInstall('com.example.otherstore'),
      isFalse,
    );
    expect(probed, isFalse);
  });
}
