import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:sqflite/sqflite.dart';
import 'package:system_theme/system_theme.dart';

import 'package:bugaoshan/utils/json_utils.dart';

import 'native_bridge.dart';
import 'viewport_web.dart';

bool _initialized = false;

/// 在 DI 初始化之前接入原生数据库，并适配 ArkWeb 的平台插件行为。
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
    webPluginRegistrar,
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
  final themeChannel = MethodChannel(
    'system_theme',
    const StandardMethodCodec(),
    webPluginRegistrar,
  );
  themeChannel.setMethodCallHandler((call) async {
    if (call.method == SystemTheme.getSystemAccentColorMethodName) {
      // system_theme_web 的 CSS 取色会抛出 Unknown color format。
      // 返回 null 表示无系统色，插件保留 fallbackColor；同时覆盖首次读取
      // accentColor 时自动触发的 load()，避免未等待的异步异常。
      return null;
    }
    throw MissingPluginException(
      'Unsupported system_theme method: ${call.method}',
    );
  });
  // 复用全局 Web 插件注册器，保留其他插件的消息处理。
  webPluginRegistrar.registerMessageHandler();
  SqflitePlugin.registerWith();
  if (capabilities.contains('viewport')) {
    await initializeArkWebViewport();
  }
  _initialized = true;
}
