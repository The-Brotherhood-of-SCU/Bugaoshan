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
    // Legacy login-keychain ACLs are tied to the previous app signature and can
    // prompt once for every saved credential after an update. Use the signed
    // app's data-protection access group instead; do not probe the legacy store
    // at startup. Existing Mac users sign in once to populate this store.
    mOptions: MacOsOptions(
      usesDataProtectionKeychain: true,
      accountName: 'io.github.thebrotherhoodofscu.bugaoshan.ios.credentials',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static FlutterSecureStorage get instance => _instance;
}
