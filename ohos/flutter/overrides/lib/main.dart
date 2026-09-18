import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/app.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/ohos_debug_diagnostics.dart';
import 'package:bugaoshan/utils/ohos_startup_error.dart';

Future<void> main() async {
  final diagnostics = kDebugMode ? OhosDebugDiagnostics() : null;
  diagnostics?.install();
  try {
    diagnostics?.mark('initializing-dependencies');
    await _initializeApp();
    diagnostics?.mark('dependencies-ready');
    runApp(MyApp());
    diagnostics?.mark('runApp-called');
  } catch (error, stackTrace) {
    final errorMessage = formatOhosStartupError(error, stackTrace);
    if (diagnostics != null) {
      diagnostics.report('startup', error, stackTrace);
    } else {
      debugPrint('Startup error: $errorMessage');
    }
    runApp(_StartupErrorApp(errorMessage: errorMessage));
  }
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  configureDependencies();
  await ensureBasicDependencies();

  // 启动时不再在 main 进行图片解码或等待；预加载交由 app 层在 post-frame 时处理，以避免重复加载与启动阻塞。
}

class _StartupErrorApp extends StatelessWidget {
  final String? errorMessage;
  const _StartupErrorApp({this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bugaoshan 启动失败',
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(1.5),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    errorMessage ?? '',
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await getIt<SharedPreferences>().clear();
                    },
                    child: const Text('Clear Shared Preferences'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
