import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:bugaoshan/services/download_manager.dart';

/// Default subdirectory name under `Bugaoshan/` for jwc notice downloads.
const kNoticeAttachmentDir = 'notice_attachments';

/// Subdirectory name under `Bugaoshan/` for party notice downloads.
const kPartyAttachmentDir = 'party_notices';

/// Subdirectory name under `Bugaoshan/` for tuanwei notice downloads.
const kTuanweiAttachmentDir = 'tuanwei_notices';

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

/// Resolves a subdirectory under `Bugaoshan/{dirName}/` inside the app's
/// base download directory, creating it if needed.
Future<Directory> _getDir(String dirName) async {
  final base = await getNoticeBaseDir();
  final saveDir = Directory('${base.path}/Bugaoshan/$dirName');
  if (!saveDir.existsSync()) {
    saveDir.createSync(recursive: true);
  }
  return saveDir;
}

String formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
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
    if (headers != null) ...headers,
  };

  final response = await http.get(Uri.parse(url), headers: mergedHeaders);
  if (response.statusCode != 200) {
    throw Exception('Download failed: HTTP ${response.statusCode}');
  }

  if (cancelToken?.isCancelled ?? false) throw DownloadCancelledException();

  final bytes = response.bodyBytes;

  // Prefer filename from Content-Disposition header.
  var actualFileName = fileName;
  final cd = response.headers['content-disposition'];
  if (cd != null) {
    // RFC 5987: filename*=UTF-8''percent-encoded-value
    final rfc5987 = RegExp(
      r"filename\*\s*=\s*UTF-8'[^']*'([^;]+)",
      caseSensitive: false,
    ).firstMatch(cd);
    if (rfc5987 != null) {
      actualFileName = Uri.decodeComponent(rfc5987.group(1)!);
    } else {
      final fnMatch = RegExp(
        r'''filename\s*=\s*["']?([^"';]+)["']?''',
      ).firstMatch(cd);
      if (fnMatch != null) {
        actualFileName = fnMatch.group(1)!;
      }
    }
  }

  final saveDir = await _getDir(dirName);

  // Deduplicate file names.
  var filePath = '${saveDir.path}/$actualFileName';
  var file = File(filePath);
  if (file.existsSync()) {
    final baseName = p.basenameWithoutExtension(actualFileName);
    final ext = p.extension(actualFileName);
    var counter = 1;
    while (file.existsSync()) {
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
  if (!saveDir.existsSync()) return null;

  final exactPath = '${saveDir.path}/$fileName';
  if (File(exactPath).existsSync()) return exactPath;

  final baseName = p.basenameWithoutExtension(fileName);
  final ext = p.extension(fileName);
  for (var i = 1; i <= 99; i++) {
    final variantPath = '${saveDir.path}/$baseName ($i)$ext';
    if (File(variantPath).existsSync()) return variantPath;
  }
  return null;
}
