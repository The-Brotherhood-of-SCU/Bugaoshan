import 'dart:convert';
import 'package:dart_sm/dart_sm.dart';

/// SM2 加密工具类（C1C2C3 模式）
class SM2Crypto {
  /// 将 base64 编码的公钥加密数据，返回 base64 编码的 04||C1C2C3 密文
  /// [plaintext] 明文字符串
  /// [publicKeyBase64] 服务端返回的 base64 编码公钥
  static String encryptWithBase64Key(String plaintext, String publicKeyBase64) {
    final pubKeyBytes = base64.decode(publicKeyBase64);
    // dart_sm 的 decodePointHex 需要完整的 04||x||y（130 hex chars）
    // 如果没有 04 前缀则补上
    final allBytes = pubKeyBytes[0] == 0x04
        ? pubKeyBytes
        : [0x04, ...pubKeyBytes];
    final pubKeyHex = allBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // dart_sm SM2.encrypt 默认 C1C3C2，指定 C1C2C3
    final cipherHex = SM2.encrypt(plaintext, pubKeyHex, cipherMode: C1C2C3);

    // dart_sm 输出: C1(128hex, 无04) + C2 + C3
    // Python 期望: 04 || C1 || C2 || C3（base64）
    final cipherBytes = [0x04, ..._hexToBytes(cipherHex)];
    return base64.encode(cipherBytes);
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
