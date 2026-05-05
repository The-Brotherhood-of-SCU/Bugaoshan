import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:os_type/os_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bugaoshan/app.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/window_state_service.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
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

      // 桌面端记住窗口位置和大小，下次启动时恢复
      if (!kIsWeb && _isDesktopPlatform) {
        await WindowStateService.create(getIt<SharedPreferences>());
      }
      runApp(MyApp());
    },
    (error, stackTrace) {
      debugPrint('Startup error: $error\n$stackTrace');
      runApp(const _StartupErrorApp());
    },
  );
}

bool get _isDesktopPlatform {
  if (kIsWeb || OS.isHarmony) return false;
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
