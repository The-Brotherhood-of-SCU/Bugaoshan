import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bugaoshan/app.dart';
import 'package:bugaoshan/injection/injector.dart';

void main() async {
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
  runApp(MyApp());
}
