import 'package:flutter/foundation.dart';

import 'package:bugaoshan/pages/campus/downloads/file_utils.dart';

/// Mutable cancellation token for in-progress downloads.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class DownloadCancelledException implements Exception {}

enum DownloadStatus { pending, downloading, done, error }

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.dirName,
    this.headers,
  });

  final String id;
  final String url;
  final String fileName;
  final String dirName;
  final Map<String, String>? headers;
  DownloadStatus status = DownloadStatus.pending;
  String? downloadedPath;
  String? errorMessage;
  CancelToken? cancelToken;
  final DateTime startedAt = DateTime.now();
  DateTime? completedAt;
}

/// Generic download manager that survives page navigation.
///
/// Register as a singleton in GetIt and observe with [ListenableBuilder].
class DownloadManager extends ChangeNotifier {
  final Map<String, DownloadTask> _tasks = {};

  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);

  DownloadTask? taskFor(String dirName, String fileName) {
    return _tasks['$dirName/$fileName'];
  }

  DownloadTask enqueue(
    String url,
    String dirName,
    String fileName, {
    Map<String, String>? headers,
  }) {
    final id = '$dirName/$fileName';
    final existing = _tasks[id];
    if (existing != null) return existing;

    final task = DownloadTask(
      id: id,
      url: url,
      fileName: fileName,
      dirName: dirName,
      headers: headers,
    );
    _tasks[id] = task;
    notifyListeners();
    return task;
  }

  void updateTask(
    DownloadTask task, {
    DownloadStatus? status,
    String? downloadedPath,
    String? errorMessage,
    CancelToken? cancelToken,
  }) {
    if (status != null) task.status = status;
    if (downloadedPath != null) task.downloadedPath = downloadedPath;
    if (errorMessage != null) task.errorMessage = errorMessage;
    if (cancelToken != null) task.cancelToken = cancelToken;
    if (status == DownloadStatus.done || status == DownloadStatus.error) {
      task.completedAt = DateTime.now();
    }
    notifyListeners();
  }

  /// Download a file, tracking state from enqueue → downloading → done/error.
  /// Returns the saved path. The task is always created or updated on the
  /// manager so [ListenableBuilder] consumers react to every state change.
  Future<String> download(
    String url,
    String dirName,
    String fileName, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    final task = enqueue(url, dirName, fileName, headers: headers);
    updateTask(task, status: DownloadStatus.downloading);
    try {
      final path = await downloadFile(
        url,
        dirName,
        fileName,
        headers: headers,
        cancelToken: cancelToken,
      );
      updateTask(task, status: DownloadStatus.done, downloadedPath: path);
      return path;
    } catch (e) {
      updateTask(task, status: DownloadStatus.error, errorMessage: e.toString());
      rethrow;
    }
  }

  void cancel(String dirName, String fileName) {
    final task = taskFor(dirName, fileName);
    if (task != null && task.cancelToken != null) {
      task.cancelToken!.cancel();
    }
  }

  void remove(String dirName, String fileName) {
    _tasks.remove('$dirName/$fileName');
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((_, t) => t.status == DownloadStatus.done || t.status == DownloadStatus.error);
    notifyListeners();
  }
}
