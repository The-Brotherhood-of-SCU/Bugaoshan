import 'dart:convert';

import 'package:bugaoshan/models/background_image_crop.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists and reloads background image crop', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final provider = AppConfigProvider(prefs);
    await provider.init();

    const crop = BackgroundImageCrop(scale: 2.0, focusX: -0.25, focusY: 0.5);
    provider.backgroundImageCrop.value = crop;

    // 写入 should be persisted as json.
    final raw = prefs.getString('backgroundImageCrop');
    expect(raw, isNotNull);
    expect(BackgroundImageCrop.fromJson(jsonDecode(raw!) as Map<String, dynamic>),
        crop);

    // Reload from a fresh provider instance.
    final provider2 = AppConfigProvider(prefs);
    await provider2.init();
    expect(provider2.backgroundImageCrop.value, crop);
  });

  test('no crop stored → stays null (backward compatible)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final provider = AppConfigProvider(prefs);
    await provider.init();

    expect(provider.backgroundImageCrop.value, isNull);
    expect(prefs.containsKey('backgroundImageCrop'), isFalse);
  });

  test('removing background image clears crop too', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final provider = AppConfigProvider(prefs);
    await provider.init();

    provider.backgroundImagePath.value = '/tmp/fake_bg.png';
    provider.backgroundImageCrop.value =
        const BackgroundImageCrop(scale: 1.5, focusX: 0.2);
    expect(prefs.containsKey('backgroundImageCrop'), isTrue);

    provider.backgroundImagePath.value = null;
    expect(provider.backgroundImageCrop.value, isNull);
    expect(prefs.containsKey('backgroundImageCrop'), isFalse);
  });

  test('corrupt crop json is ignored gracefully', () async {
    SharedPreferences.setMockInitialValues({
      'backgroundImageCrop': 'not-json',
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = AppConfigProvider(prefs);
    await provider.init();
    expect(provider.backgroundImageCrop.value, isNull);
  });
}
