import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/export/schedule_export_view.dart';
import 'package:bugaoshan/pages/course/export/schedule_image_export.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Future<AppConfigProvider> _initAppConfig() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final config = AppConfigProvider(prefs);
  await config.init();
  if (getIt.isRegistered<AppConfigProvider>()) {
    await getIt.unregister<AppConfigProvider>();
  }
  getIt.registerSingleton<AppConfigProvider>(config);
  return config;
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  final _channel = const MethodChannel('plugins.flutter.io/path_provider');

  @override
  Future<String?> getTemporaryPath() {
    return _channel.invokeMethod<String>('getTemporaryDirectory');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final List<MethodCall> galCalls = [];
  bool galAccessGranted = true;
  int shareCallCount = 0;
  late PathProviderPlatform originalPathProviderPlatform;

  setUpAll(() {
    originalPathProviderPlatform = PathProviderPlatform.instance;
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPathProviderPlatform;
  });

  setUp(() async {
    await getIt.reset();
    resetScheduleImageExportStateForTesting();
    galCalls.clear();
    galAccessGranted = true;
    shareCallCount = 0;

    PathProviderPlatform.instance = _TestPathProviderPlatform();
    tempDir = Directory.systemTemp.createTempSync('schedule_export_test_');

    // Mock share_plus channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (MethodCall methodCall) async {
            shareCallCount++;
            return 'success';
          },
        );

    // Mock plugins.flutter.io/path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getTemporaryDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );

    // Mock gal channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('gal'), (
          MethodCall methodCall,
        ) async {
          galCalls.add(methodCall);
          if (methodCall.method == 'requestAccess' ||
              methodCall.method == 'hasAccess') {
            return galAccessGranted;
          }
          if (methodCall.method == 'putImageBytes') {
            if (!galAccessGranted) {
              throw PlatformException(code: 'ACCESS_DENIED', message: 'Denied');
            }
            return null;
          }
          return null;
        });
  });

  tearDown(() async {
    resetScheduleImageExportStateForTesting();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('gal'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        );
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  final testCourse = Course(
    name: '离散数学',
    teacher: '李老师',
    location: '综合楼101',
    startWeek: 1,
    endWeek: 16,
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    colorValue: 0xFF2196F3,
  );

  group('resolveExportTargetWeek 6 例测试', () {
    test('1) visibleWeek=12, totalWeeks=20 -> 12', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 9, 1),
        totalWeeks: 20,
      );
      expect(resolveExportTargetWeek(config, visibleWeek: 12), equals(12));
    });

    test('2) visibleWeek=0, totalWeeks=20 -> 1', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 9, 1),
        totalWeeks: 20,
      );
      expect(resolveExportTargetWeek(config, visibleWeek: 0), equals(1));
    });

    test('3) visibleWeek=99, totalWeeks=20 -> 20', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 9, 1),
        totalWeeks: 20,
      );
      expect(resolveExportTargetWeek(config, visibleWeek: 99), equals(20));
    });

    test('4) 无 visibleWeek 且 semesterStartDate = now - 21d -> 4', () {
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 21));
      final config = ScheduleConfig(semesterStartDate: start, totalWeeks: 20);
      expect(resolveExportTargetWeek(config), equals(4));
    });

    test('5) 未开学 start = now + 30d -> 1', () {
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 30));
      final config = ScheduleConfig(semesterStartDate: start, totalWeeks: 20);
      expect(resolveExportTargetWeek(config), equals(1));
    });

    test('6) 已结束 start = now - 200d, totalWeeks=5 -> 5', () {
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 200));
      final config = ScheduleConfig(semesterStartDate: start, totalWeeks: 5);
      expect(resolveExportTargetWeek(config), equals(5));
    });
  });

  group('ScheduleExportData & courses unmodifiable', () {
    test('courses 为不可变列表，修改抛出 UnsupportedError', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 9, 1),
        totalWeeks: 20,
      );
      final data = ScheduleExportData(
        config: config,
        courses: [testCourse],
        targetWeek: 1,
      );

      expect(() => data.courses.add(testCourse), throwsUnsupportedError);
      expect(data.isValid, isTrue);
    });

    test('data.isValid 验证 courses 空与 targetWeek 越界', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 9, 1),
        totalWeeks: 20,
      );
      final emptyData = ScheduleExportData(
        config: config,
        courses: const [],
        targetWeek: 1,
      );
      expect(emptyData.isValid, isFalse);

      final outOfBoundsWeek = ScheduleExportData(
        config: config,
        courses: [testCourse],
        targetWeek: 21,
      );
      expect(outOfBoundsWeek.isValid, isFalse);

      final zeroWeek = ScheduleExportData(
        config: config,
        courses: [testCourse],
        targetWeek: 0,
      );
      expect(zeroWeek.isValid, isFalse);
    });
  });

  group('resolveEffectiveDpr 3 例', () {
    test('常规尺寸返回 targetDpr 2.0', () {
      final dpr = resolveEffectiveDpr(
        logicalWidth: 420,
        logicalHeight: 800,
        targetDpr: 2.0,
      );
      expect(dpr, equals(2.0));
    });

    test('超大尺寸降级且总像素数 <= maxPixels', () {
      const maxPixels = 8 * 1024 * 1024;
      final dpr = resolveEffectiveDpr(
        logicalWidth: 2000,
        logicalHeight: 2000,
        targetDpr: 2.0,
        maxPixels: maxPixels,
      );
      expect(dpr, lessThan(2.0));
      expect(dpr, greaterThan(1.0));
      final totalPixels = 2000 * 2000 * dpr * dpr;
      expect(totalPixels, lessThanOrEqualTo(maxPixels + 1e-6));
    });

    test('极端超大尺寸被 clamp 到不低于 1.0', () {
      final dpr = resolveEffectiveDpr(
        logicalWidth: 5000,
        logicalHeight: 5000,
        targetDpr: 2.0,
      );
      expect(dpr, equals(1.0));
    });
  });

  group('文件名命名辅助函数', () {
    test('scheduleImageBaseName 与 scheduleImageFileName', () {
      expect(scheduleImageBaseName(3), equals('课表_第3周'));
      expect(scheduleImageFileName(3), equals('课表_第3周.png'));
    });
  });

  group('showScheduleImageActionSheet', () {
    testWidgets('恰好 3 个 ListTile 且点击分别返回对应枚举', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      // 1. 点击保存到相册
      ScheduleImageAction? selectedAction;
      unawaited(
        showScheduleImageActionSheet(buildContext, l10n).then((val) {
          selectedAction = val;
        }),
      );
      await tester.pumpAndSettle();

      final listTiles = find.byType(ListTile);
      expect(listTiles, findsNWidgets(3));

      await tester.tap(find.text(l10n.saveScheduleImageToGallery));
      await tester.pumpAndSettle();
      expect(selectedAction, equals(ScheduleImageAction.saveToGallery));

      // 2. 点击分享
      unawaited(
        showScheduleImageActionSheet(buildContext, l10n).then((val) {
          selectedAction = val;
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareScheduleImage));
      await tester.pumpAndSettle();
      expect(selectedAction, equals(ScheduleImageAction.share));

      // 3. 点击取消
      unawaited(
        showScheduleImageActionSheet(buildContext, l10n).then((val) {
          selectedAction = val;
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(selectedAction, equals(ScheduleImageAction.cancel));
    });
  });

  group('MethodChannel mock: 相册与临时文件', () {
    final artifact = ScheduleImageArtifact(
      pngBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      baseName: '课表_第1周',
      pixelWidth: 840,
      pixelHeight: 1600,
      effectiveDpr: 2.0,
    );

    testWidgets('权限拒绝时返回 permissionDenied 且未调用 putImageBytes', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      galAccessGranted = false;

      final status = await saveScheduleImageToGallery(
        context: buildContext,
        l10n: l10n,
        artifact: artifact,
      );

      expect(status, equals(ScheduleImageOutputStatus.permissionDenied));
      final hasPutImageBytes = galCalls.any((c) => c.method == 'putImageBytes');
      expect(hasPutImageBytes, isFalse);
    });

    testWidgets('成功时 putImageBytes 收到的 name 不带 .png', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      galAccessGranted = true;

      final status = await saveScheduleImageToGallery(
        context: buildContext,
        l10n: l10n,
        artifact: artifact,
      );

      expect(status, equals(ScheduleImageOutputStatus.success));
      final putCall = galCalls.firstWhere((c) => c.method == 'putImageBytes');
      final name = putCall.arguments['name'] as String;
      expect(name, equals(artifact.baseName));
      expect(name.endsWith('.png'), isFalse);
    });

    testWidgets('writeScheduleImageTempFile 生成以 .png 结尾的文件且分享调用后文件仍存在', (
      tester,
    ) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.runAsync(() async {
        final file = await writeScheduleImageTempFile(artifact);
        expect(file.path.endsWith('.png'), isTrue);
        expect(file.path.contains(artifact.baseName), isTrue);
        expect(file.existsSync(), isTrue);

        final bytes = await file.readAsBytes();
        expect(bytes, equals(artifact.pngBytes));

        // 调用分享
        final shareStatus = await shareScheduleImage(
          context: buildContext,
          artifact: artifact,
        );
        expect(shareStatus, equals(ScheduleImageOutputStatus.success));
        expect(shareCallCount, equals(1));

        // 验证文件在分享后依然存在（不要删除）
        expect(file.existsSync(), isTrue);
      });
    });
  });

  group('showScheduleImageExportFlow flow 与计数 fake renderer', () {
    final validConfig = ScheduleConfig(
      semesterStartDate: DateTime(2026, 9, 1),
      totalWeeks: 20,
    );
    final validData = ScheduleExportData(
      config: validConfig,
      courses: [testCourse],
      targetWeek: 1,
    );
    final fakeArtifact = ScheduleImageArtifact(
      pngBytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      baseName: '课表_第1周',
      pixelWidth: 840,
      pixelHeight: 1600,
      effectiveDpr: 2.0,
    );

    testWidgets('先渲染后选择：选保存到系统相册时渲染 1 次、只分发 1 次', (tester) async {
      await _initAppConfig();
      int renderCallCount = 0;
      final dispatched = <(ScheduleImageAction, ScheduleImageArtifact)>[];
      Future<ScheduleImageArtifact> fakeRender(
        BuildContext context,
        ScheduleExportData data,
      ) async {
        renderCallCount++;
        return fakeArtifact;
      }

      Future<ScheduleImageOutputStatus> fakeOutput(
        BuildContext context,
        AppLocalizations l10n,
        ScheduleImageAction action,
        ScheduleImageArtifact artifact,
      ) async {
        dispatched.add((action, artifact));
        return ScheduleImageOutputStatus.success;
      }

      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      // 触发 flow
      final flowFuture = showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: fakeRender,
        output: fakeOutput,
      );
      await tester.pumpAndSettle();

      // 需求顺序：PNG 先生成成功，才出现三项动作
      expect(renderCallCount, equals(1));
      expect(find.byType(ListTile), findsNWidgets(3));

      // 点击保存到系统相册
      await tester.tap(find.text(l10n.saveScheduleImageToGallery));
      await tester.pumpAndSettle();
      await flowFuture;

      expect(renderCallCount, equals(1));
      expect(dispatched.length, equals(1));
      expect(dispatched.single.$1, equals(ScheduleImageAction.saveToGallery));
      // 两个输出动作消费的是同一个 artifact（不重新渲染）
      expect(identical(dispatched.single.$2, fakeArtifact), isTrue);
      expect(find.text(l10n.scheduleImageSavedToGallery), findsOneWidget);
    });

    testWidgets('先渲染后选择：选系统分享时渲染 1 次、只分发 1 次', (tester) async {
      await _initAppConfig();
      int renderCallCount = 0;
      final dispatched = <(ScheduleImageAction, ScheduleImageArtifact)>[];
      Future<ScheduleImageArtifact> fakeRender(
        BuildContext context,
        ScheduleExportData data,
      ) async {
        renderCallCount++;
        return fakeArtifact;
      }

      Future<ScheduleImageOutputStatus> fakeOutput(
        BuildContext context,
        AppLocalizations l10n,
        ScheduleImageAction action,
        ScheduleImageArtifact artifact,
      ) async {
        dispatched.add((action, artifact));
        return ScheduleImageOutputStatus.success;
      }

      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      final flowFuture = showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: fakeRender,
        output: fakeOutput,
      );
      await tester.pumpAndSettle();

      expect(renderCallCount, equals(1));
      expect(find.byType(ListTile), findsNWidgets(3));

      // 点击系统分享
      await tester.tap(find.text(l10n.shareScheduleImage));
      await tester.pumpAndSettle();
      await flowFuture;

      expect(renderCallCount, equals(1));
      expect(dispatched.length, equals(1));
      expect(dispatched.single.$1, equals(ScheduleImageAction.share));
      expect(identical(dispatched.single.$2, fakeArtifact), isTrue);
    });

    testWidgets('取消：PNG 已生成但不分发、不显示失败提示、且锁已释放', (tester) async {
      await _initAppConfig();
      int renderCallCount = 0;
      final dispatched = <(ScheduleImageAction, ScheduleImageArtifact)>[];
      Future<ScheduleImageArtifact> fakeRender(
        BuildContext context,
        ScheduleExportData data,
      ) async {
        renderCallCount++;
        return fakeArtifact;
      }

      Future<ScheduleImageOutputStatus> fakeOutput(
        BuildContext context,
        AppLocalizations l10n,
        ScheduleImageAction action,
        ScheduleImageArtifact artifact,
      ) async {
        dispatched.add((action, artifact));
        return ScheduleImageOutputStatus.success;
      }

      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      final flowFuture = showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: fakeRender,
        output: fakeOutput,
      );
      await tester.pumpAndSettle();

      // 需求规定的顺序：先渲染出 PNG，再让用户选择；取消即丢弃
      expect(renderCallCount, equals(1));
      expect(find.byType(ListTile), findsNWidgets(3));

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await flowFuture;

      expect(renderCallCount, equals(1));
      expect(dispatched, isEmpty);
      expect(find.byType(SnackBar), findsNothing);

      // 取消后防重入锁必须已释放：再次触发仍能进入流程并重新渲染
      final secondFlow = showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: fakeRender,
        output: fakeOutput,
      );
      await tester.pumpAndSettle();
      expect(renderCallCount, equals(2));
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await secondFlow;
    });

    testWidgets('防重入：进行中的第二次调用被忽略，不会二次渲染', (tester) async {
      await _initAppConfig();
      int renderCallCount = 0;
      final renderGate = Completer<ScheduleImageArtifact>();
      Future<ScheduleImageArtifact> slowRender(
        BuildContext context,
        ScheduleExportData data,
      ) {
        renderCallCount++;
        return renderGate.future;
      }

      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      // 第一次：渲染挂起（等价于“正在生成课表图片…”）
      final firstFlow = showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: slowRender,
      );
      await tester.pump();
      expect(renderCallCount, equals(1));

      // 第二次：应被文件级防重入锁忽略
      final secondFlow = showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: slowRender,
      );
      await tester.pump();
      expect(renderCallCount, equals(1));

      // 放行第一次 → 此时才允许出现三选一 → 取消
      renderGate.complete(fakeArtifact);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(3));
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await firstFlow;
      await secondFlow;
      expect(renderCallCount, equals(1));
    });

    testWidgets('无效数据：提示且不渲染、不弹三选一', (tester) async {
      await _initAppConfig();
      int renderCallCount = 0;
      Future<ScheduleImageArtifact> fakeRender(
        BuildContext context,
        ScheduleExportData data,
      ) async {
        renderCallCount++;
        return fakeArtifact;
      }

      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;
      final emptyData = ScheduleExportData(
        config: validConfig,
        courses: const [],
        targetWeek: 1,
      );

      await showScheduleImageExportFlow(
        buildContext,
        data: emptyData,
        render: fakeRender,
      );
      await tester.pumpAndSettle();

      expect(renderCallCount, equals(0));
      expect(find.byType(ListTile), findsNothing);
      expect(find.text(l10n.exportScheduleAsImageEmpty), findsOneWidget);
    });

    testWidgets('渲染失败：提示生成失败且不弹三选一', (tester) async {
      await _initAppConfig();
      Future<ScheduleImageArtifact> failingRender(
        BuildContext context,
        ScheduleExportData data,
      ) async {
        throw const ScheduleImageExportException(
          ScheduleImageErrorType.captureFailed,
        );
      }

      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      await showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: failingRender,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(find.text(l10n.exportScheduleAsImageFailed), findsOneWidget);
    });

    testWidgets('相册权限被拒：给出权限提示', (tester) async {
      await _initAppConfig();
      Future<ScheduleImageArtifact> fakeRender(
        BuildContext context,
        ScheduleExportData data,
      ) async {
        return fakeArtifact;
      }

      Future<ScheduleImageOutputStatus> deniedOutput(
        BuildContext context,
        AppLocalizations l10n,
        ScheduleImageAction action,
        ScheduleImageArtifact artifact,
      ) async {
        return ScheduleImageOutputStatus.permissionDenied;
      }

      late BuildContext buildContext;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              buildContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(buildContext)!;

      final flowFuture = showScheduleImageExportFlow(
        buildContext,
        data: validData,
        render: fakeRender,
        output: deniedOutput,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.saveScheduleImageToGallery));
      await tester.pumpAndSettle();
      await flowFuture;

      expect(
        find.text(l10n.scheduleImageGalleryPermissionDenied),
        findsOneWidget,
      );
    });
  });

  group('真实捕获链路（RepaintBoundary → PNG，不使用 fake）', () {
    testWidgets('ScheduleExportView 能被真实捕获为合法 PNG', (tester) async {
      await _initAppConfig();
      final boundaryKey = GlobalKey();
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 9, 1),
        totalWeeks: 20,
      );
      final data = ScheduleExportData(
        config: config,
        courses: [testCourse],
        targetWeek: 1,
      );

      await tester.pumpWidget(
        _wrap(
          Stack(
            alignment: Alignment.topLeft,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: kScheduleImageLogicalWidth,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: ScheduleExportView(data: data),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      expect(boundary.size.width, equals(kScheduleImageLogicalWidth));
      expect(boundary.size.height, greaterThan(0));

      final pngBytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return byteData!.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      });

      expect(pngBytes, isNotNull);
      expect(pngBytes!.length, greaterThan(0));
      // PNG 文件头：89 50 4E 47
      expect(pngBytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));
    });
  });
}
