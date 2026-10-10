import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/export/schedule_export_view.dart';
import 'package:bugaoshan/pages/course/widgets/grid_day_column.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

Widget _wrapHost(Widget child, {ThemeData? theme}) => MaterialApp(
  key: ValueKey(theme?.brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme ?? ThemeData.light(),
  home: Scaffold(
    body: Stack(
      alignment: Alignment.topLeft,
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: kScheduleImageLogicalWidth,
          child: child,
        ),
      ],
    ),
  ),
);

Future<AppConfigProvider> _createAppConfig({
  Map<String, Object> values = const {},
}) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final config = AppConfigProvider(prefs);
  await config.init();
  if (getIt.isRegistered<AppConfigProvider>()) {
    await getIt.unregister<AppConfigProvider>();
  }
  getIt.registerSingleton<AppConfigProvider>(config);
  return config;
}

Future<File> _writeTestImage(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final bytes = (await rootBundle.load(
      'assets/icon.png',
    )).buffer.asUint8List();
    final dir = await Directory.systemTemp.createTemp('bugaoshan_export_test');
    addTearDown(() => dir.delete(recursive: true).ignore());
    final file = File('${dir.path}/bg.png');
    await file.writeAsBytes(bytes);
    return file;
  }))!;
}

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
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  final sampleConfig = ScheduleConfig(
    semesterStartDate: DateTime(2026, 9, 1),
    totalWeeks: 20,
    morningSections: 4,
    afternoonSections: 5,
    eveningSections: 3,
  );

  final course1 = Course(
    name: '高等数学',
    teacher: '张老师',
    location: '一教101',
    startWeek: 1,
    endWeek: 16,
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    colorValue: 0xFF2196F3,
  );

  final lastCourse = Course(
    name: '编译原理',
    teacher: '李老师',
    location: '二教202',
    startWeek: 1,
    endWeek: 16,
    dayOfWeek: 5,
    startSection: 11,
    endSection: 12,
    colorValue: 0xFF4CAF50,
  );

  testWidgets('showWeekend=false 显示 5 列，showWeekend=true 显示 7 列', (
    tester,
  ) async {
    final appConfig = await _createAppConfig();
    appConfig.showWeekend.value = false;

    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1],
      targetWeek: 1,
    );

    await tester.pumpWidget(_wrapHost(ScheduleExportView(data: data)));
    expect(find.byType(GridDayColumn), findsNWidgets(5));

    appConfig.showWeekend.value = true;
    await tester.pumpWidget(_wrapHost(ScheduleExportView(data: data)));
    expect(find.byType(GridDayColumn), findsNWidgets(7));
  });

  testWidgets('教师/地点/周次在对应设置关闭时不渲染', (tester) async {
    final appConfig = await _createAppConfig();
    appConfig.showTeacherName.value = false;
    appConfig.showLocation.value = false;
    appConfig.showCourseWeeks.value = false;

    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1],
      targetWeek: 1,
    );

    await tester.pumpWidget(_wrapHost(ScheduleExportView(data: data)));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScheduleExportView)),
    )!;

    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('张老师'), findsNothing);
    expect(find.text('一教101'), findsNothing);
    // 用「课程实际会渲染出的周次文案」做否定断言：
    // 不能用 textContaining('周')——测试默认 en locale 下文案里没有「周」，
    // 那样即使周次被渲染出来也会假通过。
    expect(find.text(course1.formatWeeks(l10n)), findsNothing);
  });

  testWidgets('rowHeight=120 确实生效并决定日列高度', (tester) async {
    final appConfig = await _createAppConfig();
    appConfig.courseRowHeight.value = 120.0;

    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1],
      targetWeek: 1,
    );

    await tester.pumpWidget(_wrapHost(ScheduleExportView(data: data)));

    final dayColumn = tester.firstWidget<GridDayColumn>(
      find.byType(GridDayColumn),
    );
    expect(dayColumn.rowHeight, equals(120.0));

    final dayColumnSize = tester.getSize(find.byType(GridDayColumn).first);
    expect(dayColumnSize.height, equals(120.0 * 12));
  });

  testWidgets('ScheduleExportView 内部不包含任何 Scrollable 组件', (tester) async {
    await _createAppConfig();
    final data = ScheduleExportData(
      config: sampleConfig,
      courses: const [],
      targetWeek: 1,
    );

    await tester.pumpWidget(_wrapHost(ScheduleExportView(data: data)));

    final scrollables = find.descendant(
      of: find.byType(ScheduleExportView),
      matching: find.byType(Scrollable),
    );
    expect(scrollables, findsNothing);
  });

  testWidgets(
    '宿主约束下（宽度固定 420，高度无界）size.height ≈ 40*textScale + rowHeight*sections',
    (tester) async {
      final appConfig = await _createAppConfig();
      appConfig.courseRowHeight.value = 65.0;

      final data = ScheduleExportData(
        config: sampleConfig,
        courses: [course1],
        targetWeek: 1,
      );

      await tester.pumpWidget(_wrapHost(ScheduleExportView(data: data)));

      final viewSize = tester.getSize(find.byType(ScheduleExportView));
      const expectedWidth = 420.0;
      // 测试环境的 textScaler = 1.0，故表头高度恰为 40（production 不得计算该公式，
      // 这里只是测试侧的期望值；无障碍大字号下需同步调整本期望）。
      final expectedHeight = 40.0 + 65.0 * sampleConfig.sectionsPerDay;

      expect(viewSize.width, equals(expectedWidth));
      expect(viewSize.height, closeTo(expectedHeight, 0.5));
    },
  );

  testWidgets('最后一节课程卡片完全落在 boundary 边界内', (tester) async {
    await _createAppConfig();
    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1, lastCourse],
      targetWeek: 1,
    );

    await tester.pumpWidget(_wrapHost(ScheduleExportView(data: data)));

    final viewRect = tester.getRect(find.byType(ScheduleExportView));
    final lastCardRect = tester.getRect(find.text('编译原理'));

    expect(viewRect.contains(lastCardRect.topLeft), isTrue);
    expect(viewRect.contains(lastCardRect.bottomRight), isTrue);
    expect(lastCardRect.bottom, lessThanOrEqualTo(viewRect.bottom));
  });

  testWidgets('light/dark 两种 Theme 下卡片文字色不同', (tester) async {
    final appConfig = await _createAppConfig();
    // 半透明背景使卡片受 scaffoldBackgroundColor 影响，明暗主题下反衬出不同文字色
    appConfig.colorOpacity.value = 0.2;

    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1],
      targetWeek: 1,
    );

    await tester.pumpWidget(
      _wrapHost(
        ScheduleExportView(key: const ValueKey('light'), data: data),
        theme: ThemeData.light(),
      ),
    );
    final lightText = tester.widget<Text>(find.text('高等数学'));
    final lightColor = lightText.style?.color;

    await tester.pumpWidget(
      _wrapHost(
        ScheduleExportView(key: const ValueKey('dark'), data: data),
        theme: ThemeData.dark(),
      ),
    );
    final darkText = tester.widget<Text>(find.text('高等数学'));
    final darkColor = darkText.style?.color;

    expect(lightColor, isNotNull);
    expect(darkColor, isNotNull);
    expect(lightColor, isNot(equals(darkColor)));
    expect(lightColor, equals(Colors.black87));
    expect(darkColor, equals(Colors.white));
  });

  testWidgets('背景图预热后首帧即挂载 Image 组件', (tester) async {
    await _createAppConfig();
    final file = await _writeTestImage(tester);
    await _warmImageCache(tester, file);

    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1],
      targetWeek: 1,
    );

    await tester.pumpWidget(
      _wrapHost(ScheduleExportView(data: data, backgroundImagePath: file.path)),
    );

    // 首帧（无 pump(Duration)）即有 Image
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('背景图片文件不存在时无 Image 且不抛出异常', (tester) async {
    await _createAppConfig();
    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1],
      targetWeek: 1,
    );

    await tester.pumpWidget(
      _wrapHost(
        ScheduleExportView(
          data: data,
          backgroundImagePath: 'non_existent_file_path_xyz.png',
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('反向纪律用例：将 View 放进高度有界的容器会触发 RenderFlex 溢出', (tester) async {
    await _createAppConfig();
    final data = ScheduleExportData(
      config: sampleConfig,
      courses: [course1],
      targetWeek: 1,
    );

    // 高度仅 200，而 View 内部 Column 至少 40 + 60*12 = 760
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 200,
            child: ScheduleExportView(data: data),
          ),
        ),
      ),
    );

    final exception = tester.takeException();
    expect(exception, isNotNull);
    expect(exception.toString(), contains('overflowed'));
  });
}
