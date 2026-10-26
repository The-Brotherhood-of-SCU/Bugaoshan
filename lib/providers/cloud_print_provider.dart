import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:bugaoshan/models/cloud_print.dart';
import 'package:bugaoshan/services/api/cloud_print_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';

enum CloudPrintQueueStatus { pending, uploading, uploaded, failed, uncertain }

enum CloudPrintFailure { authentication, file, tooLarge, request, uncertain }

class CloudPrintQueueItem {
  CloudPrintQueueItem(this.file, this.options);
  final CloudPrintFile file;
  CloudPrintOptions options;
  CloudPrintQueueStatus status = CloudPrintQueueStatus.pending;
  CloudPrintFailure? failure;
  double progress = 0;
  bool verificationPending = false;
  bool duplicate = false;
}

/// 会话内保留批量队列；有限并发提交、成功项不重放，登出/换号丢弃旧账号结果。
class CloudPrintProvider extends ChangeNotifier {
  CloudPrintProvider(this._api, {ScuAuth? scuAuth, this.uploadConcurrency = 5})
    : _scu = scuAuth {
    _principal = _scu?.principal;
    _scu?.addListener(_onAuthChanged);
  }
  static const _tag = 'CloudPrintProvider';
  final CloudPrintApiService _api;

  /// 同时在传的文件数。上传是非幂等写，结果不确定时立即停止派发新文件，
  /// 已发出的请求各自等待结果，避免同一个文件被并发重传。
  final int uploadConcurrency;
  final ScuAuth? _scu;
  String? _principal;
  int _generation = 0;
  bool _disposed = false, _stopRequested = false;
  final List<CloudPrintQueueItem> _queue = [];
  final Map<int, String> _scanFiles = {};
  final Map<int, double> _scanProgress = {};
  final Set<int> _scanFailures = {};
  CloudPrintOptions defaults = const CloudPrintOptions();
  bool uploading = false,
      loadingJobs = false,
      loadingScans = false,
      selecting = false,
      downloading = false;
  bool jobsFailed = false, scansFailed = false;
  List<CloudPrintJob> jobs = [];
  List<CloudScanJob> scans = [];
  Future<void>? _jobsFuture, _scansFuture;
  List<CloudPrintQueueItem> get queue => List.unmodifiable(_queue);
  Map<int, String> get scanFiles => Map.unmodifiable(_scanFiles);
  Map<int, double> get scanProgress => Map.unmodifiable(_scanProgress);
  Set<int> get scanFailures => Set.unmodifiable(_scanFailures);
  int get pendingCount => _queue
      .where((item) => item.status == CloudPrintQueueStatus.pending)
      .length;
  int get failedCount => _queue
      .where((item) => item.status == CloudPrintQueueStatus.failed)
      .length;
  bool get stopRequested => _stopRequested;
  int get sessionGeneration => _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _onAuthChanged() {
    if (_scu!.state == AuthState.unknown ||
        (_principal != null && _principal != _scu.principal)) {
      clear();
    }
    _principal = _scu.principal;
  }

  Future<({int added, int duplicates, int invalid})> addPaths(
    Iterable<String> paths,
  ) async {
    // 上传进行中也允许继续加文件：新项进入队列后由空闲 worker 接着取走。
    if (selecting) return (added: 0, duplicates: 0, invalid: 0);
    final generation = _generation;
    selecting = true;
    _notify();
    var added = 0, duplicates = 0, invalid = 0;
    try {
      for (final path in paths) {
        if (!_current(generation)) break;
        try {
          final file = await CloudPrintFile.fromPath(path);
          if (!_current(generation)) break;
          // 只按实际路径去重；不同目录的同名文档仍可分别上传。
          if (_queue.any((item) => p.equals(item.file.path, file.path))) {
            duplicates++;
            continue;
          }
          _queue.add(CloudPrintQueueItem(file, defaults));
          added++;
        } catch (_, stack) {
          invalid++;
          AppLog.e(
            _tag,
            '所选文件不可用于打印',
            error: const ServiceException('文件不可读或格式不支持'),
            stackTrace: stack,
          );
        }
      }
    } finally {
      if (_current(generation)) {
        selecting = false;
        _notify();
      }
    }
    return (added: added, duplicates: duplicates, invalid: invalid);
  }

