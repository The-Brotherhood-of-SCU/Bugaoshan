import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:bugaoshan/services/download_manager.dart';

/// Default subdirectory name under `Bugaoshan/` for jwc notice downloads.
const kNoticeAttachmentDir = 'notice_attachments';

/// Subdirectory name under `Bugaoshan/` for party notice downloads.
const kPartyAttachmentDir = 'party_attachments';

/// Subdirectory name under `Bugaoshan/` for tuanwei notice downloads.
const kTuanweiAttachmentDir = 'tuanwei_attachments';

/// Subdirectory name under `Bugaoshan/` for saved auth log exports.
const kAuthLogDir = 'auth_logs';

/// Persistent URL-to-file index for notice attachments.
///
/// One metadata file is stored per URL so concurrent downloads do not overwrite
/// a shared JSON map. Legacy files are adopted only when no other URL already
/// owns that path.
class DownloadPathIndex {
  DownloadPathIndex(this.downloadDir);

  static const _indexDirName = '.download_index';
  static final Map<String, Future<void>> _directoryQueues = {};

  final Directory downloadDir;

  Directory get _indexDir => Directory(p.join(downloadDir.path, _indexDirName));

  String get _queueKey => p.normalize(downloadDir.absolute.path);

  File _entryFor(String url) {
    final key = sha256.convert(utf8.encode(url)).toString();
    return File(p.join(_indexDir.path, '$key.json'));
  }

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    final previous = _directoryQueues[_queueKey] ?? Future<void>.value();
    final gate = Completer<void>();
    final current = gate.future;
    _directoryQueues[_queueKey] = current;
    try {
      try {
        await previous;
      } catch (_) {
        // A previous operation must not poison the per-directory queue.
      }
      return await action();
    } finally {
      gate.complete();
      if (identical(_directoryQueues[_queueKey], current)) {
        _directoryQueues.remove(_queueKey);
      }
    }
  }

  Future<void> record(String url, String path) {
    return _synchronized(() => _recordUnlocked(url, path));
  }

  Future<void> _recordUnlocked(String url, String path) async {
    final fileName = p.basename(path);
    final expectedPath = p.normalize(p.join(downloadDir.path, fileName));
    if (p.normalize(path) != expectedPath) {
      throw ArgumentError.value(path, 'path', 'must be inside downloadDir');
    }

    await _indexDir.create(recursive: true);
    final entry = _entryFor(url);
    final temporary = File('${entry.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'fileName': fileName}),
      flush: true,
    );
    if (await entry.exists()) await entry.delete();
    await temporary.rename(entry.path);
  }

  Future<String?> resolve(String url, {required String legacyFileName}) {
    return _synchronized(() async {
      final mapped = await _mappedPath(url);
      if (mapped != null) return mapped;

      final claimed = await _claimedFileNames();
      for (final candidate in _legacyCandidates(legacyFileName)) {
        final fileName = p.basename(candidate);
        if (claimed.contains(fileName)) continue;
        if (!await File(candidate).exists()) continue;
        await _recordUnlocked(url, candidate);
        return candidate;
      }
      return null;
    });
  }

  Future<void> removePath(String path) {
    return _synchronized(() async {
      if (!await _indexDir.exists()) return;
      final targetName = p.basename(path);
      await for (final entry in _indexDir.list().where(
        (entry) => entry is File && entry.path.endsWith('.json'),
      )) {
        final file = entry as File;
        final fileName = await _readFileName(file);
        if (fileName == targetName && await file.exists()) {
          await file.delete();
        }
      }
    });
  }

  Future<String?> _mappedPath(String url) async {
    final entry = _entryFor(url);
    if (!await entry.exists()) return null;
    final fileName = await _readFileName(entry);
    if (fileName == null) return null;
    // 与 downloadFile / checkDownloadedFile 一致，用 '/' 拼接返回路径，
    // 保证同一路径在不同 API 间字符串一致（Windows 上 dart:io 接受混合分隔符）。
    final path = '${downloadDir.path}/$fileName';
    if (await File(path).exists()) return path;
    if (await entry.exists()) await entry.delete();
    return null;
  }

  Future<Set<String>> _claimedFileNames() async {
    if (!await _indexDir.exists()) return {};
    final claimed = <String>{};
    await for (final entry in _indexDir.list().where(
      (entry) => entry is File && entry.path.endsWith('.json'),
    )) {
      final file = entry as File;
      final fileName = await _readFileName(file);
      if (fileName == null) continue;
      if (await File(p.join(downloadDir.path, fileName)).exists()) {
        claimed.add(fileName);
      } else if (await file.exists()) {
        await file.delete();
      }
    }
    return claimed;
  }

  Future<String?> _readFileName(File entry) async {
    try {
      final data = jsonDecode(await entry.readAsString());
      if (data is! Map<String, dynamic>) throw const FormatException();
      final rawName = data['fileName'];
      if (rawName is! String || rawName != p.basename(rawName)) {
        throw const FormatException();
      }
      return rawName;
    } catch (_) {
      if (await entry.exists()) await entry.delete();
      return null;
    }
  }

  Iterable<String> _legacyCandidates(String rawName) sync* {
    final safeName = sanitizeDownloadFileName(rawName);
    yield '${downloadDir.path}/$safeName';
    final baseName = p.basenameWithoutExtension(safeName);
    final extension = p.extension(safeName);
    for (var i = 1; i <= 99; i++) {
      yield '${downloadDir.path}/$baseName ($i)$extension';
    }
  }
}

