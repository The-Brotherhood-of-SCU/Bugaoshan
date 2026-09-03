import 'package:bugaoshan/utils/zhhq_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zhhq AES decrypt matches known response', () {
    // 之前 Node 实测可解密的真实响应密文（getProjectByAreaId 等返回）
    const cipher =
        'fAZ73PH/c9gO1nM2qTr7xZGgvRqxeVfUYn2+rERPaYrDnuCp9BlvIzGInI3QrY2AqBl9YasUe0NuFSwRA2+GzDXMvnzpFU5N/SMl9CoagH4=';
    final decrypted = ZhhqCrypto.decrypt(cipher);
    expect(decrypted, isNotEmpty);
    // 前几个字符应指向 JSON 结构（data 或 errorCode）
    expect(decrypted.startsWith('{'), isTrue);
  });

  test('zhhq AES roundtrip', () {
    const plain = '{"hello":"world"}';
    final encrypted = ZhhqCrypto.encrypt(plain);
    final decrypted = ZhhqCrypto.decrypt(encrypted);
    expect(decrypted, plain);
  });

  test('zhhq AES with custom key/iv (token encryption)', () {
    // token 加密用 key=clientSecret, iv=clientId
    const plain = '{"tokenKey":"abc"}';
    final encrypted = ZhhqCrypto.encrypt(
      plain,
      key: ZhhqCrypto.clientSecret,
      iv: ZhhqCrypto.clientId,
    );
    final decrypted = ZhhqCrypto.decrypt(
      encrypted,
      key: ZhhqCrypto.clientSecret,
      iv: ZhhqCrypto.clientId,
    );
    expect(decrypted, plain);
  });
}