  void applyDefaults(CloudPrintOptions options) {
    if (uploading) return;
    options.toFields();
    defaults = options;
    for (final item in _queue) {
      if (item.status == CloudPrintQueueStatus.pending ||
          item.status == CloudPrintQueueStatus.failed) {
        item.options = options;
      }
    }
    _notify();
  }

  void updateOptions(CloudPrintQueueItem item, CloudPrintOptions options) {
    if (uploading ||
        ![
          CloudPrintQueueStatus.pending,
          CloudPrintQueueStatus.failed,
        ].contains(item.status)) {
      return;
    }
    options.toFields();
    item.options = options;
    _notify();
  }

  void remove(CloudPrintQueueItem item) {
    if (!uploading && !selecting) {
      _queue.remove(item);
      _notify();
    }
  }

  /// 已结束的记录（成功、失败、待核对）；「清理记录」只动这些，不碰待上传与上传中。
  int get finishedCount => _queue
      .where(
        (item) =>
            item.status == CloudPrintQueueStatus.uploaded ||
            item.status == CloudPrintQueueStatus.failed ||
            item.status == CloudPrintQueueStatus.uncertain,
      )
      .length;

  void clearFinished() {
    if (uploading) return;
    _queue.removeWhere(
      (item) =>
          item.status == CloudPrintQueueStatus.uploaded ||
          item.status == CloudPrintQueueStatus.failed ||
          item.status == CloudPrintQueueStatus.uncertain,
    );
    _notify();
  }

  void stopAfterCurrent() {
    _stopRequested = true;
    _notify();
  }

  /// 失败项重新排队并立刻开始上传，不必再点一次上传按钮。
  Future<void> retryFailed() async {
    if (uploading) return;
    var requeued = false;
    for (final item in _queue) {
      if (item.status != CloudPrintQueueStatus.failed) continue;
      item.status = CloudPrintQueueStatus.pending;
      item.failure = null;
      item.progress = 0;
      item.duplicate = false;
      requeued = true;
    }
    if (!requeued) return;
    _notify();
    await uploadPending();
  }

  void requeue(CloudPrintQueueItem item, {bool confirmedMissing = false}) {
    if (uploading ||
        (item.status != CloudPrintQueueStatus.failed &&
            !(item.status == CloudPrintQueueStatus.uncertain &&
                confirmedMissing))) {
      return;
    }
    item.status = CloudPrintQueueStatus.pending;
    item.failure = null;
    item.progress = 0;
    _notify();
  }

  /// 领取下一个待上传项。领取、改状态与清进度是同步的，多个 worker 不会拿到同一项。
  CloudPrintQueueItem? _claimPending() {
    for (final item in _queue) {
      if (item.status != CloudPrintQueueStatus.pending) continue;
      item.status = CloudPrintQueueStatus.uploading;
      item.progress = 0;
      item.failure = null;
      item.duplicate = false;
      return item;
    }
    return null;
  }

