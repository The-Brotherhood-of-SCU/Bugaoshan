import 'package:flutter_secure_storage_ohos/flutter_secure_storage_ohos.dart';

/// 直接使用插件提供的鸿蒙接口，不修改第三方包的 options 或构造参数。
class SecureStorageProvider {
  const SecureStorageProvider._();

  static const _instance = FlutterSecureStorage();

  static FlutterSecureStorage get instance => _instance;
}
