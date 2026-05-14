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

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetUpdate: isIgnoringBatteryOptimizations FAILED: $e');
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetUpdate: requestIgnoreBatteryOptimizations FAILED: $e');
      return false;
    }
  }
}
