import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads and persists widget appearance preferences', () async {
    SharedPreferences.setMockInitialValues({
      'widget_color_style': WidgetColorStyle.monochrome.index,
      'widget_density': WidgetDensity.compact.index,
    });
    final preferences = await SharedPreferences.getInstance();
    final provider = AppConfigProvider(preferences);
    await provider.init();

    expect(provider.widgetColorStyle.value, WidgetColorStyle.monochrome);
    expect(provider.widgetDensity.value, WidgetDensity.compact);

    provider.widgetColorStyle.value = WidgetColorStyle.colorful;
    provider.widgetDensity.value = WidgetDensity.standard;

    expect(
      preferences.getInt('widget_color_style'),
      WidgetColorStyle.colorful.index,
    );
    expect(preferences.getInt('widget_density'), WidgetDensity.standard.index);
  });
}
