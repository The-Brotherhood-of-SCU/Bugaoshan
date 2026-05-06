import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SecureStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String? value});

  Future<void> delete({required String key});
}

/// 提供跨平台存储实例，统一管理登录凭据。
class SecureStorageProvider {
  const SecureStorageProvider._();

  static final SecureStorage _instance = _isHarmony
      ? _SharedPreferencesSecureStorage()
      : const _FlutterSecureStorageAdapter();

  static SecureStorage get instance => _instance;

  static bool get _isHarmony {
    if (kIsWeb) return false;
    return defaultTargetPlatform.toString() == 'TargetPlatform.ohos';
  }
}

class _FlutterSecureStorageAdapter implements SecureStorage {
  const _FlutterSecureStorageAdapter();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String? value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}

class _SharedPreferencesSecureStorage implements SecureStorage {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read({required String key}) async {
    return (await _prefs).getString(key);
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) return delete(key: key);
    await (await _prefs).setString(key, value);
  }

  @override
  Future<void> delete({required String key}) async {
    await (await _prefs).remove(key);
  }
}
