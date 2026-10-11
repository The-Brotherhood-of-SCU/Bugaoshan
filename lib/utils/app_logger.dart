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
    return '$ts ${level.name.toUpperCase().padRight(5)} [$tag] $message$detail$stack';
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
    r"""\b((?:access_?token|refresh_?token|token|password|passwd|pwd|secret)\s*[=:]\s*)([^\s,;"'\]\}]+)""",
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

  static const String _logFileBaseName = 'bugaoshan';
  static const String _logFileExtension = '.log';

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
  /// **不等于实际可用**——实际状态见 [fileSinkHealthy] 与
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

  /// 是否正在主动关闭 sink（[disableFileSink] / [_rotate] / [dispose]）。
  ///
  /// 关闭期间 [IOSink] 抛出的 `Bad state: StreamSink is bound to a stream`
  /// 是**预期行为**，不是故障。让 [sink.done] 正常完成即可——否则
  /// [_watchSinkFailure] 会把它当成写盘失败，进而触发 [_recoverSink]，
  /// 与正在进行的关闭动作争抢同一个 sink（实测 flush 与 close 连续报错）。
  bool _closingSink = false;

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

  /// 待落盘的行（由 [_drainQueue] 串行消费）。
  final List<String> _writeQueue = [];

  /// 是否有消费者正在运行。保证任一时刻只有一个 Future 在改文件。
  bool _draining = false;

  /// 因队列满而丢弃的行数，便于排障时量化「日志系统自身在丢」。
  int _droppedLines = 0;

  /// 待落盘行的队列上界。
  ///
  /// 取值权衡：队列满意味着文件 IO 严重跟不上（如磁盘写满、设备存储极慢），
  /// 此时无限增长会耗尽内存并拖垮应用——日志不应成为故障本身。
  static const int _maxWriteQueue = 2000;

  /// 自上次 [_rotateIfNeeded] 起已写入的字节数。避免每行都 `stat()` 系统调用。
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

  /// 文件写入路径（仅在 [fileSinkEnabled] 为 true 时有值）。
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
    Object? error,
    Object? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: timestamp ?? DateTime.now(),
      level: level,
      tag: tag,
      message: LogRedactor.apply(message),
      error: error == null ? null : LogRedactor.apply(error.toString()),
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

    if (_fileSinkEnabled && level.index >= _minPersistedLevel.index) {
      _appendToFile(entry.format(includeDate: true));
    }

    _notify();
  }

  /// 便捷方法：debug / info / warn / error。
  ///
  /// [w] / [e] 接受 [error] 与 [stackTrace]——排障时最常被记录的就是这两项，
  /// 让它们成为一等参数比让每个 catch 块自己拼字符串更可靠。
  void d(String tag, String message) => log(LogLevel.debug, tag, message);
  void i(String tag, String message) => log(LogLevel.info, tag, message);
  void w(String tag, String message, {Object? error, Object? stackTrace}) =>
      log(LogLevel.warn, tag, message, error: error, stackTrace: stackTrace);
  void e(String tag, String message, {Object? error, Object? stackTrace}) =>
      log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);

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

  /// 启用文件落盘。默认由应用启动时调用（仅 warn/error 实际写入）。
  ///
  /// [overridePath] 为空时使用 [resolveLogDir] 的默认路径 —— 与 Dev 页
  /// 导出路径一致，因此 Android 上用户可直接用文件管理器查看排障日志，
  /// 且 OS 可在低存储时自动清理该目录。
  ///
  /// 重复调用会先关闭旧 sink。落盘失败不阻塞业务。
  ///
  /// 注意：失败时**不**把 [_fileSinkEnabled] 置回 false——那是「用户意图」，
  /// 由调用方（`AppConfigProvider`）决定；此处只如实标记
  /// [_fileSinkHealthy] = false，让 UI 可以区分「配置为开」与「实际在写」。
  Future<void> enableFileSink({String? overridePath}) async {
    if (_fileSinkEnabled) return;
    try {
      _logDirPath = overridePath ?? (await resolveLogDir()).path;
      await _openCurrentLogFile();
      _fileSinkEnabled = true;
      _fileSinkHealthy = true;
      _sinkRecoveryAttempts = 0;
      _notify();
    } catch (err, stackTrace) {
      // 落盘失败不应阻塞业务，但必须让用户/开发者看得见——静默失败会让人
      // 误以为日志已被保留，而崩溃现场恰恰因此丢失。
      _fileSinkHealthy = false;
      _fileSinkError = err.toString();
      w('AppLogger', '开启日志落盘失败', error: err, stackTrace: stackTrace);
      _notify();
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppLogger: enableFileSink failed: $err');
      }
    }
  }

  /// 打开（或重建）当前写入文件，并把计数归零。
  Future<void> _openCurrentLogFile() async {
    final dir = Directory(_logDirPath!);
    // 目录可能被系统清理：日志刻意落在**外部 cache**，正是为了在 Android
    // 低存储时由 OS 自动回收。但回收后用户不会主动重启 App，目录也不会
    // 自行复原——若此处不重建，后续 openWrite 会拿到一个写入即失败的句柄，
    // 而 [fileSinkEnabled] 仍为 true，界面显示「已开启」却一条也写不进去。
    // 这是 Android 上的常规场景，不是边缘情况。
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, '$_logFileBaseName$_logFileExtension'));
    // 追加模式：不截断既有内容，冷启动后新日志接在旧文件后面。
    final sink = file.openWrite(mode: FileMode.append);
    _fileSink = sink;
    _fileSinkPath = file.path;
    _bytesWritten = await file.exists() ? await file.length() : 0;
    _watchSinkFailure(sink);
  }

  /// 监听 sink 的异步失败（磁盘满、存储被移除、权限变更等）。
  ///
  /// `IOSink.write` / `flush` 的错误**不会**同步抛给调用方——它们在内部
  /// 累积，等 `done` 完成为 Error 才暴露。若不监听，一次磁盘写满就会让
  /// sink 永久静默失败：界面仍显示「落盘已开启」，磁盘上却再无内容，
  /// 且没有任何提示——排障时最难排查的正是这种「看起来在工作」的状态。
  ///
  /// **失败后不关闭 [_fileSinkEnabled]**。早期实现在此把它置 false，
  /// 等于消费者唯一的入口被自己关掉：队列自此只增不减，且没有任何路径
  /// 能重新打开——一次磁盘抖动就让落盘永久失效，而用户界面上仍写着
  /// 「已开启」。现在改为标记 [_fileSinkHealthy] = false 并走
  /// [_recoverSink]，把「意图」与「可用」这两个状态分开。
  ///
  /// 移植自 PR #369（moranfanhua）的 `sink.done.catchError` 设计。
  void _watchSinkFailure(IOSink sink) {
    // ignore: discarded_futures
    sink.done.catchError((Object error, StackTrace stackTrace) {
      // 竞态保护：轮转/关闭会先换走 sink，此时旧 sink 的失败属预期，
      // 不该把已经切到新文件的 logger 再关掉。
      if (!identical(_fileSink, sink)) return;
      if (_closingSink) return;
      _fileSinkHealthy = false;
      _fileSinkError = error.toString();
      w('AppLogger', '日志文件写入失败', error: error, stackTrace: stackTrace);
      _recoverSink(error);
    });
  }

  /// 尝试重开日志文件。成功则继续落盘；连续失败达上限则停手并保持可见的
  /// 故障状态（[fileSinkUnavailable] 为 true），让 UI 能提示用户。
  ///
  /// 旧 sink 的关闭失败在此吞掉——它已经坏了，重试关闭只会重复抛错。
  Future<void> _recoverSink(Object reason) async {
    if (_disposed || !_fileSinkEnabled) return;
    // 关闭/轮转期间不要插手：那两条路径正在处理同一个 sink，
    // 抢着close 会让 flush 与 close 连续抛 `StreamSink is bound to a stream`。
    if (_closingSink) return;
    if (_sinkRecoveryAttempts >= _maxSinkRecoveryAttempts) {
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          'AppLogger: sink recovery abandoned after '
          '$_sinkRecoveryAttempts attempts: $reason',
        );
      }
      return;
    }
    _sinkRecoveryAttempts++;

    final broken = _fileSink;
    _fileSink = null;
    _fileSinkPath = null;
    _closingSink = true;
    try {
      await broken?.close();
    } catch (_) {
      // 已损坏的 sink，关闭失败属预期。
    }
    _closingSink = false;

    try {
      await _openCurrentLogFile();
      _fileSinkHealthy = true;
      _fileSinkError = null;
      _sinkRecoveryAttempts = 0;
      _ensureDraining();
      _notify();
    } catch (err, stackTrace) {
      // 目录可能仍不可写（磁盘满时不缺权限，缺的是空间）；
      // 保留 unhealthy 状态，下一条日志会再次触发恢复尝试。
      _fileSinkHealthy = false;
      w('AppLogger', '重建日志文件失败', error: err, stackTrace: stackTrace);
    }
  }

  /// 把一行交给落盘队列（**仅入队，绝不碰文件**）。
  ///
  /// 这是修复「同步突发写入丢日志」的关键：[log] 必须保持同步（它在任意
  /// 业务路径上被调用，不能等待文件 IO），而文件操作本身是异步的。
  /// 二者直接耦合必然产生竞态——旧实现里 `unawaited(_rotate())` 之后同步
  /// 代码继续执行，导致每条日志都触发轮转并被丢弃（实测 400 条只落盘 30 条）。
  /// 故此处只做入队，实际写入由串行消费者 [_drainQueue] 负责。
  void _appendToFile(String line) {
    if (_writeQueue.length >= _maxWriteQueue) {
      // 队列满意味着文件 IO 严重跟不上（如磁盘写满或存储极慢）。
      // 此时丢弃并计数，而不是无限增长耗尽内存——日志不应拖垮应用。
      _droppedLines++;
      return;
    }
    _writeQueue.add(line);
    _ensureDraining();
  }

  /// 确保消费者在运行。消费者自行结束后会把 [_draining] 置回 false。
  void _ensureDraining() {
    if (_draining) return;
    _draining = true;
    // ignore: discarded_futures
    _drainQueue();
  }

  /// 串行消费者：把队列里的行写进当前文件，必要时轮转。
  ///
  /// 全程只有这一个 Future 在改文件，所以不需要重入保护——
  /// [_draining] 保证任一时刻只有一个消费者。
  Future<void> _drainQueue() async {
    try {
      while (_writeQueue.isNotEmpty) {
        final sink = _fileSink;
        if (sink == null) {
          // sink 未就绪：若仍希望落盘，说明是失败后的空窗期——
          // 触发一次恢复尝试（有次数上限），否则队列只增不减直到撞上界。
          // 直接丢弃会丢崩溃现场，不可接受。
          if (_fileSinkEnabled) {
            // 恢复是异步的（要重开文件）。不 await：此处必须立刻退出循环，
            // 否则会在等待期间被 finally 的重入检查再次拉起消费者。
            // [_recoverSink] 内部成功后会自己调 [_ensureDraining]。
            unawaited(_recoverSink('sink 不可用，等待恢复'));
          }
          break;
        }
        if (_bytesWritten >= maxBytesPerFile) {
          await _rotate();
          continue;
        }
        final line = _writeQueue.removeAt(0);
        sink.writeln(line);
        _bytesWritten += '$line\n'.length;
      }
      // 收尾：把sink 刷到磁盘，避免进程被杀时丢内容。
      // 关闭期可能已经有人把 sink 换走/关掉，此时 flush 必然抛
      // `StreamSink is bound to a stream`——那是预期竞态，不是故障。
      if (!_closingSink) await _fileSink?.flush();
    } catch (err, stackTrace) {
      // 写盘失败（如磁盘满）在此暴露；注意 IOSink 的异步错误另由
      // [_watchSinkFailure] 兜住，两条路径都要留痕，不能只在 debug 打印。
      w('AppLogger', '日志落盘失败', error: err, stackTrace: stackTrace);
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppLogger: drain failed: $err');
      }
    } finally {
      _draining = false;
      // 关闭/轮转期间可能又来了新日志，此时需要再跑一轮。
      if (_writeQueue.isNotEmpty && _fileSink != null) _ensureDraining();
    }
  }

  /// 多文件轮转：`app.2.log` 删除、`app.1.log` → `app.2.log`、`app.log` → `app.1.log`，
  /// 然后开一个新的空 `app.log`。
  ///
  /// 全程只用 rename/delete，不做「读取-重写」，故不会在慢速存储上卡顿；
  /// 代价是文件边界处的日志可能被切断——但每行自带完整时间戳，可读性不受影响。
  ///
  /// 只由 [_drainQueue] 串行调用，故无需考虑并发。
  Future<void> _rotate() async {
    final path = _fileSinkPath;
    if (path == null) return;
    final dir = Directory(p.dirname(path));
    final current = File(path);

    try {
      final closing = _fileSink;
      _fileSink = null;
      // 关闭期间 sink 抛错属预期，不能让 [_watchSinkFailure] 误判为写盘失败
      // 而触发恢复（那会与本方法争抢文件）。
      _closingSink = true;
      try {
        await closing?.flush();
        await closing?.close();
      } finally {
        _closingSink = false;
      }

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
      await _openCurrentLogFile();
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

  /// 删除自动落盘产生的日志文件（`bugaoshan.log` 与 `bugaoshan.N.log`），并停止写入。
  ///
  /// 供设置页「清除所有数据」与关闭落盘时调用。
  ///
  /// 不依赖 sink 曾否启用：关闭落盘后 `_fileSinkPath` 会变 null，但磁盘上
  /// 仍留着历史文件，因此此时回落到默认目录继续清理。忽略单个文件删除失败，
  /// 保证尽力清理。
  ///
  /// **只删轮转文件，不手动导出的快照**（`exportToFile` 产出的
  /// `bugaoshan-log-<时间戳>.log`）。导出是用户主动拿去分享给他人的产物，
  /// 关掉落盘开关不该顺手清掉，故按文件名精确匹配而非前缀匹配——
  /// 改 [_logFileBaseName] 时尤其容易踩这个边界（曾用
  /// `startsWith('app')` 侥幸避开，base 改成 `bugaoshan` 就会误删导出文件）。
  Future<void> deletePersistedFiles({String? overridePath}) async {
    final dir = overridePath != null
        ? Directory(overridePath)
        : _fileSinkPath != null
        ? Directory(p.dirname(_fileSinkPath!))
        : await resolveLogDir();
    await disableFileSink();
    final rotated = RegExp(
      '^${RegExp.escape(_logFileBaseName)}(\\.\\d+)?${RegExp.escape(_logFileExtension)}\$',
    );
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (!rotated.hasMatch(p.basename(entity.path))) continue;
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

  /// 把当前日志导出到 [targetDir] 下的 `bugaoshan-export-{timestamp}.log`，
  /// 返回最终写入的文件路径。失败抛异常。
  ///
  /// 命名为 `export` 而非 `log`，与轮转文件 `bugaoshan.log` / `bugaoshan.N.log`
  /// 明确区分：前者是用户主动分享的快照（不被
  /// [deletePersistedFiles] 清理），后者是自动轮转产物。
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
    final file = File(p.join(targetDir.path, 'bugaoshan-export-$stamp.log'));
    await file.writeAsString(exportToText());
    return file.path;
  }

  /// 关闭文件落盘。
  Future<void> disableFileSink() async {
    if (!_fileSinkEnabled) return;
    // 先等队列排空再关闭：否则队列里的行会随 sink 关闭而永久丢失。
    // 关闭后不再续跑，故这里是有界的等待。
    //
    // 注意**排空期间不能置 [_closingSink]**：消费者的收尾flush 与
    // [_recoverSink] 都受它约束，提前置位会让排空过程跳过写入，
    // 结果是刚入队的行被白白丢弃（实测「关闭-重开-再写」丢失最后一条）。
    // 排空完成后、真正close 之前才置位。
    await _drainQueueOnce();
    // flush 与 close 分开兜底：flush 失败（如磁盘满）不该连带跳过 close，
    // 否则句柄泄漏，下次 enableFileSink 会累积未关闭的 sink。
    // 移植自 PR #369（moranfanhua）的 `_closeSink`。
    final sink = _fileSink;
    _closingSink = true;
    try {
      await sink?.flush();
    } catch (err, stackTrace) {
      w('AppLogger', '刷新日志文件失败', error: err, stackTrace: stackTrace);
    }
    try {
      await sink?.close();
    } catch (err, stackTrace) {
      w('AppLogger', '关闭日志文件失败', error: err, stackTrace: stackTrace);
    }
    _closingSink = false;
    _fileSink = null;
    _fileSinkPath = null;
    _logDirPath = null;
    _fileSinkEnabled = false;
    _fileSinkHealthy = false;
    _fileSinkError = null;
    _sinkRecoveryAttempts = 0;
    _notify();
  }

  /// 等待队列排空（用于关闭前；与 [_drainQueue] 共用同一条消费路径）。
  ///
  /// 必须等到**队列空且消费者已收尾**（含最后一次 flush 完成）才算结束。
  /// 早期实现对空队列只`await Duration.zero`——那仅让出一个 microtask，
  /// 而消费者的收尾flush 需要真实 IO 事件循环，于是关闭方抢在 flush 之前
  /// 关掉 sink，队列里刚入队的行被丢弃（实测「关闭→重开→再写」丢最后一条）。
  Future<void> _drainQueueOnce() async {
    _ensureDraining();
    // 有界等待：正常路径只需一两轮；上限兜底防止消费者异常时永久阻塞
    // 调用方（此刻正在等待的通常是 disableFileSink）。
    for (var i = 0; i < 400; i++) {
      if (!_draining && _writeQueue.isEmpty) {
        // 队列空且无消费者，但可能刚启动过一个还没跑起来的消费者；
        // 让出一帧确认它确实没有残留工作。
        await Future<void>.delayed(Duration.zero);
        if (!_draining && _writeQueue.isEmpty) return;
        continue;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// 因队列满而丢弃的行数（供 Dev 页排障时量化）。
  int get droppedWriteLines => _droppedLines;

  /// 自动恢复落盘的最大尝试次数。
  ///
  /// 超过即认定存储长期不可用（磁盘满、权限被回收），继续重试只会空转
  /// 并持续产生「恢复失败」的日志本身——那正是日志系统不该成为故障的地方。
  static const int _maxSinkRecoveryAttempts = 3;

  @override
  void dispose() {
    _disposed = true;
    _closingSink = true;
    // 队列里可能还有未落盘的行：先尽力排空（dispose 是同步的，无法等待，
    // 故用 then 链在后台完成），再关闭 sink，避免丢内容。
    final queue = _writeQueue;
    if (queue.isNotEmpty) {
      unawaited(
        _drainQueueOnce().then((_) async {
          try {
            await _fileSink?.flush();
            await _fileSink?.close();
          } catch (_) {
            // 释放阶段失败无需处理。
          }
          _fileSink = null;
        }),
      );
      _writeQueue.clear();
    } else {
      // 关闭期间的 sink 报错属预期，吞掉即可，不应触发恢复路径。
      _fileSink?.flush().catchError((_) {});
      _fileSink?.close().catchError((_) {});
      _fileSink = null;
    }
    super.dispose();
  }
}
