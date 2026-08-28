import 'dart:ui';

import 'package:bugaoshan/models/background_image_crop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundImageCrop', () {
    test('centered is scale=1, focus=0', () {
      const crop = BackgroundImageCrop.centered;
      expect(crop.scale, 1.0);
      expect(crop.focusX, 0.0);
      expect(crop.focusY, 0.0);
      expect(crop.isCentered, isTrue);
    });

    test('isCentered detects non-default', () {
      expect(
        const BackgroundImageCrop(scale: 1, focusX: 0.5).isCentered,
        isFalse,
      );
      expect(
        const BackgroundImageCrop(scale: 2).isCentered,
        isFalse,
      );
    });

    test('toJson / fromJson round-trips', () {
      const crop = BackgroundImageCrop(scale: 1.5, focusX: -0.3, focusY: 0.7);
      final decoded = BackgroundImageCrop.fromJson(crop.toJson());
      expect(decoded, crop);
    });

    test('fromJson clamps out-of-range values', () {
      final crop = BackgroundImageCrop.fromJson({
        'scale': 99.0,
        'focusX': -5.0,
        'focusY': 5.0,
      });
      expect(crop.scale, 8.0);
      expect(crop.focusX, -1.0);
      expect(crop.focusY, 1.0);
    });

    test('copyWith overrides only given fields', () {
      const base = BackgroundImageCrop.centered;
      final updated = base.copyWith(scale: 2.0);
      expect(updated.scale, 2.0);
      expect(updated.focusX, 0.0);
      expect(updated.focusY, 0.0);
    });
  });

  group('computeCropRect', () {
    const container = Size(300, 400); // 3:4 portrait box
    const image = Size(600, 600); // square

    test('scale=1, focus=0 fills container (cover)', () {
      final rect = computeCropRect(
        container: container,
        image: image,
        crop: BackgroundImageCrop.centered,
      );
      // cover of square into 300x400 → 600x600 scaled to fill: width-limited
      // scale = max(300/600, 400/600) = 0.6667 → 400x400, centered.
      expect(rect.width, closeTo(400, 0.5));
      expect(rect.height, closeTo(400, 0.5));
      expect(rect.left, closeTo((300 - 400) / 2, 0.5)); // -50
      expect(rect.top, closeTo(0, 0.5));
    });

    test('scale>1 enlarges image around center', () {
      final rect = computeCropRect(
        container: container,
        image: image,
        crop: const BackgroundImageCrop(scale: 2.0),
      );
      expect(rect.width, closeTo(800, 0.5));
      expect(rect.height, closeTo(800, 0.5));
      // centered → offset = (container - size)/2 = (300-800)/2 = -250, (400-800)/2 = -200
      expect(rect.left, closeTo(-250, 0.5));
      expect(rect.top, closeTo(-200, 0.5));
    });

    test('focus shifts the visible region', () {
      final focusRight = computeCropRect(
        container: container,
        image: image,
        crop: const BackgroundImageCrop(focusX: 1.0),
      );
      final focusLeft = computeCropRect(
        container: container,
        image: image,
        crop: const BackgroundImageCrop(focusX: -1.0),
      );
      // focusX=1 → right aligned: left = (300-400)/2 - 1*(300-400)/2 = 0
      expect(focusRight.left, closeTo(0, 0.5));
      // focusX=-1 → left aligned: left = (300-400)/2 - (-1)*(300-400)/2 = -100
      expect(focusLeft.left, closeTo(-100, 0.5));
    });
  });
}
