import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日志级别。
enum AuthLogLevel { debug, info, warn, error }

/// 单条日志记录。
class AuthLogEntry {
  final DateTime timestamp;
  final AuthLogLevel level;
  final String tag;
  final String message;

  const AuthLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  /// 输出为单行文本，供 UI 列表 / 文件导出使用。
  ///
  /// 格式：`HH:mm:ss.SSS LEVEL [tag] message`
  String format({bool includeDate = false}) {
    final ts = includeDate
        ? _formatDateTime(timestamp)
        : _formatTime(timestamp);
    return '$ts ${level.name.toUpperCase().padRight(5)} [$tag] $message';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _three(int n) => n.toString().padLeft(3, '0');

  static String _formatTime(DateTime t) {
    final h = _two(t.hour);
    final m = _two(t.minute);
    final s = _two(t.second);
    final ms = _three(t.millisecond);
    return '$h:$m:$s.$ms';
  }

  static String _formatDateTime(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final mo = _two(t.month);
    final d = _two(t.day);
    return '$y-$mo-$d ${_formatTime(t)}';
  }
}

/// 隐私脱敏：把 access_token / password / Bearer 等敏感字段遮蔽，
/// 防止日志被分享到 issue 或支持工单时泄露凭据。
class AuthLogRedactor {
  static final RegExp _accessTokenJson = RegExp(
    r'("access_token"\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _passwordJson = RegExp(
    r'("password"\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _bearerHeader = RegExp(
    r'(Bearer\s+)[A-Za-z0-9._\-]+',
    caseSensitive: false,
  );
  static final RegExp _oauthCode = RegExp(
    r'([?&](?:code|access_token)=)([^&\s"]+)',
    caseSensitive: false,
  );
  static final RegExp _principalLabel = RegExp(
    r'\b(user(?:name|id)?|student(?:id|number)?|number)\s*=\s*([^\s,;]+)',
    caseSensitive: false,
  );
  static final RegExp _principalJson = RegExp(
    r'("(?:username|userId|studentId|studentNumber|number)"\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );

  /// 对输入文本做脱敏；返回新字符串。
  static String apply(String text) {
    var result = text;
    result = result.replaceAllMapped(
      _accessTokenJson,
      (m) => '${m[1]}"<redacted>"',
    );
    result = result.replaceAllMapped(
      _passwordJson,
      (m) => '${m[1]}"<redacted>"',
    );
    result = result.replaceAllMapped(_bearerHeader, (m) => '${m[1]}<redacted>');
    result = result.replaceAllMapped(_oauthCode, (m) {
      final prefix = m[1] ?? '';
      final value = m[2] ?? '';
      if (value.length <= 4) return '$prefix<redacted>';
      return '$prefix${value.substring(0, 4)}…';
    });
    result = result.replaceAllMapped(
      _principalLabel,
      (m) => '${m[1]}=<redacted>',
    );
    result = result.replaceAllMapped(
      _principalJson,
      (m) => '${m[1]}"<redacted>"',
    );
    return result;
  }
}

/// 全局认证日志器（单例）。
///
/// 设计要点：
/// - 内存中维护定长环形缓冲（默认 1000 条），UI 可通过 [entries] / [listenable] 订阅。
/// - 每条日志在写入缓冲前先经 [AuthLogRedactor] 脱敏，确保即便分享也不会泄露凭据。
/// - 可选的「写入文件」模式由调用方按需开启（默认关闭），避免给生产用户带来磁盘 I/O 开销。
/// - 模块通过 `getIt<AuthLogger>()` 拿到实例，无需依赖注入额外参数。
class AuthLogger extends ChangeNotifier {
  static const int _defaultCapacity = 1000;

  final int capacity;
  final List<AuthLogEntry> _buffer = [];
  bool _fileSinkEnabled = false;
  IOSink? _fileSink;
  String? _fileSinkPath;

  AuthLogger({this.capacity = _defaultCapacity});

  /// 当前日志列表（只读快照，顺序：旧 → 新）。
  List<AuthLogEntry> get entries => List.unmodifiable(_buffer);

  /// 当前是否启用了文件写入。
  bool get fileSinkEnabled => _fileSinkEnabled;

  /// 文件写入路径（仅在 [fileSinkEnabled] 为 true 时有值）。
  String? get fileSinkPath => _fileSinkPath;

