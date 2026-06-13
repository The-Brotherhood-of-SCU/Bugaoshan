import 'dart:io';

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
  return filePath;
}

/// Returns the path of an already-downloaded file, or null.
Future<String?> checkDownloadedFile(String dirName, String fileName) async {
  final base = await getNoticeBaseDir();
  final saveDir = Directory('${base.path}/Bugaoshan/$dirName');
  if (!await saveDir.exists()) return null;

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
