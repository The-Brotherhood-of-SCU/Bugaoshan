import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/pages/campus/grades/scheme_scores_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/course_teacher_index.dart';
import 'package:bugaoshan/services/database_service.dart';

Course _c(String name, String teacher, {int dayOfWeek = 1}) => Course(
  name: name,
  teacher: teacher,
  location: '',
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: dayOfWeek,
  startSection: 1,
  endSection: 2,
  colorValue: 0,
);

ScheduleConfig _cfg({
  String? academicYear,
  String? termName,
  String? semesterName,
  String id = 'default',
}) => ScheduleConfig(
  id: id,
  semesterStartDate: DateTime(2024, 9, 1),
  academicYearCode: academicYear,
  termName: termName,
  semesterName: semesterName ?? '',
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CourseTeacherIndex - 课程名称归一化', () {
    test('保留课程本体括号（括号前无空白或内容非字母数字）', () {
      expect(
        CourseTeacherIndex.normalizeCourseName('C语言程序设计(A)'),
        'C语言程序设计(A)',
      );
      expect(CourseTeacherIndex.normalizeCourseName('大学英语(一)'), '大学英语(一)');
      expect(CourseTeacherIndex.normalizeCourseName('大学英语（一）'), '大学英语(一)');
      expect(CourseTeacherIndex.normalizeCourseName('工程数学(下)'), '工程数学(下)');
    });

    test('正确剥离解析器追加的课序号后缀（要求括号前有空白）', () {
      expect(CourseTeacherIndex.normalizeCourseName('大学英语(一) (02)'), '大学英语(一)');
      expect(CourseTeacherIndex.normalizeCourseName('高等数学 (01)'), '高等数学');
      expect(CourseTeacherIndex.normalizeCourseName('高等数学 (A1)'), '高等数学');
      expect(CourseTeacherIndex.normalizeCourseName('高等数学 ()'), '高等数学');
      expect(CourseTeacherIndex.normalizeCourseName('大学物理（1） (10)'), '大学物理(1)');
      expect(
        CourseTeacherIndex.normalizeCourseName('形势与政策-6 (001)'),
        '形势与政策-6',
      );
    });
  });

  group('CourseTeacherIndex - 学期标识归一化', () {
    test('优先使用 academicYear 与 termSeason', () {
      expect(
        CourseTeacherIndex.normalizeTerm(
          academicYear: '2024-2025',
          termSeason: '秋',
        ),
        '2024-2025_秋',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(
          academicYear: '2025-2026',
          termSeason: '春季学期',
        ),
        '2025-2026_春',
      );
    });

    test('从 rawTermLabel 解析学期', () {
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025学年秋'),
        '2024-2025_秋',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2023-2024学年春(两学期)'),
        '2023-2024_春',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025-1'),
        '2024-2025_秋',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025-2'),
        '2024-2025_春',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025-1-1'),
        '2024-2025_秋',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025-2-1'),
        '2024-2025_春',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025学年第一学期'),
        '2024-2025_秋',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025学年第二学期'),
        '2024-2025_春',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025秋 (第2版)'),
        '2024-2025_秋',
      );
      expect(
        CourseTeacherIndex.normalizeTerm(rawTermLabel: '2024-2025-1(周二上课)'),
        '2024-2025_秋',
      );
    });

    test('无法解析学期时返回 null（严禁使用当前日期猜测）', () {
      expect(CourseTeacherIndex.normalizeTerm(rawTermLabel: '我的课表'), isNull);
      expect(CourseTeacherIndex.normalizeTerm(rawTermLabel: ''), isNull);
      expect(CourseTeacherIndex.normalizeTerm(), isNull);
    });
  });

  group('CourseTeacherIndex - 教师解析与集合匹配', () {
    test('多教师拆分、清洗与排序去重', () {
      final list = CourseTeacherIndex.parseTeachers('张老师, 李老师、张老师');
      expect(list, ['张老师', '李老师']..sort());
    });

    test('不同顺序的同一教师组合被识别为同一签名（不误报冲突）', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(academicYear: '2024-2025', termName: '秋'),
          courses: [
            _c('高等数学 (01)', '张老师, 李老师', dayOfWeek: 1),
            _c('高等数学 (01)', '李老师、张老师', dayOfWeek: 3),
          ],
        ),
      ]);

      final teacher = index.getTeacher(
        academicYear: '2024-2025',
        termSeason: '秋',
        courseName: '高等数学',
      );
      expect(teacher, isNotNull);
      final parts = teacher!.split('、');
      expect(parts, containsAll(['张老师', '李老师']));
      expect(parts.length, 2);
    });

    test('空教师记录被忽略，采纳有效记录且不计入冲突', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(semesterName: '2024-2025学年秋'),
          courses: [
            _c('大学物理 (01)', '', dayOfWeek: 1),
            _c('大学物理 (01)', '王老师', dayOfWeek: 3),
          ],
        ),
      ]);

      expect(
        index.getTeacher(rawTermLabel: '2024-2025学年秋', courseName: '大学物理'),
        '王老师',
      );
    });

    test('全部记录均无教师时返回 null', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(semesterName: '2024-2025学年秋'),
          courses: [_c('空教师课 (01)', '  ')],
        ),
      ]);

      expect(
        index.getTeacher(rawTermLabel: '2024-2025学年秋', courseName: '空教师课'),
        isNull,
      );
    });

    test('同学期存在不同教师候选时判定为歧义冲突，返回 null', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(semesterName: '2024-2025学年秋'),
          courses: [
            _c('程序设计 (01)', '张老师', dayOfWeek: 1),
            _c('程序设计 (02)', '李老师', dayOfWeek: 3),
          ],
        ),
      ]);

      expect(
        index.getTeacher(rawTermLabel: '2024-2025学年秋', courseName: '程序设计'),
        isNull,
      );
    });

    test('不同学期的同名课程互不干扰，不发生串教师', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(semesterName: '2023-2024学年秋'),
          courses: [_c('线性代数 (01)', '老赵')],
        ),
        (
          config: _cfg(semesterName: '2024-2025学年秋'),
          courses: [_c('线性代数 (02)', '新钱')],
        ),
      ]);

      expect(
        index.getTeacher(rawTermLabel: '2023-2024学年秋', courseName: '线性代数'),
        '老赵',
      );
      expect(
        index.getTeacher(rawTermLabel: '2024-2025学年秋', courseName: '线性代数'),
        '新钱',
      );
      expect(
        index.getTeacher(rawTermLabel: '2024-2025学年春', courseName: '线性代数'),
        isNull,
      );
    });

    test('termFromGradeDate 正确将成绩时间戳转换为学年学期', () {
      expect(CourseTeacherIndex.termFromGradeDate('20260115'), '2025-2026_秋');
      expect(
        CourseTeacherIndex.termFromGradeDate('(必修,87.0(20260115))'),
        '2025-2026_秋',
      );
      expect(
        CourseTeacherIndex.termFromGradeDate('(必修,90.0(20260625))'),
        '2025-2026_春',
      );
      expect(CourseTeacherIndex.termFromGradeDate('20251120'), '2025-2026_秋');
      expect(CourseTeacherIndex.termFromGradeDate('无效日期'), isNull);
    });

    test('当培养方案建议学期与实际修读学期不同时，能够通过 gradeInfo 成绩日期成功兜底匹配', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(semesterName: '2025-2026学年秋'),
          courses: [_c('改革开放史 (04)', '段龙龙* 张仁枫 万春林 朱莉')],
        ),
      ]);

      final teacher = index.getTeacher(
        rawTermLabel: '2025-2026学年春',
        gradeInfo: '(必修,87.0(20260115))',
        courseName: '改革开放史',
      );

      expect(teacher, isNotNull);
      expect(teacher, contains('段龙龙*'));
      expect(teacher, contains('朱莉'));
    });

    test('体育专项课（如方案中体育-1对应课表中体育-1气排球）能够正确匹配', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(semesterName: '2025-2026学年秋'),
          courses: [_c('体育-1气排球 (03)', '孙景权*')],
        ),
      ]);

      final teacher = index.getTeacher(
        rawTermLabel: '2025-2026学年秋',
        courseName: '体育-1',
      );

      expect(teacher, '孙景权*');
      expect(
        index.getTeacher(rawTermLabel: '2025-2026学年秋', courseName: '体育—1'),
        '孙景权*',
      );
    });

    test('体育专项课严格限定编号边界，体育-1不误匹配体育-10', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(semesterName: '2025-2026学年秋'),
          courses: [_c('体育-10跆拳道 (01)', '李教练')],
        ),
      ]);

      expect(
        index.getTeacher(rawTermLabel: '2025-2026学年秋', courseName: '体育-1'),
        isNull,
      );
      expect(
        index.getTeacher(rawTermLabel: '2025-2026学年秋', courseName: '体育—10'),
        '李教练',
      );
    });

    test('支持空格分隔的多个教师姓名（如段龙龙* 张仁枫 万春林 朱莉）', () {
      final list = CourseTeacherIndex.parseTeachers('段龙龙* 张仁枫 万春林 朱莉');
      expect(list.length, 4);
      expect(list, containsAll(['段龙龙*', '张仁枫', '万春林', '朱莉']));
    });
  });

  group('CourseTeacherIndex - 数据库集成与失效缓存测试', () {
    late Database db;
    late DatabaseService dbService;

    setUp(() async {
      CourseTeacherIndex.invalidate();
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE schedules (
          id TEXT PRIMARY KEY,
          config_json TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE courses (
          id TEXT PRIMARY KEY,
          schedule_id TEXT NOT NULL,
          name TEXT,
          teacher TEXT,
          location TEXT,
          campus TEXT NOT NULL DEFAULT '',
          start_week INTEGER,
          end_week INTEGER,
          day_of_week INTEGER,
          start_section INTEGER,
          end_section INTEGER,
          color_value INTEGER,
          week_type INTEGER,
          custom_weeks TEXT,
          FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
        )
      ''');

      dbService = DatabaseService.forTesting(db);
    });

    tearDown(() async {
      CourseTeacherIndex.invalidate();
      await db.close();
    });

    test('从已初始化的 DatabaseService 安全构建，课表切换不改变索引结果', () async {
      final config1 = _cfg(id: 'sch1', semesterName: '2023-2024学年秋');
      final config2 = _cfg(id: 'sch2', semesterName: '2024-2025学年秋');

      await dbService.addSchedule(config1);
      await dbService.addSchedule(config2);

      await dbService.switchSchedule('sch1');
      await dbService.addCourse(_c('高数 (01)', '张老师'));

      await dbService.switchSchedule('sch2');
      await dbService.addCourse(_c('高数 (02)', '李老师'));

      final index = await CourseTeacherIndex.load(dbService);
      expect(index, isNotNull);

      expect(
        index!.getTeacher(rawTermLabel: '2023-2024学年秋', courseName: '高数'),
        '张老师',
      );
      expect(
        index.getTeacher(rawTermLabel: '2024-2025学年秋', courseName: '高数'),
        '李老师',
      );

      // 切换当前激活课表，索引结果不变
      await dbService.switchSchedule('sch1');
      expect(
        index.getTeacher(rawTermLabel: '2024-2025学年秋', courseName: '高数'),
        '李老师',
      );
    });

    test('调用 invalidate() 后重新从数据库加载新数据', () async {
      final config = _cfg(id: 'sch1', semesterName: '2024-2025学年秋');
      await dbService.addSchedule(config);
      await dbService.switchSchedule('sch1');

      final indexBefore = await CourseTeacherIndex.load(dbService);
      expect(
        indexBefore!.getTeacher(
          rawTermLabel: '2024-2025学年秋',
          courseName: '新加课程',
        ),
        isNull,
      );

      // 新增课程并使索引失效
      await dbService.addCourse(_c('新加课程 (01)', '刘老师'));
      CourseTeacherIndex.invalidate();

      final indexAfter = await CourseTeacherIndex.load(dbService);
      expect(
        indexAfter!.getTeacher(
          rawTermLabel: '2024-2025学年秋',
          courseName: '新加课程',
        ),
        '刘老师',
      );
    });

    test('调用 invalidate() 时 revision 版本号自增且通知监听者', () async {
      final initialRevision = CourseTeacherIndex.revision.value;
      var notified = 0;
      void listener() => notified++;
      CourseTeacherIndex.revision.addListener(listener);

      try {
        CourseTeacherIndex.invalidate();
        expect(CourseTeacherIndex.revision.value, initialRevision + 1);
        expect(notified, 1);

        CourseTeacherIndex.invalidate();
        expect(CourseTeacherIndex.revision.value, initialRevision + 2);
        expect(notified, 2);
      } finally {
        CourseTeacherIndex.revision.removeListener(listener);
      }
    });
  });

  group('UI 渲染与展示测试', () {
    testWidgets('ScoreCardWidget 正常展示教师信息（存在教师）', (tester) async {
      const item = SchemeScoreItem(
        courseName: '高等数学',
        courseAttributeName: '必修',
        credit: '4',
        cj: '95',
        courseScore: 95.0,
        gradePointScore: 4.0,
        gradeName: 'A',
        academicYearCode: '2024-2025',
        termName: '秋',
        passed: true,
        hasEffectiveScore: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: ScoreCardWidget(item: item, teacher: '张老师、李老师'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('高等数学'), findsOneWidget);
      expect(find.text('授课教师：张老师、李老师'), findsOneWidget);
    });

    testWidgets('ScoreCardWidget 教师为 null 或空串时不展示教师文本', (tester) async {
      const item = SchemeScoreItem(
        courseName: '大学英语',
        courseAttributeName: '必修',
        credit: '3',
        cj: '85',
        courseScore: 85.0,
        gradePointScore: 3.5,
        gradeName: 'B+',
        academicYearCode: '2024-2025',
        termName: '秋',
        passed: true,
        hasEffectiveScore: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: ScoreCardWidget(item: item, teacher: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('大学英语'), findsOneWidget);
      expect(find.textContaining('授课教师'), findsNothing);
      expect(find.textContaining('未知教师'), findsNothing);
    });

    testWidgets('ScoreCardWidget 长课程名与长教师名不撑破布局', (tester) async {
      const item = SchemeScoreItem(
        courseName: '非常长非常长非常长非常长非常长非常长的专业核心必修课程名称',
        englishCourseName:
            'A Very Long Long Long Course Name in English Translation',
        courseAttributeName: '必修',
        credit: '5',
        cj: '90',
        courseScore: 90.0,
        gradePointScore: 4.0,
        gradeName: 'A',
        academicYearCode: '2024-2025',
        termName: '秋',
        passed: true,
        hasEffectiveScore: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: ScoreCardWidget(
              item: item,
              teacher: '张老师、李老师、王老师、赵老师、钱老师、孙老师',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ScoreCardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