  Future<void> uploadPending() async {
    if (uploading || selecting || pendingCount == 0) return;
    final generation = _generation;
    uploading = true;
    _stopRequested = false;
    _notify();
    // 批次开始时取一次任务基线，并发上传期间不再逐文件前后对列表做两次查询。
    Set<int>? baseline;
    try {
      baseline = (await _api.fetchJobs()).map((job) => job.id).toSet();
    } catch (_, stack) {
      AppLog.w(
        _tag,
        '上传前任务基线读取失败',
        error: const ServiceException('待查询任务列表'),
        stackTrace: stack,
      );
    }
    if (!_current(generation)) return;
    try {
      // 队列在批次进行中仍可能增长，worker 每次循环重新领取一项。
      Future<void> worker() async {
        while (true) {
          if (!_current(generation) || _stopRequested) return;
          final item = _claimPending();
          if (item == null) return;
          _notify();
          try {
            final result = await _api.upload(
              item.file,
              item.options,
              knownJobIds: baseline,
              onProgress: (progress) {
                if (_current(generation)) {
                  item.progress = progress;
                  _notify();
                }
              },
            );
            if (!_current(generation)) return;
            item.status = CloudPrintQueueStatus.uploaded;
            item.progress = 1;
            item.verificationPending = !result.verified;
            item.duplicate = result.duplicate;
          } catch (error, stack) {
            if (!_current(generation)) return;
            AppLog.e(_tag, '批量队列中的文件上传失败', error: error, stackTrace: stack);
            if (error is CloudPrintUploadUncertainException) {
              item.status = CloudPrintQueueStatus.uncertain;
              item.failure = CloudPrintFailure.uncertain;
              // 会话可能已失效；停止派发新文件，已在传的各自等待结果。
              _stopRequested = true;
            } else {
              item.status = CloudPrintQueueStatus.failed;
              item.failure = error is UnauthenticatedException
                  ? CloudPrintFailure.authentication
                  : error is ServiceException && error.statusCode == 413
                  ? CloudPrintFailure.tooLarge
                  : CloudPrintFailure.request;
              if (error is UnauthenticatedException) _stopRequested = true;
            }
          }
          _notify();
        }
      }

      final workers = <Future<void>>[
        for (var i = 0; i < uploadConcurrency; i++) worker(),
      ];
      await Future.wait(workers);
    } finally {
      if (_current(generation)) {
        uploading = false;
        _notify();
        await refreshJobs();
      }
    }
  }

  Future<void> refreshJobs() {
    if (_jobsFuture case final existing?) return existing;
    final generation = _generation;
    loadingJobs = true;
    jobsFailed = false;
    _notify();
    Future<void> load() async {
      try {
        final result = await _api.fetchJobs();
        if (_current(generation)) jobs = result;
      } catch (error, stack) {
        if (_current(generation)) jobsFailed = true;
        AppLog.e(_tag, '打印任务列表加载失败', error: error, stackTrace: stack);
      } finally {
        if (_current(generation)) {
          loadingJobs = false;
          _jobsFuture = null;
          _notify();
        }
      }
    }

    return _jobsFuture = load();
  }

  Future<Uint8List> previewPage(CloudPrintJob job, int pageNo) =>
      _api.previewPage(job, pageNo);

  /// 批量删除待打印任务：逐项隔离失败，成功后回查一次列表。
  Future<({int deleted, int failed})> deleteJobs(
    Iterable<CloudPrintJob> targets,
  ) async {
    final generation = _generation;
    var deleted = 0, failed = 0;
    for (final job in targets) {
      if (!_current(generation)) break;
      try {
        await _api.deleteJob(job);
        if (!_current(generation)) break;
        jobs = jobs.where((item) => item.id != job.id).toList();
        _notify();
        deleted++;
      } catch (error, stack) {
        failed++;
        AppLog.e(_tag, '删除打印任务失败', error: error, stackTrace: stack);
      }
    }
    if (_current(generation) && deleted > 0) await refreshJobs();
    return (deleted: deleted, failed: failed);
  }

  Future<bool> deleteJob(CloudPrintJob job) async =>
      (await deleteJobs([job])).deleted == 1;

