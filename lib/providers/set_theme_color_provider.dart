import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

enum ExtractColorResult { noBackgroundImage, success, failure }

class SetThemeColorProvider {
  final AppConfigProvider _appConfigProvider;

  SetThemeColorProvider(this._appConfigProvider);

  ExtractColorResult? _lastExtractResult;
  Color? _extractedColor;

  ExtractColorResult? get lastExtractResult => _lastExtractResult;
  Color? get extractedColor => _extractedColor;

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

    final pixels = <int>[];
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      _lastExtractResult = ExtractColorResult.failure;
      return ExtractColorResult.failure;
    }

    for (int i = 0; i < byteData.lengthInBytes; i += 4) {
      final r = byteData.getUint8(i);
      final g = byteData.getUint8(i + 1);
      final b = byteData.getUint8(i + 2);
      final a = byteData.getUint8(i + 3);
      if (a > 128) {
        pixels.add((r << 16) | (g << 8) | b);
      }
    }

    if (pixels.isEmpty) {
      _lastExtractResult = ExtractColorResult.failure;
      return ExtractColorResult.failure;
    }

    final colorCounts = <int, int>{};
    for (final px in pixels) {
      final quantized = px & 0xFFF8F8F8;
      colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
    }

    final dominantColorValue = colorCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    _extractedColor = Color(dominantColorValue | 0xFF000000);
    _lastExtractResult = ExtractColorResult.success;
    return ExtractColorResult.success;
  }
}
