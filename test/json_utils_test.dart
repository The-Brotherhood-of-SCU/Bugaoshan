import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/utils/json_utils.dart';

void main() {
  group('safeDouble', () {
    test('num 直接转换', () {
      expect(safeDouble(3), 3.0);
      expect(safeDouble(3.7), 3.7);
      expect(safeDouble(-1.5), -1.5);
    });

    test('数字字符串解析（含首尾空白）', () {
      expect(safeDouble('2.5'), 2.5);
      expect(safeDouble(' 2.5 '), 2.5);
      expect(safeDouble('1e3'), 1000.0);
    });

    test('脏数据回退默认值而非抛异常', () {
      expect(safeDouble(null), 0.0);
      expect(safeDouble('abc'), 0.0);
      expect(safeDouble(''), 0.0);
      expect(safeDouble(true), 0.0);
      expect(safeDouble([1]), 0.0);
    });

    test('自定义 fallback', () {
      expect(safeDouble(null, fallback: 9.9), 9.9);
      expect(safeDouble('x', fallback: 9.9), 9.9);
    });
  });

  group('safeInt', () {
    test('int 原样返回', () {
      expect(safeInt(5), 5);
      expect(safeInt(-5), -5);
    });

    test('num 截断（toInt 语义）', () {
      expect(safeInt(3.9), 3);
      expect(safeInt(-3.9), -3);
    });

    test('整数字符串解析（含首尾空白）', () {
      expect(safeInt('42'), 42);
      expect(safeInt(' 7 '), 7);
      expect(safeInt('-3'), -3);
    });

    test('脏数据回退默认值而非抛异常', () {
      expect(safeInt(null), 0);
      expect(safeInt('abc'), 0);
      // 小数字符串不是合法 int，回退 fallback（与 num 3.9 截断为 3 不同）。
      expect(safeInt('3.5'), 0);
      expect(safeInt(true), 0);
    });

    test('自定义 fallback', () {
      expect(safeInt(null, fallback: 12), 12);
      expect(safeInt('3.5', fallback: 12), 12);
    });
  });

  group('safeString', () {
    test('null 回退，其余 toString()', () {
      expect(safeString(null), '');
      expect(safeString('x'), 'x');
      expect(safeString(5), '5');
      expect(safeString(3.0), '3.0');
      expect(safeString(null, fallback: 'n/a'), 'n/a');
    });
  });

  group('safeBool', () {
    test('bool 原样返回', () {
      expect(safeBool(true), isTrue);
      expect(safeBool(false), isFalse);
    });

    test('数字按非零为 true 识别', () {
      expect(safeBool(1), isTrue);
      expect(safeBool(0), isFalse);
      expect(safeBool(2), isTrue);
      expect(safeBool(0.0), isFalse);
    });

    test('字符串识别（大小写与首尾空白不敏感）', () {
      expect(safeBool('true'), isTrue);
      expect(safeBool('TRUE'), isTrue);
      expect(safeBool(' true '), isTrue);
      expect(safeBool('1'), isTrue);
      expect(safeBool('false'), isFalse);
      expect(safeBool('0'), isFalse);
      expect(safeBool(' False '), isFalse);
    });

    test('脏数据回退默认值而非抛异常', () {
      expect(safeBool(null), isFalse);
      expect(safeBool('yes'), isFalse);
      expect(safeBool(''), isFalse);
      expect(safeBool(null, fallback: true), isTrue);
      expect(safeBool('yes', fallback: true), isTrue);
    });
  });
}
