import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads and persists widget appearance preferences', () async {
    SharedPreferences.setMockInitialValues({
      'widget_color_style': WidgetColorStyle.monochrome.index,
      'widget_density': WidgetDensity.compact.index,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesBridge.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(widgetColorStyleSettingProvider),
      WidgetColorStyle.monochrome,
    );
    expect(
      container.read(widgetDensitySettingProvider),
      WidgetDensity.compact,
    );

    container
        .read(widgetColorStyleSettingProvider.notifier)
        .update(WidgetColorStyle.colorful);
    container
        .read(widgetDensitySettingProvider.notifier)
        .update(WidgetDensity.standard);

    expect(
      preferences.getInt('widget_color_style'),
      WidgetColorStyle.colorful.index,
    );
    expect(preferences.getInt('widget_density'), WidgetDensity.standard.index);
  });
}
