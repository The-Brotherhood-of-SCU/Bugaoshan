import 'dart:async';

import 'package:bugaoshan/models/version_info.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/download_notification_service.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可控的 UpdateService 替身：downloadAndInstall 挂起在 Completer 上，
/// 由测试主动 complete / 注入错误。
class _ControllableUpdateService extends UpdateService {
  _ControllableUpdateService(SharedPreferences prefs) : super(prefs, '2.5.3');

  Completer<void>? _downloadCompleter;
  Object? nextError;
  int downloadCalls = 0;

  Completer<void>? get downloadCompleter => _downloadCompleter;

  @override
  Future<void> downloadAndInstall(
    String version,
    String downloadUrl, {
    String? checksumSha256,
    CancelToken? cancelToken,
    void Function(String status)? onStatus,
    void Function(int received, int total)? onProgress,
  }) {
    downloadCalls++;
    final error = nextError;
    if (error != null) {
      nextError = null;
      return Future<void>.error(error);
    }
    final completer = Completer<void>();
    _downloadCompleter = completer;
    return completer.future;
  }
}

/// 通知服务替身：方法通道调用全部置空，避免测试环境 MissingPluginException。
class _StubNotification extends DownloadNotificationService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showDownloadNotification({
    required String content,
    int progress = 0,
    int max = 100,
    bool indeterminate = false,
    String? title,
  }) async {}

  @override
  Future<void> updateProgress({
    required String content,
    int progress = 0,
    int max = 100,
    bool indeterminate = false,
    String? title,
  }) async {}

  @override
  Future<void> showCompleted({required String content, String? title}) async {}

  @override
  Future<void> showError({required String content, String? title}) async {}
}

/// AppInfo 替身：下载流程只读取 currentVersion，其余成员按需抛错。
class _StubAppInfo implements AppInfoProvider {
  @override
  PackageInfo get packageInfo => throw UnimplementedError();

  @override
  set packageInfo(PackageInfo _) {}

  @override
  String get currentVersion => '2.5.3';

  @override
  bool get isFdroidInstall => false;

  @override
  String get gitTag => 'v2.5.3';

  @override
  String get gitCommit => '';

  @override
  String get gitCommitDateRaw => '';

  @override
  String get shortCommit => '';

  @override
  Future<VersionInfo> getVersionInfo() async => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _ControllableUpdateService service;
  late UpdateProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = _ControllableUpdateService(prefs);
    provider = UpdateProvider(
      service,
      _StubAppInfo(),
      _StubNotification(),
    );
  });

  tearDown(() {
    provider.dispose();
  });

  test('download writes downloadingVersion for the in-flight version, '
    'then clears it on success', () async {
    final download = provider.downloadAndInstall(
      version: 'v2.5.3',
      downloadUrl: 'https://example.com/bugaoshan.apk',
      filename: 'bugaoshan_2.5.3.apk',
    );

    await pumpEventQueue();
    expect(provider.isDownloading.value, isTrue);
    expect(provider.downloadingVersion.value, 'v2.5.3');

    service.downloadCompleter!.complete();
    await download;

    expect(provider.isDownloading.value, isFalse);
    expect(provider.downloadingVersion.value, isNull);
  });

  test('re-entrant download call reuses in-flight future and does not '
    'overwrite downloadingVersion', () async {
    final download = provider.downloadAndInstall(
      version: 'v2.5.3',
      downloadUrl: 'https://example.com/bugaoshan.apk',
      filename: 'bugaoshan_2.5.3.apk',
    );
    await pumpEventQueue();
    expect(provider.downloadingVersion.value, 'v2.5.3');

    final second = provider.downloadAndInstall(
      version: 'v2.5.4',
      downloadUrl: 'https://example.com/bugaoshan-2.5.4.apk',
      filename: 'bugaoshan_2.5.4.apk',
    );

    expect(identical(download, second), isTrue);
    expect(service.downloadCalls, 1);
    // 重入不覆盖正在下载的版本号。
    expect(provider.downloadingVersion.value, 'v2.5.3');

    service.downloadCompleter!.complete();
    await download;
    expect(provider.downloadingVersion.value, isNull);
  });

  test('failed download clears downloadingVersion', () async {
    service.nextError = Exception('download exploded');
    await expectLater(
      provider.downloadAndInstall(
        version: 'v2.5.3',
        downloadUrl: 'https://example.com/bugaoshan.apk',
        filename: 'bugaoshan_2.5.3.apk',
      ),
      throwsException,
    );

    expect(provider.isDownloading.value, isFalse);
    expect(provider.downloadingVersion.value, isNull);
  });

  test('dispose releases downloadingVersion notifier', () {
    final other = UpdateProvider(
      service,
      _StubAppInfo(),
      _StubNotification(),
    );
    expect(() => other.dispose(), returnsNormally);
  });
}
