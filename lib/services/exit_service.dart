import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

class ExitService {
  /// 统一退出应用
  /// 桌面端使用 windowManager.destroy() 正确关闭窗口
  /// 移动端使用 exit(0) 直接退出
  Future<void> exitApp() async {
    //make sure changes is saved
    await Future.delayed(Duration(milliseconds: 300));
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.destroy();
    } else {
      exit(0);
    }
  }
}
