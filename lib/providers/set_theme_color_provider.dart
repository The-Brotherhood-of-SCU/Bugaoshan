import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:system_theme/system_theme.dart';

enum ExtractColorResult { noBackgroundImage, success, failure }

class ThemeColorPreviewResult {
  final Color? color;
  final ThemeColorMode mode;

  ThemeColorPreviewResult({this.color, required this.mode});
}

class SetThemeColorProvider {
  final AppConfigProvider _appConfigProvider;

  SetThemeColorProvider(this._appConfigProvider);

  ExtractColorResult? _lastExtractResult;
  Color? _extractedColor;

  ExtractColorResult? get lastExtractResult => _lastExtractResult;
  Color? get extractedColor => _extractedColor;

  Future<Color> getSystemAccentColor() async {
    await SystemTheme.accentColor.load();
    return SystemTheme.accentColor.accent;
  }

  Future<ThemeColorPreviewResult> previewSystemColor() async {
    final color = await getSystemAccentColor();
    return ThemeColorPreviewResult(color: color, mode: ThemeColorMode.system);
  }

  Future<ThemeColorPreviewResult> previewBackgroundImageColor() async {
    final bgPath = _appConfigProvider.backgroundImagePath.value;
    if (bgPath == null) {
      _lastExtractResult = ExtractColorResult.noBackgroundImage;
      final previousMode = _appConfigProvider.themeColorMode.value;
      if (previousMode == ThemeColorMode.system) {
        final color = await getSystemAccentColor();
        return ThemeColorPreviewResult(
          color: color,
          mode: ThemeColorMode.system,
        );
      } else if (previousMode == ThemeColorMode.custom) {
        return ThemeColorPreviewResult(
          color: _appConfigProvider.themeColor.value,
          mode: ThemeColorMode.custom,
        );
      }
      return ThemeColorPreviewResult(
        color: _appConfigProvider.themeColor.value,
        mode: previousMode,
      );
    }

    final result = await extractColorFromBackgroundImage();
    if (result == ExtractColorResult.success && _extractedColor != null) {
      return ThemeColorPreviewResult(
        color: _extractedColor,
        mode: ThemeColorMode.backgroundImage,
      );
    }
    return ThemeColorPreviewResult(
      color: _appConfigProvider.themeColor.value,
      mode: _appConfigProvider.themeColorMode.value,
    );
  }

  Future<ExtractColorResult> extractColorFromBackgroundImage() async {
    final bgPath = _appConfigProvider.backgroundImagePath.value;
    if (bgPath == null) {
      _lastExtractResult = ExtractColorResult.noBackgroundImage;
      return ExtractColorResult.noBackgroundImage;
    }

    final file = File(bgPath);
    if (!await file.exists()) {
      _lastExtractResult = ExtractColorResult.failure;
      return ExtractColorResult.failure;
    }

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      _lastExtractResult = ExtractColorResult.failure;
      return ExtractColorResult.failure;
    }

    final width = image.width;
    final height = image.height;
    final pixelCount = width * height;
    final sampleStep = max(1, (pixelCount / 5000).ceil());

    final bytesList = byteData.buffer.asUint8List();

    final dominantColorValue = await compute(
      _computeDominantColor,
      _ColorExtractionParams(
        bytes: bytesList,
        width: width,
        height: height,
        sampleStep: sampleStep,
      ),
    );

    if (dominantColorValue == null) {
      _lastExtractResult = ExtractColorResult.failure;
      return ExtractColorResult.failure;
    }

    _extractedColor = Color(dominantColorValue | 0xFF000000);
    _lastExtractResult = ExtractColorResult.success;
    return ExtractColorResult.success;
  }
}

class _ColorExtractionParams {
  final Uint8List bytes;
  final int width;
  final int height;
  final int sampleStep;

  _ColorExtractionParams({
    required this.bytes,
    required this.width,
    required this.height,
    required this.sampleStep,
  });
}

int? _computeDominantColor(_ColorExtractionParams params) {
  final colorCounts = <int, int>{};
  final mask = 0xF8F8F8;
  final width = params.width;
  final height = params.height;
  final sampleStep = params.sampleStep;
  final bytes = params.bytes;

  for (int y = 0; y < height; y += sampleStep) {
    for (int x = 0; x < width; x += sampleStep) {
      final offset = (y * width + x) * 4;
      final a = bytes[offset + 3];
      if (a > 128) {
        final r = bytes[offset];
        final g = bytes[offset + 1];
        final b = bytes[offset + 2];
        final quantized = ((r & mask) << 16) | ((g & mask) << 8) | (b & mask);
        colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
      }
    }
  }

  if (colorCounts.isEmpty) return null;

  return colorCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
}
