import 'package:flutter/foundation.dart';
import 'package:bugaoshan/models/release_info.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/widgets/dialog/download_progress_dialog.dart';

/// 包裹 [UpdateService],将更新检查与下载安装的状态管理收进内部。
///
/// 通过多个 [ValueNotifier] 字段暴露细粒度状态(isChecking / isDownloading /
/// lastCheckResult / stableResult / previewResult),供 UI 用 [ValueListenableBuilder]
/// 监听。下载进度由内部持有的 [UpdateProgressState](ChangeNotifier)承载,UI 通过
/// [ListenableBuilder] 监听。
///
/// 所有异步方法都通过 in-flight Future 缓存实现重入保护:再次调用同一方法时
/// 直接返回之前缓存的 Future,await 得到第一次的结果。任务完成(finally)后置空,
/// 允许下次调用。
class UpdateProvider {
  UpdateProvider(this._service, this._appInfo);

  final UpdateService _service;
  final AppInfoProvider _appInfo;

  /// 主线更新检查(about_page / home_page)。true 表示正在请求 GitHub API。
  final ValueNotifier<bool> isChecking = ValueNotifier(false);

  /// 最近一次主线检查结果。null 表示从未检查过。
  final ValueNotifier<UpdateCheckResult?> lastCheckResult = ValueNotifier(null);

  /// DevPage 的 stable 检查结果(初始为 initial 状态)。
  final ValueNotifier<UpdateCheckResult> stableResult = ValueNotifier(
    UpdateCheckResult.initial(),
  );

  /// DevPage 的 preview 检查结果(初始为 initial 状态)。
  final ValueNotifier<UpdateCheckResult> previewResult = ValueNotifier(
    UpdateCheckResult.initial(),
  );

  /// 下载安装中。可被 UI 用于禁用按钮等。
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);

  /// 下载进度状态(ChangeNotifier)。UI 通过 ListenableBuilder 监听。
  final UpdateProgressState progressState = UpdateProgressState();

  Future<UpdateCheckResult>? _checkInFlight;
  Future<(ReleaseInfo?, ReleaseInfo?)>? _getAllInFlight;
  Future<void>? _downloadInFlight;
  CancelToken? _activeCancelToken;

  bool get supportsInAppUpdate => _service.supportsInAppUpdate;

  bool hasUpdate(String currentVersion, String latestVersion) =>
      _service.hasUpdate(currentVersion, latestVersion);

  /// 主线更新检查。重入时直接返回 in-flight Future。
  Future<UpdateCheckResult> checkForUpdate() {
    final existing = _checkInFlight;
    if (existing != null) return existing;
    final future = _doCheckForUpdate();
    _checkInFlight = future;
    return future;
  }

  Future<UpdateCheckResult> _doCheckForUpdate() async {
    isChecking.value = true;
    try {
      final result = await _service.checkForUpdate();
      lastCheckResult.value = result;
      return result;
    } finally {
      isChecking.value = false;
      _checkInFlight = null;
    }
  }

  /// DevPage 用的双检查。重入时直接返回 in-flight Future。
  ///
  /// 内部完成 stable/preview 版本比较并填充 [stableResult] / [previewResult]。
  /// 异常时填充 error 状态后 rethrow,调用方仍可感知。
  Future<(ReleaseInfo?, ReleaseInfo?)> getAllLatestReleases() {
    final existing = _getAllInFlight;
    if (existing != null) return existing;
    final future = _doGetAllLatestReleases();
    _getAllInFlight = future;
    return future;
  }

  Future<(ReleaseInfo?, ReleaseInfo?)> _doGetAllLatestReleases() async {
    stableResult.value = UpdateCheckResult.checking();
    previewResult.value = UpdateCheckResult.checking();
    try {
      final (stable, preview) = await _service.getAllLatestReleases();
      final currentVersion = _appInfo.currentVersion;
      final gitTag = _appInfo.gitTag;
      stableResult.value =
          (stable != null &&
              stable.tagName != null &&
              hasUpdate(currentVersion, stable.tagName!))
          ? UpdateCheckResult.hasUpdate(stable)
          : UpdateCheckResult.noUpdate();
      previewResult.value = (preview != null && preview.tagName != gitTag)
          ? UpdateCheckResult.hasUpdate(preview)
          : UpdateCheckResult.noUpdate();
      return (stable, preview);
    } catch (e) {
      final error = UpdateCheckResult.error(e.toString());
      stableResult.value = error;
      previewResult.value = error;
      rethrow;
    } finally {
      _getAllInFlight = null;
    }
  }

  /// 下载安装。重入时直接返回 in-flight Future。
  ///
  /// 抛出 [UpdateCancelledException] / 其他异常,由调用方(dialog 函数)处理。
  Future<void> downloadAndInstall({
    required String version,
    required String downloadUrl,
    String? checksumSha256,
  }) {
    final existing = _downloadInFlight;
    if (existing != null) return existing;
    final future = _doDownloadAndInstall(
      version: version,
      downloadUrl: downloadUrl,
      checksumSha256: checksumSha256,
    );
    _downloadInFlight = future;
    return future;
  }

  Future<void> _doDownloadAndInstall({
    required String version,
    required String downloadUrl,
    String? checksumSha256,
  }) async {
    isDownloading.value = true;
    progressState.reset();
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    try {
      await _service.downloadAndInstall(
        version,
        downloadUrl,
        checksumSha256: checksumSha256,
        cancelToken: cancelToken,
        onStatus: (s) => progressState.setStatus(s),
        onProgress: (r, t) => progressState.setProgress(r, t),
      );
    } finally {
      isDownloading.value = false;
      _activeCancelToken = null;
      _downloadInFlight = null;
    }
  }

  /// 取消当前下载(若有)。
  void cancelDownload() {
    _activeCancelToken?.cancel();
  }

  void dispose() {
    isChecking.dispose();
    lastCheckResult.dispose();
    stableResult.dispose();
    previewResult.dispose();
    isDownloading.dispose();
    progressState.dispose();
  }
}
