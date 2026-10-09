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
}
