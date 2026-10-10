import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日志级别。
enum LogLevel { debug, info, warn, error }

/// 日志目录名，位于 [getLogBaseDir]`/Bugaoshan/` 下。
///
/// 与通知附件目录同级，便于用户在 Android 文件管理器里定位。
const String kLogDir = 'logs';

/// 日志落盘基目录策略：
/// - Android：app 外部 cache (`Android/data/<package>/cache/`)，
///   文件管理器可见，OS 会在低存储时清理。
/// - 其他平台：OS temp 目录，由 OS 管理生命周期。
///
/// 不走 `getDownloadsDirectory()` / `getExternalStorageDirectory()`，
/// 因为日志是调试用的瞬态产物，不是用户文件。
Future<Directory> getLogBaseDir() async {
  if (Platform.isAndroid) {
    final dirs = await getExternalCacheDirectories();
    if (dirs != null && dirs.isNotEmpty) return dirs.first;
  }
  return getTemporaryDirectory();
}

/// 解析日志目录 `<base>/Bugaoshan/[kLogDir]/`，不存在则创建。
///
/// 自动落盘与 Dev 页手动导出共用此路径，两者产物在同一目录，
/// 用户「打开文件夹」时能一次看全。
Future<Directory> resolveLogDir({String? overrideBaseDir}) async {
  final base = overrideBaseDir != null
      ? Directory(overrideBaseDir)
      : await getLogBaseDir();
  final dir = Directory(p.join(base.path, 'Bugaoshan', kLogDir));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// 单条日志记录。
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  const LogEntry({
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
class LogRedactor {
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
    r'\b((?:user|student)(?:name|id|number)?|number)\s*=\s*([^\s,;]+)',
    caseSensitive: false,
  );
  static final RegExp _principalJson = RegExp(
    r'("(?:username|userId|studentId|studentNumber|number)"\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );

  /// snake_case 变体（`student_id=` / `user_name=` / `student_number=`）。
  ///
  /// Dart 侧惯例是 camelCase，但 JSON 响应、日志约定与部分后端接口用 snake_case，
  /// 故单独覆盖。
  static final RegExp _principalSnakeLabel = RegExp(
    r'\b((?:user|student)_(?:name|id|number)|number)\s*=\s*([^\s,;]+)',
    caseSensitive: false,
  );

  /// 中文「学号」标签：项目代码与 l10n 文案中大量使用中文表述，
  /// 这类裸值不带任何英文标签，只能靠中文字面识别。
  ///
  /// 值部要求含数字或英文字母：纯中文叙述（如「学号相关的缓存 key」）不是
  /// 一个被记录的身份值，若照遮会把正常日志读成「学号[redacted]」而误导排障。
  static final RegExp _principalChinese = RegExp(
    r'(学号)\s*[:：=]?\s*([A-Za-z0-9][^\s,;，；、]*)',
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
      _principalSnakeLabel,
      (m) => '${m[1]}=<redacted>',
    );
    result = result.replaceAllMapped(
      _principalJson,
      (m) => '${m[1]}"<redacted>"',
    );
    // 中文「学号」保留原文标签，仅遮蔽其后的值。
    result = result.replaceAllMapped(
      _principalChinese,
      (m) => '${m[1]}<redacted>',
    );
    return result;
  }
}

/// 全局应用日志器（单例）。
///
/// 设计要点：
/// - 内存中维护定长环形缓冲（默认 1000 条），UI 可通过 [entries] / [listenable] 订阅。
/// - 每条日志在写入缓冲前先经 [LogRedactor] 脱敏，确保即便分享也不会泄露凭据。
/// - [LogLevel.warn] / [LogLevel.error] 落盘到按大小轮转的文件，默认开启，
///   可由用户通过设置关闭（见 `AppConfigProvider.logPersistenceEnabled`）。
///   落盘是崩溃现场唯一的后手——进程退出后内存缓冲必然丢失。
/// - 模块通过 `getIt<AppLogger>()` 拿到实例，无需依赖注入额外参数。
class AppLogger extends ChangeNotifier {
  static const int _defaultCapacity = 1000;

  /// 落盘的最低级别：[LogLevel.warn] 及以上。
  ///
  /// 不落 debug/info：它们记的是生命周期里程碑（"download started" 等），
  /// 对用户报障几乎无用，却会把文件迅速撑满。
  static const LogLevel _minPersistedLevel = LogLevel.warn;

  /// 单个日志文件的大小上限，超过则轮转。
  static const int _defaultMaxBytesPerFile = 2 * 1024 * 1024;

  /// 保留的历史文件份数（不含当前写入的 `app.log`），故总量上限约
  /// `(_maxFileCount + 1) * _maxBytesPerFile`。
  static const int _defaultMaxFileCount = 2;

  static const String _logFileBaseName = 'app';
  static const String _logFileExtension = '.log';

  final int capacity;

  /// 单个文件大小上限，超过则轮转。作为实例字段而非编译期常量，
  /// 便于测试用小阈值验证轮转行为而不必写 2 MB。
  final int maxBytesPerFile;

  /// 保留的历史份数（不含当前 `app.log`）。
  final int maxFileCount;

  final List<LogEntry> _buffer = [];
  bool _fileSinkEnabled = false;
  IOSink? _fileSink;
  String? _fileSinkPath;

  /// 自上次 [_rotateIfNeeded] 起已写入的字节数。避免每行都 `stat()` 系统调用。
  int _bytesWritten = 0;

  AppLogger({
    this.capacity = _defaultCapacity,
    this.maxBytesPerFile = _defaultMaxBytesPerFile,
    this.maxFileCount = _defaultMaxFileCount,
  });

  /// 当前日志列表（只读快照，顺序：旧 → 新）。
  List<LogEntry> get entries => List.unmodifiable(_buffer);

  /// 当前是否启用了文件写入。
  bool get fileSinkEnabled => _fileSinkEnabled;

  /// 文件写入路径（仅在 [fileSinkEnabled] 为 true 时有值）。
  String? get fileSinkPath => _fileSinkPath;

  /// 写入一条日志。level 默认为 [LogLevel.info]。
  void log(LogLevel level, String tag, String message, {DateTime? timestamp}) {
    final entry = LogEntry(
      timestamp: timestamp ?? DateTime.now(),
      level: level,
      tag: tag,
      message: LogRedactor.apply(message),
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

    if (_fileSinkEnabled && level.index >= _minPersistedLevel.index) {
      _appendToFile(entry.format(includeDate: true));
    }

    notifyListeners();
  }

  /// 便捷方法：debug / info / warn / error。
  void d(String tag, String message) => log(LogLevel.debug, tag, message);
  void i(String tag, String message) => log(LogLevel.info, tag, message);
  void w(String tag, String message) => log(LogLevel.warn, tag, message);
  void e(String tag, String message) => log(LogLevel.error, tag, message);

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
      buf.writeln('# Bugaoshan app log');
      buf.writeln('# exported: ${DateTime.now().toIso8601String()}');
      buf.writeln('# entries: ${_buffer.length}');
      buf.writeln('');
    }
    for (final entry in _buffer) {
      buf.writeln(entry.format(includeDate: includeDate));
    }
    return buf.toString();
  }

  /// 启用文件落盘。默认由应用启动时调用（仅 warn/error 实际写入）。
  ///
  /// [overridePath] 为空时使用 [resolveLogDir] 的默认路径 —— 与 Dev 页
  /// 导出路径一致，因此 Android 上用户可直接用文件管理器查看排障日志，
  /// 且 OS 可在低存储时自动清理该目录。
  ///
  /// 重复调用会先关闭旧 sink。落盘失败不阻塞业务。
  Future<void> enableFileSink({String? overridePath}) async {
    if (_fileSinkEnabled) return;
    try {
      final dir = overridePath != null
          ? Directory(overridePath)
          : await resolveLogDir();
      await _openCurrentLogFile(dir);
      _fileSinkEnabled = true;
      notifyListeners();
    } catch (err) {
      // 落盘失败不应阻塞业务，仅 debug 打印提醒。
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppLogger: enableFileSink failed: $err');
      }
    }
  }

  /// 打开（或重建）当前写入文件，并把计数归零。
  Future<void> _openCurrentLogFile(Directory dir) async {
    final file = File(p.join(dir.path, '$_logFileBaseName$_logFileExtension'));
    // 追加模式：不截断既有内容，冷启动后新日志接在旧文件后面。
    _fileSink = file.openWrite(mode: FileMode.append);
    _fileSinkPath = file.path;
    _bytesWritten = await file.exists() ? await file.length() : 0;
  }

  /// 追加一行到当前文件，必要时先轮转。
  ///
  /// 只在超过 [maxBytesPerFile] 后轮转，且检查以「累计字节数」为准，
  /// 避免每行都做一次 `stat()` 系统调用。
  void _appendToFile(String line) {
    final sink = _fileSink;
    if (sink == null) return;

    // writeln 会补 '\n'，计入时保持一致。
    final payload = '$line\n';
    _bytesWritten += payload.length;
    if (_bytesWritten >= maxBytesPerFile) {
      // 轮转涉及文件 IO，不能在 log() 的同步路径里等，故异步执行。
      // sink 已提前换走，后续日志直接进新文件，不会因等待而丢失。
      unawaited(_rotate());
      return;
    }
    sink.writeln(line);
  }

  /// 多文件轮转：`app.2.log` 删除、`app.1.log` → `app.2.log`、`app.log` → `app.1.log`，
  /// 然后开一个新的空 `app.log`。
  ///
  /// 全程只用 rename/delete，不做「读取-重写」，故不会在慢速存储上卡顿；
  /// 代价是文件边界处的日志可能被切断——但每行自带完整时间戳，可读性不受影响。
  Future<void> _rotate() async {
    final path = _fileSinkPath;
    if (path == null) return;
    final dir = Directory(p.dirname(path));
    final current = File(path);

    try {
      await _fileSink?.flush();
      await _fileSink?.close();
      _fileSink = null;

      final oldest = File(
        p.join(dir.path, '$_logFileBaseName.$maxFileCount$_logFileExtension'),
      );
      if (await oldest.exists()) {
        await oldest.delete();
      }
      for (var i = maxFileCount - 1; i >= 1; i--) {
        final from = File(
          p.join(dir.path, '$_logFileBaseName.$i$_logFileExtension'),
        );
        if (await from.exists()) {
          await from.rename(
            p.join(dir.path, '$_logFileBaseName.${i + 1}$_logFileExtension'),
          );
        }
      }
      if (await current.exists()) {
        await current.rename(
          p.join(dir.path, '$_logFileBaseName.1$_logFileExtension'),
        );
      }
      await _openCurrentLogFile(dir);
    } catch (err) {
      // 轮转失败（如磁盘满、权限异常）不应让日志静默消失：
      // 退回追加到原文件，下一次超限时再试。
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppLogger: rotate failed: $err');
      }
      if (_fileSink == null && await current.exists()) {
        try {
          _fileSink = current.openWrite(mode: FileMode.append);
          _bytesWritten = await current.length();
        } catch (_) {
          // 实在打不开就放弃本次轮转，内存缓冲仍可正常工作。
        }
      }
    }
  }

  /// 删除全部落盘日志文件（含历史轮转份），并停止写入。
  ///
  /// 供设置页「清除所有数据」与关闭落盘时调用。
  ///
  /// 不依赖 sink 曾否启用：关闭落盘后 `_fileSinkPath` 会变 null，但磁盘上
  /// 仍留着历史文件，因此此时回落到默认目录继续清理。忽略单个文件删除失败，
  /// 保证尽力清理。
  Future<void> deletePersistedFiles({String? overridePath}) async {
    final dir = overridePath != null
        ? Directory(overridePath)
        : _fileSinkPath != null
        ? Directory(p.dirname(_fileSinkPath!))
        : await resolveLogDir();
    await disableFileSink();
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(_logFileBaseName)) continue;
        if (!name.endsWith(_logFileExtension)) continue;
        try {
          await entity.delete();
        } catch (_) {
          // 单个文件删不掉（如被占用）不影响其余清理。
        }
      }
    } catch (err) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppLogger: deletePersistedFiles failed: $err');
      }
    }
  }

  /// 把当前日志导出到 [targetDir] 下的 `bugaoshan-log-{timestamp}.log`，
  /// 返回最终写入的文件路径。失败抛异常。
  ///
  /// 供 LogViewer "Save" 按钮使用 — 调用方负责选定 [targetDir]
  /// （推荐 `getLogBaseDir()` 路径下的 `Bugaoshan/logs/`）。
  Future<String> exportToFile(Directory targetDir) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final ts = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${ts.year}${two(ts.month)}${two(ts.day)}-${two(ts.hour)}${two(ts.minute)}${two(ts.second)}';
    final file = File(p.join(targetDir.path, 'bugaoshan-log-$stamp.log'));
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