  /// 批量删除扫描记录。只删服务器记录，已下载到本地的扫描件保留。
  Future<({int deleted, int failed})> deleteScans(
    Iterable<CloudScanJob> targets,
  ) async {
    final generation = _generation;
    var deleted = 0, failed = 0;
    for (final scan in targets) {
      if (!_current(generation)) break;
      try {
        await _api.deleteScan(scan);
        if (!_current(generation)) break;
        scans = scans.where((item) => item.id != scan.id).toList();
        _scanFiles.remove(scan.id);
        _scanProgress.remove(scan.id);
        _scanFailures.remove(scan.id);
        _notify();
        deleted++;
      } catch (error, stack) {
        failed++;
        AppLog.e(_tag, '删除扫描记录失败', error: error, stackTrace: stack);
      }
    }
    if (_current(generation) && deleted > 0) await refreshScans();
    return (deleted: deleted, failed: failed);
  }

  Future<void> refreshScans() {
    if (_scansFuture case final existing?) return existing;
    final generation = _generation;
    loadingScans = true;
    scansFailed = false;
    _notify();
    Future<void> load() async {
      try {
        final result = await _api.fetchScans();
        if (_current(generation)) scans = result;
      } catch (error, stack) {
        if (_current(generation)) scansFailed = true;
        AppLog.e(_tag, '扫描文档列表加载失败', error: error, stackTrace: stack);
      } finally {
        if (_current(generation)) {
          loadingScans = false;
          _scansFuture = null;
          _notify();
        }
      }
    }

    return _scansFuture = load();
  }

  /// 批量下载逐项隔离失败；只使用受控目录和去除路径字符后的文件名。
  Future<void> downloadScans(
    Iterable<CloudScanJob> selected,
    Directory directory,
  ) async {
    if (downloading) return;
    final generation = _generation;
    final scope = sha256
        .convert(utf8.encode(_principal ?? 'local'))
        .toString()
        .substring(0, 16);
    downloading = true;
    _notify();
    try {
      for (final scan in selected) {
        if (!_current(generation)) break;
        if (scan.expired) continue;
        final cached = _scanFiles[scan.id];
        if (cached != null && await File(cached).exists()) continue;
        if (!_current(generation)) break;
        _scanFiles.remove(scan.id);
        _scanFailures.remove(scan.id);
        _scanProgress[scan.id] = 0;
        _notify();
        try {
          // 按账号分目录；登出后不向下一个账号展示上一个账号的下载结果。
          var safeName = scan.name
              .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
              .replaceFirst(RegExp(r'[ .]+$'), '');
          if (safeName.length > 120) {
            final extension = p.extension(safeName);
            safeName =
                '${safeName.substring(0, 100)}${extension.length <= 20 ? extension : ''}';
          }
          final destination = p.normalize(
            p.join(
              directory.path,
              scope,
              '${scan.id}_${safeName.isEmpty ? 'scan' : safeName}',
            ),
          );
          await _api.downloadScan(
            scan,
            destination,
            onProgress: (progress) {
              if (_current(generation)) {
                _scanProgress[scan.id] = progress;
                _notify();
              }
            },
          );
          if (_current(generation)) _scanFiles[scan.id] = destination;
        } catch (error, stack) {
          if (_current(generation)) _scanFailures.add(scan.id);
          AppLog.e(_tag, '扫描文档下载失败', error: error, stackTrace: stack);
        }
        if (_current(generation)) {
          _scanProgress.remove(scan.id);
          _notify();
        }
      }
    } finally {
      if (_current(generation)) {
        downloading = false;
        _notify();
      }
    }
  }

  void clear() {
    _generation++;
    _queue.clear();
    jobs = [];
    scans = [];
    _scanFiles.clear();
    _scanProgress.clear();
    _scanFailures.clear();
    _jobsFuture = null;
    _scansFuture = null;
    uploading = false;
    selecting = false;
    downloading = false;
    loadingJobs = false;
    loadingScans = false;
    jobsFailed = false;
    scansFailed = false;
    _stopRequested = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _scu?.removeListener(_onAuthChanged);
    super.dispose();
  }
}
