import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bugaoshan/utils/json_utils.dart';

import 'native_bridge.dart';

bool _initialized = false;

/// 在 DI 和数据库初始化之前，把 sqflite 的平台调用接到原生桥。
Future<void> initializeArkWebSupport() async {
  if (_initialized || !isArkWebNativeAvailable) return;

  final info = await invokeArkWeb(
    'bridge.info',
  ).timeout(const Duration(seconds: 10));
  if (info is! Map || safeInt(info['version']) != 1) {
    throw StateError('ArkWeb native bridge protocol version 1 is required.');
  }
  final capabilities = info['capabilities'];
  if (capabilities is! List ||
      !capabilities.contains('database') ||
      !capabilities.contains('http')) {
    throw StateError('ArkWeb native bridge must provide database and HTTP.');
  }

  final channel = MethodChannel(
    'com.tekartik.sqflite',
    const StandardMethodCodec(),
    registrar,
  );
  channel.setMethodCallHandler((call) async {
    try {
      return await invokeArkWeb('database.invoke', {
        'method': call.method,
        'arguments': call.arguments,
      });
    } on ArkWebNativeException catch (error) {
      // sqflite 会把 sqlite_error 转为 DatabaseException，保留已有错误处理。
      throw PlatformException(
        code: error.code,
        message: error.message,
        details: error.details,
      );
    }
  });
  // 复用全局 registrar，保留其他 Web 插件的消息处理。
  registrar.registerMessageHandler();
  SqflitePlugin.registerWith();
  _initialized = true;
}
