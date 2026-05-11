import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WidgetUpdateService {
  static const _channel = MethodChannel('bugaoshan/update');

  Future<void> updateWidgetData() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      debugPrint('WidgetUpdate: starting update...');
      await _channel.invokeMethod('updateWidget');
      debugPrint('WidgetUpdate: completed successfully');
    } catch (e, stack) {
      debugPrint('WidgetUpdate: FAILED: $e');
      debugPrint('WidgetUpdate: stack: $stack');
    }
  }

  Future<bool> pinWidget(String size) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('pinWidget', {
        'size': size,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetUpdate: pinWidget FAILED: $e');
      return false;
    }
  }
}
