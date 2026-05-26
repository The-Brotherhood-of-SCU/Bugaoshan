import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bugaoshan/app.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/window_state_service.dart';
import 'package:system_theme/system_theme.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

Future<void> main() async {
  try {
    await _initializeApp();
    runApp(MyApp());
  } catch (error, stackTrace) {
    debugPrint('Startup error: $error\n$stackTrace');
    runApp(const _StartupErrorApp());
  }
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    DartPluginRegistrant.ensureInitialized();
    if (_isDesktopPlatform) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
  configureDependencies();
  await ensureBasicDependencies();

  // 清理下载的安装包（首次打开或更新后）。
  getIt<UpdateService>().cleanupOldPackages();

  // 桌面端记住窗口位置和大小，下次启动时恢复
  if (!kIsWeb && _isDesktopPlatform) {
    await WindowStateService.create(getIt<SharedPreferences>());
  }

  // 获取系统主题颜色
  SystemTheme.fallbackColor = Colors.blue;
  await SystemTheme.accentColor.load();

  // 尝试在进入 runApp 前预加载背景图片，缩短首帧前的图片准备时间，减少白屏闪烁。
  try {
    final appConfig = getIt<AppConfigProvider>();
    final bgPath = appConfig.backgroundImagePath.value;
    if (bgPath != null) {
      final f = File(bgPath);
      if (await f.exists()) {
        final provider = FileImage(f);
        final stream = provider.resolve(const ImageConfiguration());
        final completer = Completer<void>();
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (_, _) {
            if (!completer.isCompleted) completer.complete();
          },
          onError: (_, _) {
            if (!completer.isCompleted) completer.complete();
          },
        );
        stream.addListener(listener);
        // 等待短时间内解码完成，避免阻塞过久
        try {
          await Future.any([
            completer.future,
            Future.delayed(const Duration(milliseconds: 300)),
          ]);
        } finally {
          stream.removeListener(listener);
        }
      }
    }
  } catch (_) {
    // ignore preload errors
  }
}

bool get _isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Bugaoshan 启动失败', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
