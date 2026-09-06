import 'dart:io';

import 'package:bugaoshan/models/background_crop.dart';
import 'package:bugaoshan/widgets/common/background_image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 从测试环境的 asset bundle 读取真实 PNG 字节写出临时文件供 FileImage 解码。
///
/// 所有真实 IO 必须在 `tester.runAsync` 内执行：widget test 的 FakeAsync
/// zone 中 dart:io 的真实事件永远不会被处理，会直接卡死测试。
Future<File> _writeTestImage(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final bytes = (await rootBundle.load(
      'assets/icon.png',
    )).buffer.asUint8List();
    final dir = await Directory.systemTemp.createTemp('bugaoshan_bg_test');
    addTearDown(() => dir.delete(recursive: true).ignore());
    final file = File('${dir.path}/bg.png');
    await file.writeAsBytes(bytes);
    return file;
  }))!;
}

/// 预热 FileImage 的共享 ImageStreamCompleter。
///
/// widget test 的 FakeAsync zone 不会分发解码回调，直接 pump 等不到
/// onImage；用文档推荐的 precacheImage + runAsync 先完成解码，之后
/// BackgroundImageView resolve 同一 provider 时同步拿到图片尺寸。
Future<void> _warmImageCache(WidgetTester tester, File file) async {
  BuildContext? context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (inner) {
          context = inner;
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
  await tester.runAsync(() => precacheImage(FileImage(file), context!));
}

void main() {
  // assets/icon.png 为方图（2048x2048），放进 2:1 容器时 cover 后
  // 垂直方向有平移余量，可验证焦点摆放。
  const imageSize = (width: 2048.0, height: 2048.0);
  const containerSize = Size(200, 100);

  testWidgets('无裁剪参数时走 BoxFit.cover 分支（不产生 Positioned）', (tester) async {
    final file = await _writeTestImage(tester);
    await _warmImageCache(tester, file);
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: containerSize.width,
          height: containerSize.height,
          child: BackgroundImageView(path: file.path, overlayOpacity: 0.3),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('默认裁剪参数同样走 cover 分支', (tester) async {
    final file = await _writeTestImage(tester);
    await _warmImageCache(tester, file);
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: containerSize.width,
          height: containerSize.height,
          child: BackgroundImageView(
            path: file.path,
            overlayOpacity: 0.3,
            crop: BackgroundCropParams.cover,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('裁剪参数驱动 Positioned 布局，与 resolveLayout 一致', (tester) async {
    const crop = BackgroundCropParams(focusX: 1.0, focusY: 0.5, zoom: 1.5);
    final file = await _writeTestImage(tester);
    await _warmImageCache(tester, file);
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: containerSize.width,
          height: containerSize.height,
          child: BackgroundImageView(
            path: file.path,
            overlayOpacity: 0.3,
            crop: crop,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final expected = BackgroundCropParams.resolveLayout(
      imageWidth: imageSize.width,
      imageHeight: imageSize.height,
      containerWidth: containerSize.width,
      containerHeight: containerSize.height,
      params: crop,
    );
    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, closeTo(expected.left, 1e-6));
    expect(positioned.top, closeTo(expected.top, 1e-6));
    expect(positioned.width, closeTo(expected.scaledWidth, 1e-6));
    expect(positioned.height, closeTo(expected.scaledHeight, 1e-6));
  });

  testWidgets('图片文件不存在时保持空显示不抛错', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: containerSize.width,
          height: containerSize.height,
          child: BackgroundImageView(
            path: '${Directory.systemTemp.path}/not_exists_bg.png',
            overlayOpacity: 0.3,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Image), findsNothing);
  });
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));
