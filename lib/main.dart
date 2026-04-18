import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/app.dart';
import 'package:bugaoshan/injection/injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    DartPluginRegistrant.ensureInitialized();
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
  }
  configureDependencies();
  await ensureBasicDependencies();
  runApp(MyApp());
}
