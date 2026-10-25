import 'dart:convert';
import 'dart:io';

import 'package:bugaoshan/utils/json_utils.dart';
import 'package:path/path.dart' as p;

enum CloudPrintColor { monochrome, color }

enum CloudPrintPaper { a4, a3, original }

enum CloudPrintDuplex { longEdge, shortEdge, simplex }

/// 默认 A4、黑白、长边双面、全部页、1 份。每个队列项保存自己的设置快照。
class CloudPrintOptions {
  const CloudPrintOptions({
    this.color = CloudPrintColor.monochrome,
    this.paper = CloudPrintPaper.a4,
    this.duplex = CloudPrintDuplex.longEdge,
    this.copies = 1,
    this.pages = '',
  });
  final CloudPrintColor color;
  final CloudPrintPaper paper;
  final CloudPrintDuplex duplex;
  final int copies;
  final String pages;

  Map<String, String> toFields() {
    if (copies < 1 || copies > 0xffffffff) {
      throw const FormatException('copies');
    }
    var first = 0, last = 0;
    if (pages.trim().isNotEmpty) {
      final match = RegExp(
        r'^(\d+)(?:\s*-\s*(\d+))?$',
      ).firstMatch(pages.trim());
      if (match == null) throw const FormatException('pages');
      first = int.tryParse(match[1]!) ?? 0;
      last = int.tryParse(match[2] ?? match[1]!) ?? 0;
      if (first < 1 || last < first || last > 0xffffffff) {
        throw const FormatException('pages');
      }
    }
    return {
      'dwColor': color == CloudPrintColor.color ? '2' : '1',
      'dwPaperId': switch (paper) {
        CloudPrintPaper.a4 => '9',
        CloudPrintPaper.a3 => '8',
        CloudPrintPaper.original => '-1',
      },
      'dwDuplex': switch (duplex) {
        CloudPrintDuplex.simplex => '1',
        CloudPrintDuplex.longEdge => '2',
        CloudPrintDuplex.shortEdge => '3',
      },
      'dwCopies': '$copies',
      'dwFrom': '$first',
      'dwTo': '$last',
    };
  }
}

const cloudPrintExtensions = [
  'pdf',
  'jpg',
  'jpeg',
  'heic',
  'png',
  'txt',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'wps',
  'wpt',
  'dot',
  'rtf',
  'dotx',
  'docm',
  'dotm',
  'xml',
  'mht',
  'mhtml',
  'html',
  'htm',
  'xps',
  'odt',
  'xlsm',
  'xlsb',
  'csv',
  'xltx',
  'xltm',
  'xlt',
  'prn',
  'dif',
  'slk',
  'xla',
  'xlam',
  'ods',
  'dps',
  'dpt',
  'pot',
  'pps',
  'pptm',
  'potm',
  'ppsm',
];

class CloudPrintFile {
  const CloudPrintFile({
    required this.path,
    required this.name,
    required this.size,
  });
  final String path, name;
  final int size;
  static Future<CloudPrintFile> fromPath(String path) async {
    final name = p.basename(path);
    final stat = await File(path).stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size == 0 ||
        name.contains(RegExp(r'[\r\n]')) ||
        !cloudPrintExtensions.contains(
          p.extension(name).replaceFirst('.', '').toLowerCase(),
        )) {
      throw const FormatException('file');
    }
    return CloudPrintFile(
      path: p.normalize(p.absolute(path)),
      name: name,
      size: stat.size,
    );
  }
}

/// 只提取打印所需字段，不持有账号、姓名、卡号和服务器文件路径。
class CloudPrintJob {
  CloudPrintJob.fromJson(Map<String, dynamic> json)
    : id = safeInt(json['dwJobId']),
      name = safeString(json['szJobName']),
      pages = safeInt(json['dwPages']),
      copies = safeInt(json['dwCopies']),
      status = safeInt(json['dwStatus']),
      attributes = safeString(json['szAttribe']);
  final int id, pages, copies, status;
  final String name, attributes;
}

class CloudScanJob {
  CloudScanJob.fromJson(Map<String, dynamic> json)
    : id = safeInt(json['dwJobId']),
      name = safeString(json['szDisplayName']),
      size = safeInt(json['dwFileSize']),
      status = safeInt(json['dwStatus']),
      date = safeInt(json['dwSubmitDate']),
      time = safeInt(json['dwSubmitTime']);
  final int id, size, status, date, time;
  final String name;
  bool get expired => (status & 256) != 0;
  String get displayDate {
    final day = date.toString();
    final formatted = day.length == 8
        ? '${day.substring(0, 4)}-${day.substring(4, 6)}-${day.substring(6)}'
        : day;
    final clock = time.toString().padLeft(6, '0');
    return '$formatted ${clock.substring(0, 2)}:${clock.substring(2, 4)}:${clock.substring(4)}';
  }
}

List<Map<String, dynamic>> cloudPrintResultList(Object? value) {
  if (value == null) return [];
  if (value is! List) throw const FormatException('result');
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

// 参数解析使用统一宽松 helper；上传结果不依赖回跳 HTML 内容。
Map<String, dynamic> decodeCloudPrintJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) throw const FormatException('envelope');
  return Map<String, dynamic>.from(decoded);
}
