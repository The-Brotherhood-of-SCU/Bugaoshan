import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

class WidgetUpdateService {
  final AppConfigProvider _appConfig;

  static const _widgetProviders = [
    'CourseWidgetProviderSmall',
    'CourseWidgetProviderMedium',
    'CourseWidgetProviderLarge',
  ];

  WidgetUpdateService(this._appConfig);

  Future<void> updateWidgetData() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      debugPrint('WidgetUpdate: starting update...');
      await _writeThemeColor();
      await _triggerWidgetUpdate();
      debugPrint('WidgetUpdate: completed successfully');
    } catch (e, stack) {
      debugPrint('WidgetUpdate: FAILED: $e');
      debugPrint('WidgetUpdate: stack: $stack');
    }
  }

  Future<void> _writeThemeColor() async {
    // Only theme color is written to SharedPreferences;
    // course data is read directly from SQLite by the native widget.
    await HomeWidget.saveWidgetData(
        'widget_theme_color', _appConfig.themeColor.value.toARGB32());
    debugPrint('WidgetUpdate: theme color saved');
  }

  Future<void> _triggerWidgetUpdate() async {
    for (final provider in _widgetProviders) {
      try {
        await HomeWidget.updateWidget(
          qualifiedAndroidName:
              'io.github.the_brotherhood_of_scu.bugaoshan.$provider',
        );
        debugPrint('WidgetUpdate: triggered $provider');
      } catch (e) {
        debugPrint('WidgetUpdate: failed to trigger $provider: $e');
      }
    }
  }
}
