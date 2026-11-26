import 'dart:async';
import 'dart:convert';

import 'package:bugaoshan/models/release_info.dart';
import 'package:bugaoshan/models/version_info.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/download_notification_service.dart';
import 'package:bugaoshan/services/github_resource_service.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// downloadAndInstall 被覆写，注入的 resource 不会真正发请求；
/// 用空 MockClient 构造以避免触碰网络。
final _stubResourceClient = MockClient((_) async => http.Response('', 404));

/// 可控的 UpdateService 替身：downloadAndInstall 挂起在 Completer 上，
/// 由测试主动 complete / 注入错误。
class _ControllableUpdateService extends UpdateService {
  _ControllableUpdateService(SharedPreferences prefs)
    : super(
        prefs,
        '2.5.3',
        GithubResourceService(
          AppConfigProvider(prefs),
          client: _stubResourceClient,
        ),
      );

  /// 覆盖基类基于平台与安装来源的判定：宿主测试平台不一定是 Android，
  /// 红点逻辑需要能显式模拟「支持 / 不支持应用内更新」两种渠道。
  bool supportsInAppUpdateOverride = true;

  @override
  bool get supportsInAppUpdate => supportsInAppUpdateOverride;

  /// 主线检查结果由测试指定，避免走真实网络与平台判定。
  UpdateCheckResult checkResult = UpdateCheckResult.noUpdate();

  @override
  Future<UpdateCheckResult> checkForUpdate() async => checkResult;

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

  /// 下载成功/取消后的收尾通知。基类的实现会走 MethodChannel，
  /// 在单测里抛 MissingPluginException——这是下载路径的必经步骤，必须覆盖。
  @override
  Future<void> cancel() async {}
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
  late AppConfigProvider appConfig;
  late _ControllableUpdateService service;
  late UpdateProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    appConfig = AppConfigProvider(prefs);
    // 红点由 AppConfigProvider 持久化，需接上层监听才能断言落盘结果。
    await appConfig.init();
    service = _ControllableUpdateService(prefs);
    provider = UpdateProvider(
      service,
      _StubAppInfo(),
      _StubNotification(),
      appConfig,
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
      appConfig,
    );
    expect(() => other.dispose(), returnsNormally);
  });

  test(
    'developer results stay noUpdate when platform packages are absent',
    () async {
      final realService = UpdateService(
        prefs,
        '2.5.3',
        GithubResourceService(
          AppConfigProvider(prefs),
          client: _stubResourceClient,
        ),
      );
      final realProvider = UpdateProvider(
        realService,
        _StubAppInfo(),
        _StubNotification(),
        appConfig,
      );
      addTearDown(realProvider.dispose);
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {'tag_name': 'v2.5.4', 'prerelease': false, 'assets': []},
            {'tag_name': 'v2.5.5-preview', 'prerelease': true, 'assets': []},
          ]),
          200,
        ),
      );
      addTearDown(client.close);
      final (stable, preview) = await http.runWithClient(
        realProvider.getAllLatestReleases,
        () => client,
      );
      expect(stable, isNull);
      expect(preview, isNull);
      expect(realProvider.stableResult.value.noUpdate, isTrue);
      expect(realProvider.previewResult.value.noUpdate, isTrue);
    },
  );

  group('更新红点（#448）', () {
    UpdateCheckResult hasUpdateResult() => UpdateCheckResult.hasUpdate(
      const ReleaseInfo(
        tagName: 'v2.5.4',
        downloadUrl: 'https://example.com/bugaoshan_2.5.4.apk',
        filename: 'bugaoshan_2.5.4.apk',
      ),
    );

    test('不支持应用内更新的渠道即使检查到新版本也不点亮红点', () {
      service.supportsInAppUpdateOverride = false;
      expect(provider.updateBadgeFor(hasUpdateResult()), isFalse);
    });

    test('不支持应用内更新时熄灭从其它渠道覆盖安装残留的红点', () {
      service.supportsInAppUpdateOverride = false;
      expect(provider.updateBadgeFor(UpdateCheckResult.noUpdate()), isFalse);
    });

    test('支持应用内更新时检查到新版本点亮红点', () {
      service.supportsInAppUpdateOverride = true;
      expect(provider.updateBadgeFor(hasUpdateResult()), isTrue);
    });

    test('支持应用内更新且确认没有更新时熄灭旧红点', () {
      service.supportsInAppUpdateOverride = true;
      expect(provider.updateBadgeFor(UpdateCheckResult.noUpdate()), isFalse);
    });

    test('检查出错时保持红点原状，网络抖动不抹掉已有提示', () {
      service.supportsInAppUpdateOverride = true;
      expect(provider.updateBadgeFor(UpdateCheckResult.error('boom')), isNull);
    });
  });

  // 覆盖首页接线：页面只调 checkForUpdateInBackground 一次，红点的写入与
  // 渠道判定都在这条路径上。有人把这里改回「只看 result.hasUpdate」时，
  // 本组第一个用例会失败（#448）。
  group('后台检查写入红点（#448 接线）', () {
    UpdateCheckResult hasUpdateResult() => UpdateCheckResult.hasUpdate(
      const ReleaseInfo(
        tagName: 'v2.5.4',
        downloadUrl: 'https://example.com/bugaoshan_2.5.4.apk',
        filename: 'bugaoshan_2.5.4.apk',
      ),
    );

    test('不支持应用内更新时，即使检查到新版本也熄灭红点并落盘', () async {
      service
        ..supportsInAppUpdateOverride = false
        ..checkResult = hasUpdateResult();
      appConfig.hasUpdateNotification.value = true;

      await provider.checkForUpdateInBackground();

      expect(appConfig.hasUpdateNotification.value, isFalse);
      expect(prefs.getBool('hasUpdateNotification'), isFalse);
    });

    test('不支持应用内更新时，检查报错也熄灭残留红点（无网首启场景）', () async {
      service
        ..supportsInAppUpdateOverride = false
        ..checkResult = UpdateCheckResult.error('offline');
      appConfig.hasUpdateNotification.value = true;

      await provider.checkForUpdateInBackground();

      expect(appConfig.hasUpdateNotification.value, isFalse);
    });

    test('支持应用内更新时，检查到新版本点亮红点并落盘', () async {
      service
        ..supportsInAppUpdateOverride = true
        ..checkResult = hasUpdateResult();
      appConfig.hasUpdateNotification.value = false;

      await provider.checkForUpdateInBackground();

      expect(appConfig.hasUpdateNotification.value, isTrue);
      expect(prefs.getBool('hasUpdateNotification'), isTrue);
    });

    test('支持应用内更新且确认没有更新时熄灭旧红点', () async {
      service
        ..supportsInAppUpdateOverride = true
        ..checkResult = UpdateCheckResult.noUpdate();
      appConfig.hasUpdateNotification.value = true;

      await provider.checkForUpdateInBackground();

      expect(appConfig.hasUpdateNotification.value, isFalse);
    });

    test('检查出错时红点保持原状，网络抖动不抹掉已有提示', () async {
      service
        ..supportsInAppUpdateOverride = true
        ..checkResult = UpdateCheckResult.error('boom');
      appConfig.hasUpdateNotification.value = true;

      await provider.checkForUpdateInBackground();

      expect(appConfig.hasUpdateNotification.value, isTrue);
      expect(prefs.getBool('hasUpdateNotification'), isTrue);
    });
  });
}
