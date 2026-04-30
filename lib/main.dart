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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    DartPluginRegistrant.ensureInitialized();
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
  configureDependencies();
  await ensureBasicDependencies();

  // 桌面端记住窗口位置和大小，下次启动时恢复
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await WindowStateService.create(getIt<SharedPreferences>());
  }

  runApp(MyApp());
}
