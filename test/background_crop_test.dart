import 'dart:math';

import 'package:bugaoshan/models/background_crop.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppConfigProvider 裁剪参数持久化', () {
    test('写入后新实例可读回，清空后回到 cover 行为', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      expect(provider.backgroundImageCrop.value, isNull);

      const crop = BackgroundCropParams(focusX: 0.4, focusY: 0.6, zoom: 1.5);
      provider.backgroundImageCrop.value = crop;
      expect(preferences.getString('backgroundImageCrop'), crop.encode());

      // 模拟重启：新实例从同一 SharedPreferences 恢复。
      final reloaded = AppConfigProvider(preferences);
      await reloaded.init();
      expect(reloaded.backgroundImageCrop.value, crop);

      // 清空 → 移除持久化 key。
      reloaded.backgroundImageCrop.value = null;
      expect(preferences.getString('backgroundImageCrop'), isNull);
      final cleared = AppConfigProvider(preferences);
      await cleared.init();
      expect(cleared.backgroundImageCrop.value, isNull);
    });

    test('持久化数据损坏时回退为 null（cover 行为）', () async {
      SharedPreferences.setMockInitialValues({
        'backgroundImageCrop': '{broken json',
      });
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();
      expect(provider.backgroundImageCrop.value, isNull);
    });
  });

  group('BackgroundCropParams 序列化', () {
    test('encode/tryDecode 往返一致', () {
      const params = BackgroundCropParams(focusX: 0.3, focusY: 0.7, zoom: 2.5);
      final decoded = BackgroundCropParams.tryDecode(params.encode());
      expect(decoded, params);
    });

    test('null/空串/非法 JSON 返回 null', () {
      expect(BackgroundCropParams.tryDecode(null), isNull);
      expect(BackgroundCropParams.tryDecode(''), isNull);
      expect(BackgroundCropParams.tryDecode('not json'), isNull);
      expect(BackgroundCropParams.tryDecode('[1,2,3]'), isNull);
    });

    test('非法数值返回 null（缺字段/类型错误）', () {
      expect(BackgroundCropParams.tryDecode('{"focusX":0.5}'), isNull);
      expect(
        BackgroundCropParams.tryDecode(
          '{"focusX":"a","focusY":0.5,"zoom":1.5}',
        ),
        isNull,
      );
    });

    test('越界数值被收敛而不是拒绝', () {
      expect(
        BackgroundCropParams.tryDecode(
          '{"focusX":0.5,"focusY":0.5,"zoom":0.5}',
        ),
        BackgroundCropParams.cover,
      );
      final decoded = BackgroundCropParams.tryDecode(
        '{"focusX":3,"focusY":-1,"zoom":99}',
      );
      expect(decoded, isNotNull);
      expect(decoded!.focusX, 1.0);
      expect(decoded.focusY, 0.0);
      expect(decoded.zoom, BackgroundCropParams.maxZoom);
    });

    test('isCover 判定与相等性', () {
      const cover = BackgroundCropParams.cover;
      expect(cover.isCover, isTrue);
      expect(const BackgroundCropParams(zoom: 1.5).isCover, isFalse);
      expect(const BackgroundCropParams(focusX: 0.4).isCover, isFalse);
      expect(cover, const BackgroundCropParams());
      expect(cover.hashCode, const BackgroundCropParams().hashCode);
      expect(cover == cover.copyWith(zoom: 2), isFalse);
    });
  });

  group('resolveLayout 渲染数学', () {
    // 常用场景：图片与容器尺寸组合（含竖屏/横屏/同比例）。
    const imageSizes = [
      (1000.0, 2000.0), // 竖图
      (4000.0, 3000.0), // 横图
      (1000.0, 1000.0), // 方图
    ];
    const containerSizes = [
      (360.0, 700.0), // 手机竖屏
      (800.0, 500.0), // 桌面横窗
      (500.0, 500.0), // 方形
    ];

    test('默认参数等价于 BoxFit.cover 居中裁剪', () {
      for (final (iw, ih) in imageSizes) {
        for (final (cw, ch) in containerSizes) {
          final layout = BackgroundCropParams.resolveLayout(
            imageWidth: iw,
            imageHeight: ih,
            containerWidth: cw,
            containerHeight: ch,
            params: BackgroundCropParams.cover,
          );
          final coverScale = max(cw / iw, ch / ih);
          expect(layout.scaledWidth, closeTo(iw * coverScale, 1e-6));
          expect(layout.scaledHeight, closeTo(ih * coverScale, 1e-6));
          // 居中：四周超出量对称。
          expect(layout.left, closeTo((cw - layout.scaledWidth) / 2, 1e-6));
          expect(layout.top, closeTo((ch - layout.scaledHeight) / 2, 1e-6));
          // cover 语义：铺满容器。
          expect(layout.left, lessThanOrEqualTo(0));
          expect(layout.top, lessThanOrEqualTo(0));
          expect(layout.left + layout.scaledWidth, greaterThanOrEqualTo(cw));
          expect(layout.top + layout.scaledHeight, greaterThanOrEqualTo(ch));
        }
      }
    });

    test('zoom >= 1 时图片始终铺满容器（任意焦点）', () {
      for (final (iw, ih) in imageSizes) {
        for (final (cw, ch) in containerSizes) {
          for (final zoom in [1.0, 1.3, 2.0, 5.0]) {
            for (final fx in [0.0, 0.25, 0.5, 0.9, 1.0]) {
              for (final fy in [0.0, 0.5, 1.0]) {
                final layout = BackgroundCropParams.resolveLayout(
                  imageWidth: iw,
                  imageHeight: ih,
                  containerWidth: cw,
                  containerHeight: ch,
                  params: BackgroundCropParams(
                    focusX: fx,
                    focusY: fy,
                    zoom: zoom,
                  ),
                );
                expect(
                  layout.scaledWidth,
                  greaterThanOrEqualTo(cw - 1e-6),
                  reason: 'w=$iw h=$ih cw=$cw ch=$ch zoom=$zoom fx=$fx',
                );
                expect(
                  layout.scaledHeight,
                  greaterThanOrEqualTo(ch - 1e-6),
                  reason: 'w=$iw h=$ih cw=$cw ch=$ch zoom=$zoom fy=$fy',
                );
                expect(layout.left, lessThanOrEqualTo(1e-6));
                expect(layout.top, lessThanOrEqualTo(1e-6));
                expect(
                  layout.left + layout.scaledWidth,
                  greaterThanOrEqualTo(cw - 1e-6),
                );
                expect(
                  layout.top + layout.scaledHeight,
                  greaterThanOrEqualTo(ch - 1e-6),
                );
              }
            }
          }
        }
      }
    });

    test('zoom 放大图片且保持纵横比', () {
      const params = BackgroundCropParams(zoom: 2.0);
      final base = BackgroundCropParams.resolveLayout(
        imageWidth: 1000,
        imageHeight: 2000,
        containerWidth: 360,
        containerHeight: 700,
        params: BackgroundCropParams.cover,
      );
      final zoomed = BackgroundCropParams.resolveLayout(
        imageWidth: 1000,
        imageHeight: 2000,
        containerWidth: 360,
        containerHeight: 700,
        params: params,
      );
      expect(zoomed.scaledWidth, closeTo(base.scaledWidth * 2, 1e-6));
      expect(zoomed.scaledHeight, closeTo(base.scaledHeight * 2, 1e-6));
      expect(
        zoomed.scaledWidth / zoomed.scaledHeight,
        closeTo(base.scaledWidth / base.scaledHeight, 1e-6),
      );
    });

    test('容器中心始终映射到收敛后的焦点', () {
      // 不变量：图片缩放坐标系中，容器中心点的归一化坐标 == clampFocus(焦点)。
      // 由此推论：焦点可达（未被收敛）时，目标图片坐标显示在容器中心。
      const zoom = 2.0;
      for (final requested in const [
        Offset(1, 1),
        Offset(0.6, 0.4),
        Offset(0, 0),
      ]) {
        final clamped = BackgroundCropParams.clampFocus(
          requested.dx,
          requested.dy,
          imageWidth: 1000,
          imageHeight: 2000,
          containerWidth: 360,
          containerHeight: 700,
          zoom: zoom,
        );
        final layout = BackgroundCropParams.resolveLayout(
          imageWidth: 1000,
          imageHeight: 2000,
          containerWidth: 360,
          containerHeight: 700,
          params: BackgroundCropParams(
            focusX: requested.dx,
            focusY: requested.dy,
            zoom: zoom,
          ),
        );
        final centerX = (360 / 2 - layout.left) / layout.scaledWidth;
        final centerY = (700 / 2 - layout.top) / layout.scaledHeight;
        expect(
          centerX,
          closeTo(clamped.dx, 1e-6),
          reason: 'requested=$requested',
        );
        expect(
          centerY,
          closeTo(clamped.dy, 1e-6),
          reason: 'requested=$requested',
        );
      }

      // zoom=2 时 (0.6, 0.4) 可达，应原样出现在容器中心。
      final layout = BackgroundCropParams.resolveLayout(
        imageWidth: 1000,
        imageHeight: 2000,
        containerWidth: 360,
        containerHeight: 700,
        params: const BackgroundCropParams(focusX: 0.6, focusY: 0.4, zoom: 2),
      );
      expect((360 / 2 - layout.left) / layout.scaledWidth, closeTo(0.6, 1e-6));
      expect((700 / 2 - layout.top) / layout.scaledHeight, closeTo(0.4, 1e-6));
    });

    test('布局对象相等性', () {
      const args = (
        imageWidth: 100.0,
        imageHeight: 200.0,
        containerWidth: 50.0,
        containerHeight: 100.0,
      );
      final a = BackgroundCropParams.resolveLayout(
        imageWidth: args.imageWidth,
        imageHeight: args.imageHeight,
        containerWidth: args.containerWidth,
        containerHeight: args.containerHeight,
        params: BackgroundCropParams.cover,
      );
      final b = BackgroundCropParams.resolveLayout(
        imageWidth: args.imageWidth,
        imageHeight: args.imageHeight,
        containerWidth: args.containerWidth,
        containerHeight: args.containerHeight,
        params: BackgroundCropParams.cover,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('clampFocus 收敛', () {
    test('越界焦点收敛后图片仍铺满容器', () {
      const cases = [
        Offset(0, 0),
        Offset(1, 1),
        Offset(-5, 3),
        Offset(0.5, 0.5),
      ];
      for (final focus in cases) {
        final clamped = BackgroundCropParams.clampFocus(
          focus.dx,
          focus.dy,
          imageWidth: 1000,
          imageHeight: 2000,
          containerWidth: 360,
          containerHeight: 700,
          zoom: 1.5,
        );
        final layout = BackgroundCropParams.resolveLayout(
          imageWidth: 1000,
          imageHeight: 2000,
          containerWidth: 360,
          containerHeight: 700,
          params: BackgroundCropParams(
            focusX: clamped.dx,
            focusY: clamped.dy,
            zoom: 1.5,
          ),
        );
        expect(layout.left, lessThanOrEqualTo(1e-6));
        expect(layout.top, lessThanOrEqualTo(1e-6));
        expect(
          layout.left + layout.scaledWidth,
          greaterThanOrEqualTo(360 - 1e-6),
        );
        expect(
          layout.top + layout.scaledHeight,
          greaterThanOrEqualTo(700 - 1e-6),
        );
      }
    });

    test('缩放不足以产生平移余量时焦点回到中心', () {
      // 方图 + 方容器：cover 时两方向均无余量，焦点应恒为中心。
      final clamped = BackgroundCropParams.clampFocus(
        0.1,
        0.9,
        imageWidth: 1000,
        imageHeight: 1000,
        containerWidth: 500,
        containerHeight: 500,
        zoom: 1.0,
      );
      expect(clamped, const Offset(0.5, 0.5));
    });

    test('clamp 是幂等的', () {
      final first = BackgroundCropParams.clampFocus(
        0.0,
        0.0,
        imageWidth: 1000,
        imageHeight: 2000,
        containerWidth: 360,
        containerHeight: 700,
        zoom: 2.0,
      );
      final second = BackgroundCropParams.clampFocus(
        first.dx,
        first.dy,
        imageWidth: 1000,
        imageHeight: 2000,
        containerWidth: 360,
        containerHeight: 700,
        zoom: 2.0,
      );
      expect(second, first);
    });
  });
}
