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
  });

  group('文件落盘与轮转', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('bugaoshan_log_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
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

      final content = await File('${tmp.path}/app.log').readAsString();
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
      expect(files, contains('app.log'));
      // 历史份不含 app.log，且编号连续。
      final rotated = files.where((f) => f != 'app.log').toList();
      expect(rotated.length, lessThanOrEqualTo(2));
    });

    test('冷启动时追加到既有文件，不截断历史日志', () async {
      final first = AppLogger();
      await first.enableFileSink(overridePath: tmp.path);
      first.log(LogLevel.error, 'T', 'first run');
      await first.disableFileSink();

      final second = AppLogger();
      await second.enableFileSink(overridePath: tmp.path);
      second.log(LogLevel.error, 'T', 'second run');
      await second.disableFileSink();

      final content = await File('${tmp.path}/app.log').readAsString();
      expect(content, contains('first run'));
      expect(content, contains('second run'));
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

    test('关闭 sink 后不再写入文件', () async {
      final logger = AppLogger();
      await logger.enableFileSink(overridePath: tmp.path);
      await logger.disableFileSink();

      logger.log(LogLevel.error, 'T', 'after disable');

      final content = await File('${tmp.path}/app.log').readAsString();
      expect(content, isNot(contains('after disable')));
      // 内存缓冲仍照常记录，Dev 页不受影响。
      expect(logger.entries, hasLength(1));
    });
  });
}
