import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_logger_file_sink.dart';

/// 日志级别。
enum LogLevel { debug, info, warn, error }

/// 分类与级别独立：认证失败仍属于认证日志，业务失败属于业务日志。
enum LogCategory { authentication, business }

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
  final LogCategory category;

  /// 异常对象与其堆栈，**独立于 [message]**。
  ///
  /// 早期实现把两者拼进 message 字符串，代价是 UI 无法分别处理：查看器只能
  /// 把整条文本一样渲染，既不能折叠堆栈、也不能按 message 长度截断显示。
  /// 拆成字段后，UI 可按需省略堆栈，落盘时也能保持结构化的一行。
  ///
  /// 两者在写入前都经 [LogRedactor] 脱敏——堆栈里常出现请求 URL，
  /// 可能带 `?code=` 之类的一次性凭据。
  final String? error;
  final String? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.category = LogCategory.authentication,
    this.error,
    this.stackTrace,
  });

  /// 输出为单行文本，供 UI 列表 / 文件导出使用。
  ///
  /// 格式：`HH:mm:ss.SSS LEVEL [tag] message`。
  /// [error] / [stackTrace] 存在时追加为后续行——堆栈必须保持逐行原样，
  /// 压成一行会丢失帧序号与文件行号，排障时无法定位。
  String format({bool includeDate = false, bool includeStackTrace = true}) {
    final ts = includeDate
        ? _formatDateTime(timestamp)
        : _formatTime(timestamp);
    final detail = error == null ? '' : '\n  error: $error';
    final stack = (!includeStackTrace || stackTrace == null)
        ? ''
        : '\n$stackTrace';
    return '$ts ${level.name.toUpperCase().padRight(5)} '
        '[${category.name}] [$tag] $message$detail$stack';
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
    r'("(?:access_?token|refresh_?token|reset_?token|sToken|token(?:key)?|cookie|authorization|userinfo|ticket|jsessionid|sessionid)"\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _passwordJson = RegExp(
    r'("(?:password|pwd|new_?password|confirm_?password)"\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _bearerHeader = RegExp(
    r'''(Bearer\s+)[^\s,"']+''',
    caseSensitive: false,
  );
  static final RegExp _oauthCode = RegExp(
    r'([?&](?:code|access_?token|refresh_?token|reset_?token|sToken|token(?:key)?|password|pwd|userinfo|ticket|jsessionid|sessionid)=)([^&\s"]+)',
    caseSensitive: false,
  );

  /// 非 JSON 形式的凭据键值对：`password=xxx`、`token=xxx`、`pwd: xxx` 等。
  ///
  /// 此前只覆盖了 JSON 形式（`"password":"xxx"`），漏掉了这类——
  /// 而异常堆栈里出现的请求构造参数恰恰多是这种形态（`StateError('token=...')`），
  /// 是真实泄露路径。
  ///
  /// 键名限定为明确的凭据词，**不含 `id` / `account` / `key` 等宽泛词**，
  /// 避免把普通参数一起抹掉；也**不含 `authorization` / `cookie`**——
  /// 这两个由 [_bearerHeader] 等专门规则处理，若在此一并匹配会先吃掉
  /// `Authorization: Bearer xxx` 的前缀，导致 Bearer 规则失效。
  static final RegExp _credentialLabel = RegExp(
    r"""\b((?:access_?token|refresh_?token|reset_?token|sToken|token(?:key)?|ticket|password|passwd|pwd|new_?password|confirm_?password|secret)\s*[=:]\s*)([^\s,;"'\]\}]+)""",
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
      if (!RegExp(r'^[?&]code=$', caseSensitive: false).hasMatch(prefix)) {
        return '$prefix<redacted>';
      }
      if (value.length <= 4) return '$prefix<redacted>';
      return '$prefix${value.substring(0, 4)}…';
    });
    result = result.replaceAllMapped(
      _principalLabel,
      (m) => '${m[1]}=<redacted>',
    );
    // 非 JSON 凭据键值：保留原分隔符形态，仅替换值部。
    result = result.replaceAllMapped(
      _credentialLabel,
      (m) => '${m[1]}<redacted>',
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

/// FormatException 的 source 可能含响应或表单正文，不进入异常日志。
String describeLogError(Object error) => error is FormatException
    ? 'FormatException: ${error.message} (offset=${error.offset})'
    : error.toString();

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
  static const String _tag = 'AppLogger';
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

  static const String _logFileBaseName = 'bugaoshan';
  static const String _logFileExtension = '.log';
  static const int _maxExportSnapshots = 5;

  final int capacity;

  /// 单个文件大小上限，超过则轮转。作为实例字段而非编译期常量，
  /// 便于测试用小阈值验证轮转行为而不必写 2 MB。
  final int maxBytesPerFile;

  /// 保留的历史份数（不含当前 `app.log`）。
  final int maxFileCount;

  final List<LogEntry> _buffer = [];

  /// tag → 当前缓冲中该 tag 的条数。与 [_buffer] 同步维护，供筛选条使用。
  final Map<String, int> _tagCounts = {};

  /// 用户**意图**落盘（由 [AppConfigProvider.logPersistenceEnabled] 驱动）。
  ///
  /// **不等于实际可用**——实际状态见 [_fileSinkHealthy] 与
  /// [fileSinkUnavailable]。二者必须分开：早期实现只有一个 flag，
  /// 导致「sink 失败」直接把落盘入口一并关掉，从此永久失效且无法自愈
  /// （消费者只在它为真时才运行，等于自己关掉了自己的入口）。
  bool _fileSinkEnabled = false;

  /// sink 当前是否可用。为 false 表示上次写入已失败或目录不可写，
  /// 此时会尝试重开；连续失败达[_maxSinkRecoveryAttempts] 次后停止重试，
  /// 避免在磁盘长期不可写时反复空转。
  bool _fileSinkHealthy = false;

  /// 已连续尝试恢复落盘的次数，达到上限后不再自动重试。
  int _sinkRecoveryAttempts = 0;

  /// 最近一次落盘故障的原因（用户可读），成功恢复后清空。
  String? _fileSinkError;

  IOSink? _fileSink;
  String? _fileSinkPath;
  String? _logDirPath;

  /// 是否已 [dispose]。dispose 是异步收尾（排空队列后再关 sink），
  /// 期间可能仍有日志写入或消费者回调，此时对已释放的 ChangeNotifier
  /// 调用 `notifyListeners()` 会抛断言错误。
  ///
  /// 移植自 PR #369（moranfanhua）的 `_disposed` 守卫。
  bool _disposed = false;

  /// 待落盘的记录；序号将快速开关前后的写入划分到对应的文件操作。
  final List<({int sequence, String line})> _writeQueue = [];
  int _writeSequence = 0;
  _LogWriteBatch? _pendingDrain;

  /// 开关、写入、轮转、清理和导出共用一条串行操作链。
  Future<void> _fileOperations = Future<void>.value();

  /// 文件系统自身的错误只进入内存，不能重新排入失败的写入队列。
  bool _reportingSinkFailure = false;

  /// 因队列满而丢弃的行数，便于排障时量化「日志系统自身在丢」。
  int _droppedLines = 0;

  /// 待落盘行的队列上界。
  ///
  /// 取值权衡：队列满意味着文件 IO 严重跟不上（如磁盘写满、设备存储极慢），
  /// 此时无限增长会耗尽内存并拖垮应用——日志不应成为故障本身。
  static const int _maxWriteQueue = 2000;

  /// 当前文件的 UTF-8 字节数，避免每行都 `stat()` 系统调用。
  int _bytesWritten = 0;

  AppLogger({
    this.capacity = _defaultCapacity,
    this.maxBytesPerFile = _defaultMaxBytesPerFile,
    this.maxFileCount = _defaultMaxFileCount,
  });

  /// 通知监听者，已 dispose 后静默跳过。
  ///
  /// dispose 是异步收尾：队列排空、sink 关闭都在之后完成，期间到达的日志
  /// 或消费者回调若直接调`notifyListeners()`，会触发 ChangeNotifier 的
  /// 已释放断言。日志此时已无处可展示，静默是正确的。
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// 当前日志列表（只读快照，顺序：旧 → 新）。
  List<LogEntry> get entries => List.unmodifiable(_buffer);

  /// 各 tag 在当前缓冲中的条数，按条数降序。
  ///
  /// 增量维护而非每次从 [entries] 现算：查看器每收到一条日志就会重建，
  /// 若每次都遍历整个缓冲（上限 1000 条）并排序，写满一轮就是 O(n²)。
  List<MapEntry<String, int>> get tagCounts {
    final list = _tagCounts.entries.toList()
      ..sort((a, b) {
        // 条数降序；同条数时按 tag 字母序，保证顺序稳定可预期。
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return list;
  }

  bool hasTag(String tag) => _tagCounts.containsKey(tag);

  /// 当前是否启用了文件写入（**用户意图**，不代表实际可写）。
  bool get fileSinkEnabled => _fileSinkEnabled;

  /// 用户已要求落盘，但当前实际写不进去（磁盘满、权限失效、目录被清理
  /// 且重建失败，或重试次数已用尽）。
  ///
  /// UI 必须能读到它：否则用户看到「已开启」却发现文件始终不存在，
  /// 无从判断是应用 bug 还是设备存储问题——这正是「看起来在工作」的状态。
  bool get fileSinkUnavailable => _fileSinkEnabled && !_fileSinkHealthy;

  /// 落盘最近一次失败的原因，供 UI 展示（为空表示无故障）。
  String? get fileSinkError => _fileSinkError;

  /// 当前打开的文件路径；尚未打开、关闭或故障恢复期间为空。
  String? get fileSinkPath => _fileSinkPath;

  /// 写入一条日志。level 默认为 [LogLevel.info]。
  ///
  /// [error] / [stackTrace] 可选，传入后作为独立字段存入 [LogEntry]（经脱敏），
  /// 不需要调用方自己拼进 [message]。
  void log(
    LogLevel level,
    String tag,
    String message, {
    DateTime? timestamp,
    LogCategory category = LogCategory.authentication,
    Object? error,
    Object? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: timestamp ?? DateTime.now(),
      level: level,
      tag: tag,
      message: LogRedactor.apply(message),
      category: category,
      error: error == null ? null : LogRedactor.apply(describeLogError(error)),
      stackTrace: stackTrace == null
          ? null
          : LogRedactor.apply(stackTrace.toString()),
    );
    _buffer.add(entry);
    _tagCounts[tag] = (_tagCounts[tag] ?? 0) + 1;
    if (_buffer.length > capacity) {
      // 逐条递减被淘汰条目的计数，保持与 [tagCounts] 一致。
      final overflow = _buffer.length - capacity;
      for (var i = 0; i < overflow; i++) {
        final evicted = _buffer[i];
        final left = (_tagCounts[evicted.tag] ?? 1) - 1;
        if (left <= 0) {
          _tagCounts.remove(evicted.tag);
        } else {
          _tagCounts[evicted.tag] = left;
        }
      }
      _buffer.removeRange(0, overflow);
    }

    // 仅 debug 模式同时打到控制台，避免生产包日志噪声。
    // 使用 debugPrint 而非 print：避免 stdout 与其他异步日志乱序交错，
    // 并获得 Flutter 自带的同帧节流防刷屏。
    if (kDebugMode) {
      debugPrint(entry.format());
    }

    if (_fileSinkEnabled &&
        !_disposed &&
        !_reportingSinkFailure &&
        level.index >= _minPersistedLevel.index) {
      _appendToFile(entry.format(includeDate: true));
    }

    _notify();
  }

  /// 便捷方法：debug / info / warn / error。
  ///
  /// [w] / [e] 接受 [error] 与 [stackTrace]——排障时最常被记录的就是这两项，
  /// 让它们成为一等参数比让每个 catch 块自己拼字符串更可靠。
  void d(
    String tag,
    String message, {
    LogCategory category = LogCategory.authentication,
  }) => log(LogLevel.debug, tag, message, category: category);
  void i(
    String tag,
    String message, {
    LogCategory category = LogCategory.authentication,
  }) => log(LogLevel.info, tag, message, category: category);
  void w(
    String tag,
    String message, {
    Object? error,
    Object? stackTrace,
    LogCategory category = LogCategory.authentication,
  }) => log(
    LogLevel.warn,
    tag,
    message,
    error: error,
    stackTrace: stackTrace,
    category: category,
  );
  void e(
    String tag,
    String message, {
    Object? error,
    Object? stackTrace,
    LogCategory category = LogCategory.authentication,
  }) => log(
    LogLevel.error,
    tag,
    message,
    error: error,
    stackTrace: stackTrace,
    category: category,
  );

  /// 记录认证操作的最终异常，并保留原异常传播。
  Future<T> guard<T>(
    String tag,
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      e(tag, '$operation 失败', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 清空当前缓冲（不影响文件落盘的历史记录）。
  void clear() {
    if (_buffer.isEmpty) return;
    _buffer.clear();
    _tagCounts.clear();
    _notify();
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

  /// 启用 warn/error 落盘；启动期可补写启用前的缓冲记录。
  /// 失败保留开启意图，并通过可用性与错误字段报告。
  Future<void> enableFileSink({
    String? overridePath,
    bool includeBufferedEntries = false,
  }) => _enableFileSink(
    overridePath: overridePath,
    includeBufferedEntries: includeBufferedEntries,
  );

  /// 等待已接受的记录写入；不改变落盘开关或关闭文件。
  Future<void> flushFileSink() => _flushFileSink();

  /// 排空已接受的记录后关闭落盘。开关意图立即生效，文件操作按调用顺序执行。
  Future<void> disableFileSink() => _disableFileSink();

  /// 清理自动轮转文件，保留手动导出。默认同时关闭落盘；清除所有数据时可
  /// 使用 [preserveEnabled]，按当前开关状态恢复写入。
  Future<void> deletePersistedFiles({
    String? overridePath,
    bool preserveEnabled = false,
  }) => _deletePersistedFiles(
    overridePath: overridePath,
    preserveEnabled: preserveEnabled,
  );

  /// 导出历史落盘文件与当前内存上下文，返回可分享的快照路径。
  Future<String> exportToFile(Directory targetDir) => _exportToFile(targetDir);

  /// 因队列满而丢弃的行数（供 Dev 页排障时量化）。
  int get droppedWriteLines => _droppedLines;

  static const int _maxSinkRecoveryAttempts = 3;

  @override
  void dispose() {
    _disposed = true;
    unawaited(disableFileSink());
    super.dispose();
  }
}
