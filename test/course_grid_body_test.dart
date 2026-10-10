import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/widgets/course_card.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid_body.dart';
import 'package:bugaoshan/pages/course/widgets/grid_day_column.dart';
import 'package:bugaoshan/pages/course/widgets/grid_header.dart';
import 'package:bugaoshan/pages/course/widgets/grid_section_column.dart';
import 'package:bugaoshan/pages/course/widgets/minimal_weekday_header.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 与 test/course_display_settings_test.dart 相同的 AppConfigProvider 装配方式。
/// CourseGridBody 本身不读 GetIt，但内部的 CourseCard 仍 live 读 AppConfig，
/// 因此渲染网格前必须注册。
Future<AppConfigProvider> _registerAppConfig() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final appConfig = AppConfigProvider(prefs);
  await appConfig.init();
  getIt.registerSingleton<AppConfigProvider>(appConfig);
  return appConfig;
}

/// 每天 [sections] 节、无时间段的课表（节次列只显示编号）。
ScheduleConfig _config({required int sections}) => ScheduleConfig(
  semesterStartDate: DateTime(2026, 9, 1),
  morningSections: sections,
  afternoonSections: 0,
  eveningSections: 0,
  timeSlots: const [],
);

Course _course() => Course(
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

/// 同名/同星期/同节次，但教师、地点、周次可调：用于验证 showAllWeeks 的合并语义
/// （grid_logic.mergeSameSlotCourses / mergeCourseGroup）。
Course _mergeableCourse({
  required String name,
  required String teacher,
  required String location,
  required int startWeek,
  required int endWeek,
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
}) => Course(
  name: name,
  teacher: teacher,
  location: location,
  startWeek: startWeek,
  endWeek: endWeek,
  dayOfWeek: dayOfWeek,
  startSection: startSection,
  endSection: endSection,
  colorValue: 0xFF2196F3,
);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// 无界高度 + 撑满宽度：复刻 CourseGrid 在 SingleChildScrollView 内的真实约束，
/// 让网格以自然高度布局（有界高度会把节次列的 Column 拉伸/撑溢出）。
Widget _unbounded(Widget child) => _app(SingleChildScrollView(child: child));

/// 有界高度容器：用于断言 Scrollable 数量与点击坐标（内容必须小于容器）。
Widget _bounded(Widget child, {double width = 400, double height = 240}) =>
    _app(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );

void main() {
  late AppConfigProvider appConfig;

  setUp(() async {
    await getIt.reset();
    appConfig = await _registerAppConfig();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('导出视图依赖的常量契约', () {
    test('kCourseGridSectionWidth / kCourseGridHeaderHeight 取值冻结', () {
      expect(kCourseGridSectionWidth, 35);
      expect(kCourseGridHeaderHeight, 40);
    });
  });

  group('CourseGridBody 布局', () {
    testWidgets('showWeekend=false → 5 个日列；true → 7 个日列', (tester) async {
      Widget body({required bool showWeekend}) => _bounded(
        CourseGridBody(
          courses: const [],
          config: _config(sections: 4),
          displayWeek: 1,
          showWeekend: showWeekend,
          showNonCurrentWeekCourses: true,
          rowHeight: 60,
          showCourseGrid: true,
        ),
      );

      await tester.pumpWidget(body(showWeekend: false));
      expect(find.byType(GridDayColumn), findsNWidgets(5));

      await tester.pumpWidget(body(showWeekend: true));
      expect(find.byType(GridDayColumn), findsNWidgets(7));
    });

    testWidgets(
      '日列与节次列高度 = rowHeight × sections，宽度 = kCourseGridSectionWidth',
      (tester) async {
        await tester.pumpWidget(
          _unbounded(
            CourseGridBody(
              courses: const [],
              config: _config(sections: 12),
              displayWeek: 1,
              showWeekend: false,
              showNonCurrentWeekCourses: true,
              rowHeight: 72,
              showCourseGrid: true,
            ),
          ),
        );

        final sectionColumn = tester.getSize(find.byType(GridSectionColumn));
        expect(sectionColumn.width, kCourseGridSectionWidth);
        expect(sectionColumn.height, 72 * 12);
        expect(
          tester.getSize(find.byType(GridDayColumn).first).height,
          72 * 12,
        );
      },
    );

    testWidgets('rowHeight=120 时确实使用 120', (tester) async {
      await tester.pumpWidget(
        _unbounded(
          CourseGridBody(
            courses: const [],
            config: _config(sections: 12),
            displayWeek: 1,
            showWeekend: true,
            showNonCurrentWeekCourses: true,
            rowHeight: 120,
            showCourseGrid: true,
          ),
        ),
      );

      expect(tester.getSize(find.byType(GridSectionColumn)).height, 120 * 12);
      expect(tester.getSize(find.byType(GridDayColumn).first).height, 120 * 12);
    });

    testWidgets('CourseGridBody 自身不含 Scrollable；CourseGrid 恰好 1 个', (
      tester,
    ) async {
      appConfig.courseRowHeight.value = 60;

      await tester.pumpWidget(
        _bounded(
          CourseGridBody(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
            showWeekend: false,
            showNonCurrentWeekCourses: true,
            rowHeight: 60,
            showCourseGrid: true,
          ),
        ),
      );
      expect(find.byType(Scrollable), findsNothing);

      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
          ),
        ),
      );
      expect(find.byType(Scrollable), findsOneWidget);
    });
  });

  group('CourseGridHeader 表头二选一', () {
    testWidgets('默认（显示日期、非聚合）走 GridHeaderRow', (tester) async {
      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
          ),
        ),
      );

      expect(find.byType(CourseGridHeader), findsOneWidget);
      expect(find.byType(GridHeaderRow), findsOneWidget);
      expect(find.byType(MinimalWeekdayHeader), findsNothing);
    });

    testWidgets('showAllWeeks / showHeaderDates=false 走 MinimalWeekdayHeader', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
            showAllWeeks: true,
          ),
        ),
      );
      expect(find.byType(MinimalWeekdayHeader), findsOneWidget);
      expect(find.byType(GridHeaderRow), findsNothing);

      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
            showHeaderDates: false,
          ),
        ),
      );
      expect(find.byType(MinimalWeekdayHeader), findsOneWidget);
      expect(find.byType(GridHeaderRow), findsNothing);
    });
  });

  group('空白单元格两段点击（状态已搬入 CourseGridBody）', () {
    // 5 天、每天 4 节、rowHeight 60 → 内容 400×240，点击坐标稳定。
    const bodyWidth = 400.0;
    const rowHeight = 60.0;
    const sections = 4;

    Offset tapPointFor(WidgetTester tester, int dayIndex, int section) {
      final origin = tester.getTopLeft(find.byType(CourseGridBody));
      final columnWidth = (bodyWidth - kCourseGridSectionWidth) / 5;
      return origin +
          Offset(
            kCourseGridSectionWidth + columnWidth * (dayIndex + 0.5),
            rowHeight * (section - 1) + rowHeight / 2,
          );
    }

    Widget body({void Function(int dayOfWeek, int section)? onEmptyTap}) =>
        _bounded(
          CourseGridBody(
            courses: const [],
            config: _config(sections: sections),
            displayWeek: 1,
            showWeekend: false,
            showNonCurrentWeekCourses: true,
            rowHeight: rowHeight,
            showCourseGrid: true,
            onEmptyTap: onEmptyTap,
          ),
          width: bodyWidth,
          height: rowHeight * sections,
        );

    testWidgets('第一次点击选中、第二次点击回调并清除选中', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        body(onEmptyTap: (day, section) => taps.add('$day-$section')),
      );

      expect(find.byIcon(Icons.add), findsNothing);

      final point = tapPointFor(tester, 0, 3);
      await tester.tapAt(point);
      await tester.pump();

      // 第一次点击只选中，不触发回调
      expect(taps, isEmpty);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tapAt(point);
      await tester.pump();

      expect(taps, ['1-3']);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('onEmptyTap 为 null 时不产生可交互选中态', (tester) async {
      await tester.pumpWidget(body(onEmptyTap: null));

      final point = tapPointFor(tester, 0, 3);
      await tester.tapAt(point);
      await tester.pump();

      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('已有选中时点击另一个单元格 → 取消选中且不触发回调', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        body(onEmptyTap: (day, section) => taps.add('$day-$section')),
      );

      // 先选中 (第 1 天, 第 3 节)
      await tester.tapAt(tapPointFor(tester, 0, 3));
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);

      // 再点同一天的第 4 节：命中"点击不同单元格"分支 → 仅取消选中
      await tester.tapAt(tapPointFor(tester, 0, 4));
      await tester.pump();

      expect(taps, isEmpty);
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });

  group('CourseGridBody showAllWeeks 合并/分轨（grid_logic 语义）', () {
    Widget body(List<Course> courses) => _unbounded(
      CourseGridBody(
        courses: courses,
        config: _config(sections: 4),
        displayWeek: 1,
        showWeekend: false,
        showNonCurrentWeekCourses: true,
        rowHeight: 72,
        showCourseGrid: true,
        showAllWeeks: true,
      ),
    );

    testWidgets('同名同星期同节次且同地点 → 合并为一张卡（教师去重、地点/周次合并）', (tester) async {
      await tester.pumpWidget(
        body([
          _mergeableCourse(
            name: '大学物理',
            teacher: '张老师',
            location: '一教101',
            startWeek: 1,
            endWeek: 8,
          ),
          _mergeableCourse(
            name: '大学物理',
            teacher: '李老师',
            location: '一教101',
            startWeek: 5,
            endWeek: 16,
          ),
        ]),
      );
      await tester.pump();

      expect(find.byType(CourseCard), findsOneWidget);
      expect(find.text('大学物理'), findsOneWidget);
      // 教师去重后以 '、' 连接；同一地点只保留一份（不是 ' 一教101 · 一教101'）
      expect(find.text('张老师、李老师'), findsOneWidget);
      expect(find.text('一教101'), findsOneWidget);
      // 周次取 min/max：1..8 与 5..16 → 1..16
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CourseCard)),
      )!;
      expect(find.text(l10n.weekRange(1, 16)), findsOneWidget);
    });

    testWidgets('同名同节次但地点不同 → 不合并，保留并排轨道', (tester) async {
      await tester.pumpWidget(
        body([
          _mergeableCourse(
            name: '大学物理',
            teacher: '张老师',
            location: '一教101',
            startWeek: 1,
            endWeek: 16,
          ),
          _mergeableCourse(
            name: '大学物理',
            teacher: '张老师',
            location: '二教202',
            startWeek: 1,
            endWeek: 16,
          ),
        ]),
      );
      await tester.pump();

      expect(find.byType(CourseCard), findsNWidgets(2));
      expect(find.text('一教101'), findsOneWidget);
      expect(find.text('二教202'), findsOneWidget);

      // 并排轨道：同一 top、不同 left（assignCourseTracks 分轨）
      final first = tester.getTopLeft(find.byType(CourseCard).at(0));
      final second = tester.getTopLeft(find.byType(CourseCard).at(1));
      expect(first.dy, second.dy);
      expect(first.dx, lessThan(second.dx));
    });
  });

  group('CourseCard 仍 live 读 AppConfig（本次重构未改变）', () {
    Widget grid() => _app(
      CourseGrid(
        courses: [_course()],
        config: _config(sections: 4),
        displayWeek: 1,
      ),
    );

    testWidgets('showTeacherName / showLocation 关闭后文案消失，恢复后重现', (tester) async {
      await tester.pumpWidget(grid());
      await tester.pump();

      expect(find.text('高等数学'), findsOneWidget);
      expect(find.text('张老师'), findsOneWidget);
      expect(find.text('一教101'), findsOneWidget);

      appConfig.showTeacherName.value = false;
      appConfig.showLocation.value = false;
      await tester.pump();

      expect(find.text('高等数学'), findsOneWidget);
      expect(find.text('张老师'), findsNothing);
      expect(find.text('一教101'), findsNothing);

      appConfig.showTeacherName.value = true;
      appConfig.showLocation.value = true;
      await tester.pump();

      expect(find.text('张老师'), findsOneWidget);
      expect(find.text('一教101'), findsOneWidget);
    });

    testWidgets('rowHeight / showWeekend 由 CourseGrid 透传给 Body', (
      tester,
    ) async {
      appConfig.courseRowHeight.value = 120;
      appConfig.showWeekend.value = true;

      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
          ),
        ),
      );

      expect(find.byType(GridDayColumn), findsNWidgets(7));
      final body = tester.widget<CourseGridBody>(find.byType(CourseGridBody));
      expect(body.rowHeight, 120);
      expect(body.showWeekend, isTrue);
      expect(body.showNonCurrentWeekCourses, isTrue);
      expect(body.showCourseGrid, isTrue);
    });

    testWidgets('showNonCurrentWeekCourses / showCourseGrid 由 CourseGrid 透传', (
      tester,
    ) async {
      appConfig.showNonCurrentWeekCourses.value = false;
      appConfig.showCourseGrid.value = false;

      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
          ),
        ),
      );

      final body = tester.widget<CourseGridBody>(find.byType(CourseGridBody));
      expect(body.showNonCurrentWeekCourses, isFalse);
      expect(body.showCourseGrid, isFalse);
    });

    testWidgets('showWeekendOverride 仍然优先于全局 showWeekend', (tester) async {
      appConfig.showWeekend.value = true;

      // 覆盖为 false：即使全局显示周末，也只渲染 5 天（班级课表/培养方案依赖该语义）
      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
            showWeekendOverride: false,
          ),
        ),
      );
      expect(find.byType(GridDayColumn), findsNWidgets(5));
      expect(
        tester.widget<CourseGridBody>(find.byType(CourseGridBody)).showWeekend,
        isFalse,
      );

      // 覆盖为 true：全局关闭周末时仍然渲染 7 天
      appConfig.showWeekend.value = false;
      await tester.pumpWidget(
        _app(
          CourseGrid(
            courses: const [],
            config: _config(sections: 4),
            displayWeek: 1,
            showWeekendOverride: true,
          ),
        ),
      );
      expect(find.byType(GridDayColumn), findsNWidgets(7));
      expect(
        tester.widget<CourseGridBody>(find.byType(CourseGridBody)).showWeekend,
        isTrue,
      );
    });
  });
}
