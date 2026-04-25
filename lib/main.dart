import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/app.dart';
import 'package:bugaoshan/injection/injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    DartPluginRegistrant.ensureInitialized();
  }
  configureDependencies();
  await ensureBasicDependencies();
  runApp(MyApp());
}
