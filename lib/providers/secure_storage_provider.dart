import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 提供 FlutterSecureStorage 实例，统一管理安全存储
///
/// 使用方式: SecureStorageProvider.instance
class SecureStorageProvider {
  const SecureStorageProvider._();

  static const _instance = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static FlutterSecureStorage get instance => _instance;
}
