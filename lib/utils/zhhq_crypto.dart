import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;

/// 智慧后勤（zhhq）平台的 AES 加解密工具。
///
/// zhhq 前端（webpack 模块 7b7e）使用 AES-128-CBC + PKCS7：
/// - 默认 key/iv：`1974051005060708`（响应体解密）
/// - token 加密：key = clientSecret、iv = clientId（均可覆盖默认值）
///
/// 已通过真实抓包验证：解密响应与前端 `s`（encrypt）/`l`（decrypt）一致。
class ZhhqCrypto {
  ZhhqCrypto._();

  /// 响应体解密默认 key/iv。
  static const String _responseKey = '1974051005060708';
  static const String _responseIv = '1974051005060708';

  /// 智慧后勤客户端固定配置（来自前端 webpack 模块 83d6，属公开前端常量）。
  ///
  /// ⚠️ 尽管命名为 `clientSecret`，它**不是服务端机密**——和响应加解密
  /// 默认 key/iv 一样，任何能打开 zhhq 前端页面的人都能从 JS 里提取，
  /// 其作用只是让客户端请求通过服务端的签名/参数校验。
  /// 请勿将其当作凭据对待（不要轮换、不要放入 SecureStorage、不要在日志
  /// 中脱敏），它是与前端行为精确一致的固定常量。
  static const String clientId = 'web201911chengdu';
  static const String clientSecret = 'bf8ec0449942e7f4';

  /// 用指定 key/iv 做 AES-128-CBC(PKCS7) 加密，返回 base64 密文。
  ///
  /// 与前端 `s(t, n, e)` 行为一致：`[key]` 覆盖默认 key、`[iv]` 覆盖默认 iv。
  static String encrypt(String plaintext, {String? key, String? iv}) {
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key.fromUtf8(key ?? _responseKey), mode: enc.AESMode.cbc),
    );
    return encrypter
        .encrypt(plaintext, iv: enc.IV.fromUtf8(iv ?? _responseIv))
        .base64;
  }

  /// 用指定 key/iv 解密 base64 密文，返回 UTF8 明文。
  ///
  /// 与前端 `l(t, n, e)` 行为一致：`[key]` 覆盖默认 key、`[iv]` 覆盖默认 iv。
  static String decrypt(String ciphertextBase64, {String? key, String? iv}) {
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key.fromUtf8(key ?? _responseKey), mode: enc.AESMode.cbc),
    );
    return encrypter.decrypt(
      enc.Encrypted.fromBase64(ciphertextBase64),
      iv: enc.IV.fromUtf8(iv ?? _responseIv),
    );
  }
}

/// 解析 zhhq 响应：解密后转为 JSON Map。
Map<String, dynamic>? zhhqDecodeResponse(String body) {
  try {
    final decrypted = ZhhqCrypto.decrypt(body);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