// ── File utilities ─────────────────────────────────────────────────────────────────

Future<Directory> getNoticeBaseDir() async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final dir = await getDownloadsDirectory();
    if (dir != null) return dir;
  }
  if (Platform.isAndroid) {
    final dir = await getExternalStorageDirectory();
    if (dir != null) return dir;
  }
  return getApplicationDocumentsDirectory();
}

/// Auth log 落盘策略：
/// - Android：app 外部 cache (`Android/data/<package>/cache/`)，
///   文件管理器可见，OS 会在低存储时清理。
/// - 其他平台：OS temp 目录，由 OS 管理生命周期。
///
/// 不走 `getDownloadsDirectory()` / `getExternalStorageDirectory()`，
/// 因为 auth log 是调试用的瞬态产物，不是用户文件。
Future<Directory> getAuthLogBaseDir() async {
  if (Platform.isAndroid) {
    final dirs = await getExternalCacheDirectories();
    if (dirs != null && dirs.isNotEmpty) return dirs.first;
  }
  return getTemporaryDirectory();
}

/// Resolves a subdirectory under `Bugaoshan/{dirName}/` inside the app's
/// base download directory, creating it if needed.
Future<Directory> _getDir(String dirName) async {
  final base = await getNoticeBaseDir();
  final saveDir = Directory('${base.path}/Bugaoshan/$dirName');
  // create(recursive: true) is a no-op if the directory already exists,
  // so we can skip the explicit exists check entirely.
  await saveDir.create(recursive: true);
  return saveDir;
}

String formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String sanitizeDownloadFileName(String rawName) {
  final normalized = rawName.replaceAll('\\', '/');
  var fileName = p.posix.basename(normalized).trim();
  if (fileName.isEmpty || fileName == '.' || fileName == '..') {
    fileName = 'download';
  }
  fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  return fileName.isEmpty ? 'download' : fileName;
}

/// Downloads a file from [url] into `Bugaoshan/{dirName}/`.
/// Returns the final local path.
Future<String> downloadFile(
  String url,
  String dirName,
  String fileName, {
  Map<String, String>? headers,
  CancelToken? cancelToken,
}) async {
  if (cancelToken?.isCancelled ?? false) throw DownloadCancelledException();

  final mergedHeaders = <String, String>{
    'Referer': 'https://xgb.scu.edu.cn',
    ...?headers,
  };

  final response = await http.get(Uri.parse(url), headers: mergedHeaders);
  if (response.statusCode != 200) {
    throw Exception('Download failed: HTTP ${response.statusCode}');
  }

  if (cancelToken?.isCancelled ?? false) throw DownloadCancelledException();

  final bytes = response.bodyBytes;

  // Prefer filename from Content-Disposition header.
  var actualFileName = sanitizeDownloadFileName(fileName);
  final cd = response.headers['content-disposition'];
  if (cd != null) {
    // RFC 5987: filename*=UTF-8''percent-encoded-value
    final rfc5987 = RegExp(
      r"filename\*\s*=\s*UTF-8'[^']*'([^;]+)",
      caseSensitive: false,
    ).firstMatch(cd);
    if (rfc5987 != null) {
      actualFileName = sanitizeDownloadFileName(
        Uri.decodeComponent(rfc5987.group(1)!),
      );
    } else {
      final fnMatch = RegExp(
        r'''filename\s*=\s*["']?([^"';]+)["']?''',
      ).firstMatch(cd);
      if (fnMatch != null) {
        actualFileName = sanitizeDownloadFileName(fnMatch.group(1)!);
      }
    }
  }

  final saveDir = await _getDir(dirName);

  // Deduplicate file names.
  var filePath = '${saveDir.path}/$actualFileName';
  var file = File(filePath);
  if (await file.exists()) {
    final baseName = p.basenameWithoutExtension(actualFileName);
    final ext = p.extension(actualFileName);
    var counter = 1;
    while (await file.exists()) {
      filePath = '${saveDir.path}/$baseName ($counter)$ext';
      file = File(filePath);
      counter++;
    }
  }

  await file.writeAsBytes(bytes);
  await DownloadPathIndex(saveDir).record(url, filePath);
  return filePath;
}

/// Returns the path of an already-downloaded file, or null.
Future<String?> checkDownloadedFile(
  String dirName,
  String fileName, {
  String? url,
}) async {
  final base = await getNoticeBaseDir();
  final saveDir = Directory('${base.path}/Bugaoshan/$dirName');
  if (!await saveDir.exists()) return null;

  if (url != null) {
    return DownloadPathIndex(saveDir).resolve(url, legacyFileName: fileName);
  }

  final safeFileName = sanitizeDownloadFileName(fileName);
  final exactPath = '${saveDir.path}/$safeFileName';
  if (await File(exactPath).exists()) return exactPath;

  final baseName = p.basenameWithoutExtension(safeFileName);
  final ext = p.extension(safeFileName);
  for (var i = 1; i <= 99; i++) {
    final variantPath = '${saveDir.path}/$baseName ($i)$ext';
    if (await File(variantPath).exists()) return variantPath;
  }
  return null;
}

Future<void> removeDownloadPathMapping(String dirName, String path) async {
  final base = await getNoticeBaseDir();
  final saveDir = Directory('${base.path}/Bugaoshan/$dirName');
  if (!await saveDir.exists()) return;
  await DownloadPathIndex(saveDir).removePath(path);
}