  /// 写入一条日志。level 默认为 [AuthLogLevel.info]。
  void log(
    AuthLogLevel level,
    String tag,
    String message, {
    DateTime? timestamp,
  }) {
    final entry = AuthLogEntry(
      timestamp: timestamp ?? DateTime.now(),
      level: level,
      tag: tag,
      message: AuthLogRedactor.apply(message),
    );
    _buffer.add(entry);
    if (_buffer.length > capacity) {
      _buffer.removeRange(0, _buffer.length - capacity);
    }

    // 仅 debug 模式同时打到控制台，避免生产包日志噪声。
    // 使用 debugPrint 而非 print：避免 stdout 与其他异步日志乱序交错，
    // 并获得 Flutter 自带的同帧节流防刷屏。
    if (kDebugMode) {
      debugPrint(entry.format());
    }

    if (_fileSinkEnabled) {
      _fileSink?.writeln(entry.format(includeDate: true));
    }

    notifyListeners();
  }

  /// 便捷方法：debug / info / warn / error。
  void d(String tag, String message) => log(AuthLogLevel.debug, tag, message);
  void i(String tag, String message) => log(AuthLogLevel.info, tag, message);
  void w(String tag, String message) => log(AuthLogLevel.warn, tag, message);
  void e(String tag, String message) => log(AuthLogLevel.error, tag, message);

  /// 清空当前缓冲（不影响文件落盘的历史记录）。
  void clear() {
    if (_buffer.isEmpty) return;
    _buffer.clear();
    notifyListeners();
  }

  /// 导出为纯文本（每行一条），供分享 / 保存到文件。
  String exportToText({bool includeDate = true}) {
    final buf = StringBuffer();
    if (includeDate) {
      buf.writeln('# Bugaoshan auth log');
      buf.writeln('# exported: ${DateTime.now().toIso8601String()}');
      buf.writeln('# entries: ${_buffer.length}');
      buf.writeln('');
    }
    for (final entry in _buffer) {
      buf.writeln(entry.format(includeDate: includeDate));
    }
    return buf.toString();
  }

  /// 启用文件落盘（写入到 app 文档目录下的 auth.log）。
  ///
  /// 重复调用会先关闭旧 sink。每次写入追加一行（含时间戳），不做自动 rotation。
  /// 主要用于在测试/调试场景下保留更长时间窗口的日志供分享。
  Future<void> enableFileSink({String? overridePath}) async {
    if (_fileSinkEnabled) return;
    try {
      final dir = overridePath != null
          ? Directory(overridePath)
          : await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(p.join(dir.path, 'auth.log'));
      _fileSink = file.openWrite(mode: FileMode.append);
      _fileSinkPath = file.path;
      _fileSinkEnabled = true;
      notifyListeners();
    } catch (err) {
      // 落盘失败不应阻塞业务，仅 debug 打印提醒。
      if (kDebugMode) {
        // ignore: avoid_print
        print('AuthLogger: enableFileSink failed: $err');
      }
    }
  }

  /// 把当前日志导出到 [targetDir] 下的 `bugaoshan-auth-{timestamp}.log`，
  /// 返回最终写入的文件路径。失败抛异常。
  ///
  /// 供 AuthLogViewer "Save" 按钮使用 — 调用方负责选定 [targetDir]
  /// （推荐 `getAuthLogBaseDir()` 路径下的 `Bugaoshan/auth_logs/`）。
  Future<String> exportToFile(Directory targetDir) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final ts = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${ts.year}${two(ts.month)}${two(ts.day)}-${two(ts.hour)}${two(ts.minute)}${two(ts.second)}';
    final file = File(p.join(targetDir.path, 'bugaoshan-auth-$stamp.log'));
    await file.writeAsString(exportToText());
    return file.path;
  }

  /// 关闭文件落盘。
  Future<void> disableFileSink() async {
    if (!_fileSinkEnabled) return;
    try {
      await _fileSink?.flush();
      await _fileSink?.close();
    } catch (_) {
      // 关闭失败忽略。
    }
    _fileSink = null;
    _fileSinkPath = null;
    _fileSinkEnabled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _fileSink?.flush().catchError((_) {});
    _fileSink?.close().catchError((_) {});
    _fileSink = null;
    super.dispose();
  }
}
