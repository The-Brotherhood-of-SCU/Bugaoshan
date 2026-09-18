import 'package:bugaoshan/pages/auth/scu_reset_password_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchesResetPasswordPolicy 客户端密码预校验', () {
    test('满足全部要求（≥8位 + 大小写 + 数字 + 特殊字符）通过', () {
      expect(matchesResetPasswordPolicy('Abcdef1!'), isTrue);
      expect(matchesResetPasswordPolicy('Aa1!aaaa'), isTrue); // 恰好 8 位
      expect(matchesResetPasswordPolicy('Zx9#password'), isTrue); // 超过 8 位
      // 下划线按特殊字符计
      expect(matchesResetPasswordPolicy('Abcdef1_'), isTrue);
    });

    test('缺少任一类字符不通过', () {
      expect(matchesResetPasswordPolicy('abcdefg1!'), isFalse); // 缺大写
      expect(matchesResetPasswordPolicy('ABCDEFG1!'), isFalse); // 缺小写
      expect(matchesResetPasswordPolicy('Abcdefgh!'), isFalse); // 缺数字
      expect(matchesResetPasswordPolicy('Abcdefg1'), isFalse); // 缺特殊字符
    });

    test('长度不足 8 位不通过', () {
      expect(matchesResetPasswordPolicy('Ab1!'), isFalse);
      expect(matchesResetPasswordPolicy('Aa1!aaa'), isFalse); // 7 位
      expect(matchesResetPasswordPolicy(''), isFalse);
    });
  });
}
