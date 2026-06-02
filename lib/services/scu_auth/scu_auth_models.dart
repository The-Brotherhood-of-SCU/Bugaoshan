/// 教务系统 base URL（该服务器不支持 HTTPS）
const kZhjwBase = 'http://zhjw.scu.edu.cn';

class CaptchaResult {
  final String code;
  final String captchaBase64;
  const CaptchaResult({required this.code, required this.captchaBase64});
}

class ScuLoginException implements Exception {
  final String message;
  final bool sessionExpired;
  const ScuLoginException(this.message, {this.sessionExpired = false});
  @override
  String toString() => message;
}
