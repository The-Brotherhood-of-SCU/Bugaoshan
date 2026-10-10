import 'dart:io';

import 'package:bugaoshan/utils/app_error_reporter.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogRedactor', () {
    test('脱敏日志中的账号和用户标识', () {
      final redacted = LogRedactor.apply(
        'login user=202612345678 userId=ccyl-user-42 username=alice',
      );

      expect(redacted, isNot(contains('202612345678')));
      expect(redacted, isNot(contains('ccyl-user-42')));
      expect(redacted, isNot(contains('alice')));
      expect(redacted, contains('user=<redacted>'));
      expect(redacted, contains('userId=<redacted>'));
      expect(redacted, contains('username=<redacted>'));
    });

    test('保留原有凭据脱敏行为', () {
      final redacted = LogRedactor.apply(
        'Authorization: Bearer secret.token "password":"plain"',
      );

      expect(redacted, contains('Bearer <redacted>'));
      expect(redacted, contains('"password":"<redacted>"'));
      expect(redacted, isNot(contains('secret.token')));
      expect(redacted, isNot(contains('plain')));
    });

    // 回归用例：#367 中实测发现的缺口。学号一旦随日志贴进 issue 即构成个人信息
    // 泄露，而本项目的身份标识就是学号，故这些写法必须被覆盖。
    test('脱敏学号的 snake_case 写法', () {
      for (final input in [
        'student_id=202612345678',
        'student_number=202612345678',
        'user_name=202612345678',
        '"studentId":"202612345678"',
      ]) {
        expect(
          LogRedactor.apply(input),
          isNot(contains('202612345678')),
          reason: '未能脱敏：$input',
        );
      }
    });

    test('脱敏中文「学号」裸值', () {
      for (final input in [
        '学号202612345678',
        '学号 202612345678 成绩查询失败',
        '学号：202612345678',
        '学号=202612345678',
      ]) {
        expect(
          LogRedactor.apply(input),
          isNot(contains('202612345678')),
          reason: '未能脱敏：$input',
        );
      }

      expect(LogRedactor.apply('学号202612345678'), '学号<redacted>');
    });

    // 过度脱敏比漏脱敏更危险：会抹掉排障所需信息，让日志失去价值。
    test('不误伤非身份字段与纯中文叙述', () {
      for (final input in [
        'roomId=202612345678',
        'widgetId=abc-123',
        'cache hit for key grades_2024',
        '课程表加载失败',
        '学号相关的缓存 key',
        '学号信息已脱敏',
      ]) {
        expect(LogRedactor.apply(input), input, reason: '被误脱敏：$input');
      }
    });
  });

  group('AppLogger', () {
    test('环形缓冲超出容量时淘汰最旧条目', () {
      final logger = AppLogger(capacity: 3);
      for (final i in [1, 2, 3, 4, 5]) {
        logger.log(LogLevel.info, 'T', 'msg$i');
      }

      final entries = logger.entries;
      expect(entries, hasLength(3));
      expect(entries.map((e) => e.message).toList(), ['msg3', 'msg4', 'msg5']);
    });

    test('写入时即完成脱敏，缓冲内不留明文凭据', () {
      final logger = AppLogger();
      logger.log(LogLevel.info, 'T', 'token {"access_token":"secret-value"}');

      expect(logger.entries.single.message, isNot(contains('secret-value')));
    });

    // 以下三项保护 tagCounts 的增量维护——它是筛选条的数据源，
    // 若与 entries 不一致，下拉里的条数会与实际不符。
    test('tagCounts 按条数降序，同条数按字母序', () {
      final logger = AppLogger();
      // 用记录而非 [tag, count] 列表：后者会被推断为 List<Object>，取值时类型丢失。
      const plan = [
        (tag: 'A', count: 1),
        (tag: 'B', count: 3),
        (tag: 'C', count: 3),
        (tag: 'D', count: 2),
      ];
      for (final e in plan) {
        for (var i = 0; i < e.count; i++) {
          logger.log(LogLevel.info, e.tag, 'msg');
        }
      }

      expect(logger.tagCounts.map((e) => '${e.key}:${e.value}').toList(), [
        'B:3',
        'C:3',
        'D:2',
        'A:1',
      ]);
    });

    test('tagCounts 随缓冲淘汰同步递减，不残留已淘汰的 tag', () {
      final logger = AppLogger(capacity: 3);
      // 写入顺序刻意让 tag 完全被淘汰：A 先占满缓冲，随后只写 B。
      logger.log(LogLevel.info, 'A', '1');
      logger.log(LogLevel.info, 'A', '2');
      logger.log(LogLevel.info, 'A', '3');
      logger.log(LogLevel.info, 'B', '4');
      logger.log(LogLevel.info, 'B', '5');

      expect(logger.entries, hasLength(3));
      expect(
        logger.tagCounts.map((e) => '${e.key}:${e.value}').toList(),
        ['B:2', 'A:1'],
        reason: 'A 只剩 1 条仍在缓冲内',
      );
    });

    test('clear 同时清空 entries 与 tagCounts', () {
      final logger = AppLogger();
      logger.log(LogLevel.info, 'A', '1');
      logger.log(LogLevel.info, 'B', '2');

      logger.clear();

      expect(logger.entries, isEmpty);
      expect(logger.tagCounts, isEmpty);
    });

    test('clear 清空缓冲但不影响已导出内容', () {
      final logger = AppLogger();
      logger.log(LogLevel.info, 'T', 'before clear');
      final exported = logger.exportToText();

      logger.clear();

      expect(logger.entries, isEmpty);
      expect(exported, contains('before clear'));
    });

    test('格式化条目按 level 与 tag 输出单行', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 10, 9, 22, 30, 5, 42),
        level: LogLevel.warn,
        tag: 'ReminderService',
        message: 'syncPlan skipped',
      );

      expect(
        entry.format(),
        '22:30:05.042 WARN  [ReminderService] syncPlan skipped',
      );
      expect(
        entry.format(includeDate: true),
        '2026-10-09 22:30:05.042 WARN  [ReminderService] syncPlan skipped',
      );
    });
  });

  group('formatExceptionForLog', () {
    test('拼接异常与堆栈', () {
      final formatted = formatExceptionForLog(
        StateError('boom'),
        StackTrace.fromString('#0 main (main.dart:1)'),
      );

      expect(formatted, contains('boom'));
      expect(formatted, contains('main.dart:1'));
    });

    test('超长内容截断并报告省略行数，保留头部异常信息', () {
      final longStack = StackTrace.fromString(
        List.generate(400, (i) => '#$i frame (file$i.dart:1)').join('\n'),
      );

      final formatted = formatExceptionForLog(
        StateError('the-original-error'),
        longStack,
        maxChars: 200,
      );

      expect(formatted.length, lessThan(400));
      expect(formatted, startsWith('Bad state: the-original-error'));
      expect(formatted, contains('more lines]'));
    });

    // 回归用例（#367 review 发现）：FlutterErrorDetails.context 是 DiagnosticsNode，
    // toString() 可能输出整棵组件树，使「上限 - context 长度」为负，
    // substring 抛 RangeError——错误处理器在处理异常时崩溃会掩盖真实错误。
    test('maxChars 为负时不抛异常（防御非法预算）', () {
      final formatted = formatExceptionForLog(
        StateError('the-real-error'),
        StackTrace.fromString('#0 frame (a.dart:1)'),
        maxChars: -5,
      );

      expect(formatted, contains('the-real-error'));
      expect(formatted, contains('a.dart:1'));
    });

    test('maxChars 为 0 时退化为原样返回', () {
      final formatted = formatExceptionForLog(
        StateError('boom'),
        null,
        maxChars: 0,
      );

      expect(formatted, contains('boom'));
    });
  });

  group('文件落盘与轮转', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('bugaoshan_log_test');
    });

    tearDown(() async {
      if (!await tmp.exists()) return;
      // Windows 上 IOSink.close() 到句柄真正释放有短暂延迟，
      // 立即删除会撞上「另一个程序正在使用此文件」。重试数次即可，
      // 属测试环境时序问题，与被测逻辑无关。
      for (var i = 0; i < 5; i++) {
        try {
          await tmp.delete(recursive: true);
          return;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
    });

    Future<List<String>> names() async {
      final list = await tmp.list().toList();
      final paths =
          list
              .whereType<File>()
              .map((f) => f.path.split(RegExp(r'[/\\]')).last)
              .toList()
            ..sort();
      return paths;
    }

    test('只落盘 warn/error，debug/info 不写文件', () async {
      final logger = AppLogger();
      await logger.enableFileSink(overridePath: tmp.path);

      logger.log(LogLevel.debug, 'T', 'debug message');
      logger.log(LogLevel.info, 'T', 'info message');
      logger.log(LogLevel.warn, 'T', 'warn message');
      logger.log(LogLevel.error, 'T', 'error message');
      await logger.disableFileSink();

      final content = await File('${tmp.path}/bugaoshan.log').readAsString();
      expect(content, isNot(contains('debug message')));
      expect(content, isNot(contains('info message')));
      expect(content, contains('warn message'));
      expect(content, contains('error message'));
      // 内存缓冲不受落盘范围影响，Dev 页仍能看到全部级别。
      expect(logger.entries, hasLength(4));
    });

    test('超过单份上限后轮转，最多保留 maxFileCount + 1 份', () async {
      // 阈值取得很小，让几条日志就能触发轮转。
      final logger = AppLogger(maxBytesPerFile: 120, maxFileCount: 2);
      await logger.enableFileSink(overridePath: tmp.path);

      for (var i = 0; i < 40; i++) {
        logger.log(LogLevel.error, 'T', 'message-$i ${'x' * 30}');
        // 让异步轮转有机会完成，避免用例只验证到第一次 rotate。
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await logger.disableFileSink();

      final files = await names();
      expect(files.length, lessThanOrEqualTo(3), reason: '实际：$files');
      expect(files, contains('bugaoshan.log'));
      // 历史份不含 bugaoshan.log，且编号连续。
      final rotated = files.where((f) => f != 'bugaoshan.log').toList();
      expect(rotated.length, lessThanOrEqualTo(2));
    });

    test('冷启动时追加到既有文件，不截断历史日志', () async {
      final first = AppLogger();
      await first.enableFileSink(overridePath: tmp.path);
      first.log(LogLevel.error, 'T', 'first run');
      await first.disableFileSink();
      first.dispose();

      final second = AppLogger();
      await second.enableFileSink(overridePath: tmp.path);
      second.log(LogLevel.error, 'T', 'second run');
      await second.disableFileSink();
      second.dispose();

      final content = await File('${tmp.path}/bugaoshan.log').readAsString();
      expect(content, contains('first run'));
      expect(content, contains('second run'));
    });

    // 回归用例（#367review 发现并修复）：旧实现中 log() 直接写文件、而
    // _rotate() 是异步的，二者竞态使部分日志既没写进旧文件也没被补写。
    // 对照实测（maxBytesPerFile=512、maxFileCount=2，写 400 条）：
    //   旧实现落盘 5 行；新实现落盘 16 行 = 容量上限（3×512B），无额外丢失。
    //
    // 注意：**不可用「落盘行数 == 写入条数」断言**——写入量远超容量时，
    // 超出部分本就该被轮转淘汰。正确断言分两层，见下面两个用例。

    test('容量充足时同步突发写入不丢日志（单写入队列）', () async {
      // 阈值远大于写入总量：此时任何缺失都是真丢失。
      final logger = AppLogger(maxBytesPerFile: 100 * 1024, maxFileCount: 2);
      await logger.enableFileSink(overridePath: tmp.path);

      const total = 200;
      // 故意不 await delay，模拟突发写入（如批量错误同时抛出）。
      for (var i = 0; i < total; i++) {
        logger.log(LogLevel.error, 'T', 'message-$i ${'x' * 60}');
      }
      await logger.disableFileSink();
      logger.dispose();

      var lines = 0;
      for (final name in await names()) {
        lines += (await File('${tmp.path}/$name').readAsLines()).length;
      }
      expect(logger.droppedWriteLines, 0, reason: '队列上界不应被触及');
      expect(lines, total, reason: '写入 $total 条（容量充足）应全部落盘，实际 $lines 行');
    });

    test('写入量超过容量时保留量等于容量上限（非丢弃）', () async {
      final logger = AppLogger(maxBytesPerFile: 512, maxFileCount: 2);
      await logger.enableFileSink(overridePath: tmp.path);

      const total = 400;
      for (var i = 0; i < total; i++) {
        logger.log(LogLevel.error, 'T', 'message-$i ${'x' * 60}');
      }
      await logger.disableFileSink();
      logger.dispose();

      var bytes = 0;
      var files = 0;
      for (final name in await names()) {
        files++;
        bytes += await File('${tmp.path}/$name').length();
      }
      expect(files, lessThanOrEqualTo(3), reason: '最多 maxFileCount + 1 份');
      // 超出容量的部分被正常轮转淘汰，故落盘量应贴近容量上限而非写入总量。
      // 旧实现在此参数下只有 5 字节量级，远低于上限，即为丢失。
      expect(
        bytes,
        greaterThan(512 * 2),
        reason: '落盘 $bytes B，应接近容量上限 1536 B（旧实现仅数百字节）',
      );
      expect(
        bytes,
        lessThanOrEqualTo(512 * 3 + 200),
        reason: '不应超过容量上限太多，实际 $bytes B',
      );
    });

    test('deletePersistedFiles 清理当前与历史文件', () async {
      final logger = AppLogger(maxBytesPerFile: 120, maxFileCount: 2);
      await logger.enableFileSink(overridePath: tmp.path);
      for (var i = 0; i < 40; i++) {
        logger.log(LogLevel.error, 'T', 'message-$i ${'x' * 30}');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((await names()).length, greaterThan(1), reason: '应已产生历史份');

      await logger.deletePersistedFiles();

      expect(await names(), isEmpty);
    });

    // 回归用例：_logFileBaseName 曾从 'app' 改为 'bugaoshan'，而清理逻辑用的是
    // startsWith 前缀匹配 —— 手动导出的 'bugaoshan-export-*.log' 会被一并删掉。
    // 导出是用户主动拿去分享的产物，关掉落盘开关不该顺手清掉。
    test('deletePersistedFiles 不误删手动导出的快照', () async {
      final logger = AppLogger();
      await logger.enableFileSink(overridePath: tmp.path);
      logger.log(LogLevel.error, 'T', 'persisted entry');
      final exported = await logger.exportToFile(Directory(tmp.path));
      final exportedName = exported.split(Platform.pathSeparator).last;
      expect(await File(exported).exists(), isTrue);

      await logger.deletePersistedFiles(overridePath: tmp.path);
      logger.dispose();

      expect(await names(), [exportedName], reason: '应只剩手动导出的快照，自动落盘的轮转文件已被清理');
    });

    test('关闭 sink 后不再写入文件', () async {
      final logger = AppLogger();
      await logger.enableFileSink(overridePath: tmp.path);
      await logger.disableFileSink();

      logger.log(LogLevel.error, 'T', 'after disable');

      final content = await File('${tmp.path}/bugaoshan.log').readAsString();
      expect(content, isNot(contains('after disable')));
      // 内存缓冲仍照常记录，Dev 页不受影响。
      expect(logger.entries, hasLength(1));
    });
  });

  // 以下两项移植自 PR #369（moranfanhua）的设计，见 commit 35cdb35d 说明。
  group('异常与堆栈的独立字段', () {
    test('error 与 stackTrace 独立保存，不拼进 message', () {
      final logger = AppLogger();

      logger.e(
        'T',
        'plain message',
        error: StateError('boom'),
        stackTrace: StackTrace.fromString('#0 main (main.dart:1)'),
      );

      final entry = logger.entries.single;
      expect(entry.message, 'plain message');
      expect(entry.error, contains('boom'));
      expect(entry.stackTrace, contains('main.dart:1'));
    });

    test('堆栈逐行原样保留，不被压成一行', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 1),
        level: LogLevel.error,
        tag: 'T',
        message: 'm',
        stackTrace: '#0 a (a.dart:1)\n#1 b (b.dart:2)',
      );

      final text = entry.format();
      expect(text, contains('#0 a (a.dart:1)\n#1 b (b.dart:2)'));
    });

    test('includeStackTrace: false 时省略堆栈但保留 error', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 1),
        level: LogLevel.error,
        tag: 'T',
        message: 'm',
        error: 'boom',
        stackTrace: '#0 a (a.dart:1)',
      );

      final text = entry.format(includeStackTrace: false);
      expect(text, isNot(contains('#0 a')));
      expect(text, contains('boom'));
    });

    test('error 与堆栈同样经脱敏', () {
      final logger = AppLogger();

      logger.e(
        'T',
        'failed',
        error: StateError('token=secret-value'),
        stackTrace: StackTrace.fromString(
          '#0 f (f.dart:1) url=https://x/api?code=oauth-secret',
        ),
      );

      final entry = logger.entries.single;
      expect(entry.error, isNot(contains('secret-value')));
      expect(entry.stackTrace, isNot(contains('oauth-secret')));
    });
  });

  // 移植自 PR #369（moranfanhua）的 _disposed 守卫。
  group('dispose 后的异步收尾', () {
    test('dispose 后仍有日志写入不抛断言错误', () {
      final logger = AppLogger();
      logger.dispose();

      // ChangeNotifier 在 dispose 后被 notifyListeners 会抛断言错误。
      // dispose 是异步收尾，期间到达的日志必须静默丢弃而非崩溃——
      // 否则 App 退出阶段的日志会反过来把退出流程打断。
      expect(() => logger.e('T', 'after dispose'), returnsNormally);
      // 内存缓冲仍记录，只是不再通知监听者（此时也无监听者可通知）。
      expect(logger.entries, hasLength(1));
      // clear 同样走通知路径。
      expect(logger.clear, returnsNormally);
    });

    test('dispose 后关闭 sink 不抛断言错误', () async {
      final logger = AppLogger();
      logger.dispose();

      await expectLater(logger.disableFileSink(), completes);
    });
  });
}
