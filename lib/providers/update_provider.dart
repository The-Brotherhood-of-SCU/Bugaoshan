import 'package:flutter/foundation.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/release_info.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/download_notification_service.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/widgets/dialog/download_progress_dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

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
  UpdateProvider(this._service, this._appInfo, this._notification);

  final UpdateService _service;
  final AppInfoProvider _appInfo;
  final DownloadNotificationService _notification;

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
  /// [filename] 用于在通知栏标题展示下载文件名。
  /// 抛出 [UpdateCancelledException] / 其他异常,由调用方(dialog 函数)处理。
  Future<void> downloadAndInstall({
    required String version,
    required String downloadUrl,
    required String filename,
    String? checksumSha256,
  }) {
    final existing = _downloadInFlight;
    if (existing != null) return existing;
    final future = _doDownloadAndInstall(
      version: version,
      downloadUrl: downloadUrl,
      filename: filename,
      checksumSha256: checksumSha256,
    );
    _downloadInFlight = future;
    return future;
  }

  Future<void> _doDownloadAndInstall({
    required String version,
    required String downloadUrl,
    required String filename,
    String? checksumSha256,
  }) async {
    isDownloading.value = true;
    progressState.reset();
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    // 监听通知栏"取消"按钮事件,转发到同一 CancelToken
    final cancelSub = _notification.onCancelButtonPressed.listen((_) {
      cancelToken.cancel();
    });

    // 通过 navigatorKey 拿到根 context,用于取 ARB 本地化文案。
    // Provider 是 DI 单例,不持有 BuildContext,这里在调用时取最新值。
    // 必须在任何 await 之前取,避免触发 use_build_context_synchronously。
    final l10n = AppLocalizations.of(logicRootContext);

    // 请求通知权限(失败不阻断下载,仅不显示通知)
    await _notification.requestPermission();

    // 显示初始通知(indeterminate,因为 total 未知)
    // 通知标题展示文件名,让用户在通知栏一眼看到下载的是哪个文件
    await _notification.showDownloadNotification(
      content: l10n?.notificationDownloading(0) ?? 'Downloading... 0%',
      indeterminate: true,
      title: filename,
    );

    try {
      await _service.downloadAndInstall(
        version,
        downloadUrl,
        checksumSha256: checksumSha256,
        cancelToken: cancelToken,
        onStatus: (s) {
          progressState.setStatus(s);
          // 状态变化(Verifying / Installing / Extracting):切到 indeterminate
          _notification.updateProgress(
            content: s,
            indeterminate: progressState.total == 0,
            title: filename,
          );
        },
        onProgress: (r, t) {
          progressState.setProgress(r, t);
          if (t > 0) {
            _notification.updateProgress(
              content:
                  l10n?.notificationDownloading(progressState.percent) ??
                  'Downloading... ${progressState.percent}%',
              progress: progressState.percent,
              max: 100,
              indeterminate: false,
              title: filename,
            );
          }
        },
      );
      // 下载完成 → 取消下载通知
      // Android: 系统 PackageInstaller 对话框已弹出作为唯一 UI 反馈,
      // Flutter 端无法感知用户在系统对话框点"取消安装",若保留"正在安装"
      // 通知会一直残留。直接取消更符合用户预期。
      // 其他平台: showCompleted 本身就是 no-op (isSupported false)。
      await _notification.cancel();
    } on UpdateCancelledException {
      // 用户取消(通知栏按钮或 App 内取消按钮)→ 关闭通知,异常继续向上抛
      await _notification.cancel();
      rethrow;
    } catch (e) {
      // 其他错误 → 显示错误通知,异常继续向上抛由 dialog 处理
      await _notification.showError(
        content:
            l10n?.notificationUpdateFailed(e.toString()) ?? 'Update failed: $e',
        title: filename,
      );
      rethrow;
    } finally {
      await cancelSub.cancel();
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
    _notification.dispose();
  }
}
