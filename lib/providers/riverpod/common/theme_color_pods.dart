import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/providers/set_theme_color_provider.dart';

part 'theme_color_pods.g.dart';

class ThemeColorState {
  final ExtractColorResult? lastExtractResult;
  final Color? extractedColor;

  const ThemeColorState({
    this.lastExtractResult,
    this.extractedColor,
  });
}

@Riverpod(keepAlive: true)
class ThemeColorNotifier extends _$ThemeColorNotifier {
  @override
  ThemeColorState build() {
    return const ThemeColorState();
  }

  SetThemeColorProvider _getProvider() {
    return SetThemeColorProvider(
      getBackgroundImagePath: () => ref.read(backgroundImagePathSettingProvider),
      getThemeColorMode: () => ref.read(themeColorModeSettingProvider),
      getThemeColor: () => ref.read(themeColorSettingProvider),
    );
  }

  Future<Color> getSystemAccentColor() async {
    return _getProvider().getSystemAccentColor();
  }

  Future<ThemeColorPreviewResult> previewSystemColor() async {
    return _getProvider().previewSystemColor();
  }

  Future<ThemeColorPreviewResult> previewBackgroundImageColor() async {
    final provider = _getProvider();
    final result = await provider.previewBackgroundImageColor();
    state = ThemeColorState(
      lastExtractResult: provider.lastExtractResult,
      extractedColor: provider.extractedColor,
    );
    return result;
  }

  Future<ExtractColorResult> extractColorFromBackgroundImage() async {
    final provider = _getProvider();
    final result = await provider.extractColorFromBackgroundImage();
    state = ThemeColorState(
      lastExtractResult: provider.lastExtractResult,
      extractedColor: provider.extractedColor,
    );
    return result;
  }
}
