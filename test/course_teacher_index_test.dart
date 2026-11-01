import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/pages/campus/grades/scheme_scores_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
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
      expect(CourseTeacherIndex.normalizeCourseName('大学物理(1)'), '大学物理(1)');
      expect(CourseTeacherIndex.normalizeCourseName('大学物理（1）'), '大学物理(1)');
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
    test('多教师拆分、清洗与去重，保留原始先后顺序', () {
      final list1 = CourseTeacherIndex.parseTeachers('李老师, 张老师、李老师');
      expect(list1, ['李老师', '张老师']);

      final list2 = CourseTeacherIndex.parseTeachers('段龙龙* 张仁枫 万春林 朱莉');
      expect(list2, ['段龙龙*', '张仁枫', '万春林', '朱莉']);
    });

    test('不同顺序的同一教师组合被识别为同一签名（不误报冲突）', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(academicYear: '2024-2025', termName: '秋'),
          courses: [
            _c('高等数学 (01)', '李老师, 张老师', dayOfWeek: 1),
            _c('高等数学 (01)', '张老师、李老师', dayOfWeek: 3),
          ],
        ),
      ]);

      final teacher = index.getTeacher(
        academicYear: '2024-2025',
        termSeason: '秋',
        courseName: '高等数学',
      );
      expect(teacher, '李老师、张老师');
    });

    test('端到端匹配：课表课程「大学物理（1） (10)」精确匹配「大学物理（1）」，且不误匹配「大学物理（2）」', () {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(academicYear: '2024-2025', termName: '秋'),
          courses: [_c('大学物理（1） (10)', '孙老师')],
        ),
      ]);

      expect(
        index.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '大学物理（1）',
        ),
        '孙老师',
      );
      expect(
        index.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '大学物理(1)',
        ),
        '孙老师',
      );
      expect(
        index.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '大学物理（2）',
        ),
        isNull,
      );
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

  group('CourseTeacherIndex - 数据库无状态加载测试', () {
    late Database db;
    late DatabaseService dbService;

    setUp(() async {
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

    test('新增课程后再次调用 CourseTeacherIndex.load(dbService) 返回最新索引', () async {
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

      // 新增课程
      await dbService.addCourse(_c('新加课程 (01)', '刘老师'));

      final indexAfter = await CourseTeacherIndex.load(dbService);
      expect(
        indexAfter!.getTeacher(
          rawTermLabel: '2024-2025学年秋',
          courseName: '新加课程',
        ),
        '刘老师',
      );
    });
  });

  group('CourseTeacherIndexController - 页面级控制器测试', () {
    test('页面生命周期释放：dispose() 后 index 置空，且进行中的加载结果被丢弃并不触发通知', () async {
      final completer = Completer<CourseTeacherIndex?>();
      var notifyCount = 0;

      final controller = CourseTeacherIndexController(
        initialIndex: CourseTeacherIndex.fromSchedules([]),
        loader: ([db]) => completer.future,
      );
      controller.addListener(() => notifyCount++);

      expect(controller.index, isNotNull);

      // 触发异步加载
      unawaited(controller.reload());

      // 页面销毁：立即 dispose
      controller.dispose();
      expect(controller.index, isNull);

      // 加载完成
      completer.complete(
        CourseTeacherIndex.fromSchedules([
          (
            config: _cfg(academicYear: '2024-2025', termName: '秋'),
            courses: [_c('大学物理', '赵老师')],
          ),
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      // dispose 之后 index 依然为 null，且没有触发 notify
      expect(controller.index, isNull);
      expect(notifyCount, 0);
    });

    test('微任务合并：scheduleReload() 在同一事件循环内多次调用时仅触发一次重新加载', () async {
      var loadCount = 0;
      final controller = CourseTeacherIndexController(
        initialIndex: CourseTeacherIndex.fromSchedules([]),
        loader: ([db]) async {
          loadCount++;
          return CourseTeacherIndex.fromSchedules([]);
        },
      );

      expect(loadCount, 0);

      // 同一事件循环内多次调用 scheduleReload
      controller.scheduleReload();
      controller.scheduleReload();
      controller.scheduleReload();

      // 微任务执行前尚未加载
      expect(loadCount, 0);

      // 执行微任务
      await Future<void>.delayed(Duration.zero);

      expect(loadCount, 1);
      controller.dispose();
    });

    test('异步竞态守卫：先发起的慢加载在后发起的快加载完成之后才返回时，旧结果不会覆盖新索引', () async {
      final slowCompleter = Completer<CourseTeacherIndex?>();
      final fastCompleter = Completer<CourseTeacherIndex?>();

      final slowIndex = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(academicYear: '2024-2025', termName: '秋'),
          courses: [_c('高数', '慢速旧老师')],
        ),
      ]);
      final fastIndex = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(academicYear: '2024-2025', termName: '秋'),
          courses: [_c('高数', '快速新老师')],
        ),
      ]);

      var callIndex = 0;
      final controller = CourseTeacherIndexController(
        initialIndex: CourseTeacherIndex.fromSchedules([]),
        loader: ([db]) {
          callIndex++;
          if (callIndex == 1) {
            return slowCompleter.future;
          } else {
            return fastCompleter.future;
          }
        },
      );

      // 发起第 1 次慢加载
      final reload1 = controller.reload();
      // 紧接着发起第 2 次快加载
      final reload2 = controller.reload();

      // 快加载先完成
      fastCompleter.complete(fastIndex);
      await reload2;

      expect(
        controller.index?.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '高数',
        ),
        '快速新老师',
      );

      // 慢加载后完成
      slowCompleter.complete(slowIndex);
      await reload1;

      // 索引依然保持 fastIndex，旧结果被丢弃
      expect(
        controller.index?.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '高数',
        ),
        '快速新老师',
      );

      controller.dispose();
    });

    test('初次加载失败后调用 reload() 可重试恢复', () async {
      var loadCount = 0;
      var shouldFail = true;

      final controller = CourseTeacherIndexController(
        initialIndex: null, // 触发初次异步加载
        loader: ([db]) async {
          loadCount++;
          if (shouldFail) return null;
          return CourseTeacherIndex.fromSchedules([
            (
              config: _cfg(academicYear: '2024-2025', termName: '秋'),
              courses: [_c('大学物理', '赵老师')],
            ),
          ]);
        },
      );

      // 等待初次加载完成（失败）
      await Future<void>.delayed(Duration.zero);
      expect(loadCount, 1);
      expect(controller.index, isNull);

      // 恢复状态并调用 reload() 重试
      shouldFail = false;
      await controller.reload();
      expect(loadCount, 2);
      expect(
        controller.index?.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '大学物理',
        ),
        '赵老师',
      );

      controller.dispose();
    });

    test('已就绪的索引在后续 reload() 返回 null 时保留旧索引，不清空也不误发通知', () async {
      final validIndex = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(academicYear: '2024-2025', termName: '秋'),
          courses: [_c('大学物理', '赵老师')],
        ),
      ]);
      final controller = CourseTeacherIndexController(
        initialIndex: validIndex,
        loader: ([db]) async => null,
      );

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.reload();

      expect(controller.index, isNotNull);
      expect(
        controller.index?.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '大学物理',
        ),
        '赵老师',
      );
      expect(notifyCount, 0);

      controller.dispose();
    });

    test('注入的 loader 抛出异常时 reload() 安全捕获并保留旧索引', () async {
      final validIndex = CourseTeacherIndex.fromSchedules([
        (
          config: _cfg(academicYear: '2024-2025', termName: '秋'),
          courses: [_c('大学物理', '赵老师')],
        ),
      ]);
      final controller = CourseTeacherIndexController(
        initialIndex: validIndex,
        loader: ([db]) => throw StateError('DB transient error'),
      );

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.reload();

      expect(controller.index, isNotNull);
      expect(
        controller.index?.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '大学物理',
        ),
        '赵老师',
      );
      expect(notifyCount, 0);

      controller.dispose();
    });

    test('retryIfNeeded()：初次加载失败时触发重试，就绪时不产生重复加载，重载失败保留旧索引且再次重试', () async {
      var loadCount = 0;
      var returnNull = true;
      final controller = CourseTeacherIndexController(
        loader: ([db]) async {
          loadCount++;
          if (returnNull) return null;
          return CourseTeacherIndex.fromSchedules([
            (
              config: _cfg(academicYear: '2024-2025', termName: '秋'),
              courses: [_c('高等数学', '张老师')],
            ),
          ]);
        },
      );

      // 1. 等待初次加载失败完成
      await Future<void>.delayed(Duration.zero);
      expect(loadCount, 1);
      expect(controller.index, isNull);

      // 恢复成功后调用 retryIfNeeded
      returnNull = false;
      controller.retryIfNeeded();
      await Future<void>.delayed(Duration.zero);
      expect(loadCount, 2);
      expect(controller.index, isNotNull);
      expect(
        controller.index!.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '高等数学',
        ),
        '张老师',
      );

      // 2. 索引就绪且无失败时，retryIfNeeded() 为空操作，不调用 loader
      controller.retryIfNeeded();
      await Future<void>.delayed(Duration.zero);
      expect(loadCount, 2);

      // 3. 后续 reload() 失败时保留旧索引，且 needsRetry 为 true，允许 retryIfNeeded() 重试更新
      returnNull = true;
      await controller.reload();
      expect(loadCount, 3);
      expect(controller.index, isNotNull);
      expect(
        controller.index!.getTeacher(
          academicYear: '2024-2025',
          termSeason: '秋',
          courseName: '高等数学',
        ),
        '张老师',
      );

      returnNull = false;
      controller.retryIfNeeded();
      await Future<void>.delayed(Duration.zero);
      expect(loadCount, 4);
      expect(controller.index, isNotNull);

      controller.dispose();
    });

    test(
      'courseDataListenable 监听与合并：触发变更时调度 reload 并更新索引，dispose 后取消监听',
      () async {
        final listenable = ValueNotifier<int>(0);
        var loadCount = 0;
        var teacherName = '初始老师';
        final controller = CourseTeacherIndexController(
          courseDataListenable: listenable,
          loader: ([db]) async {
            loadCount++;
            return CourseTeacherIndex.fromSchedules([
              (
                config: _cfg(academicYear: '2024-2025', termName: '秋'),
                courses: [_c('高等数学', teacherName)],
              ),
            ]);
          },
        );

        await Future<void>.delayed(Duration.zero);
        expect(loadCount, 1);
        expect(
          controller.index?.getTeacher(
            academicYear: '2024-2025',
            termSeason: '秋',
            courseName: '高等数学',
          ),
          '初始老师',
        );

        // 连续触发多次变更，微任务合并为 1 次 reload
        teacherName = '新老师';
        listenable.value = 1;
        listenable.value = 2;
        listenable.value = 3;
        await Future<void>.delayed(Duration.zero);
        expect(loadCount, 2);
        expect(
          controller.index?.getTeacher(
            academicYear: '2024-2025',
            termSeason: '秋',
            courseName: '高等数学',
          ),
          '新老师',
        );

        // dispose 之后触发变更不再 reload
        controller.dispose();
        listenable.value = 4;
        await Future<void>.delayed(Duration.zero);
        expect(loadCount, 2);
      },
    );

    test(
      'CourseProvider courseDataVersion：switchSchedule 不递增，8 个数据修改方法均递增',
      () async {
        final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        addTearDown(() => db.close());
        await db.execute(
          'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE schedules (id TEXT PRIMARY KEY, config_json TEXT NOT NULL)',
        );
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
        final dbService = DatabaseService.forTesting(db);
        final provider = CourseProvider(dbService);
        await Future<void>.delayed(Duration.zero);

        expect(provider.courseDataVersion.value, 0);

        // 1. addSchedule -> version = 1
        final cfg1 = _cfg(id: 's1', semesterName: '2024-2025学年秋');
        await provider.addSchedule(cfg1);
        expect(provider.courseDataVersion.value, 1);

        // 2. addSchedule s2 -> version = 2
        final cfg2 = _cfg(id: 's2', semesterName: '2024-2025学年春');
        await provider.addSchedule(cfg2);
        expect(provider.courseDataVersion.value, 2);

        // switchSchedule 不递增
        await provider.switchSchedule('s1');
        expect(provider.courseDataVersion.value, 2);

        // 3. addCourse -> version = 3
        final course1 = _c('大学物理', '赵老师');
        await provider.addCourse(course1);
        expect(provider.courseDataVersion.value, 3);

        // 4. updateCourse -> version = 4
        final updatedCourse1 = course1.copyWith(teacher: '钱老师');
        await provider.updateCourse(updatedCourse1);
        expect(provider.courseDataVersion.value, 4);

        // 5. deleteCourse -> version = 5
        await provider.deleteCourse(course1.id);
        expect(provider.courseDataVersion.value, 5);

        // 6. updateScheduleConfig -> version = 6
        final updatedCfg = cfg1.copyWith(semesterName: '2024-2025秋季');
        await provider.updateScheduleConfig(updatedCfg);
        expect(provider.courseDataVersion.value, 6);

        // 7. replaceScheduleCourses -> version = 7
        await provider.replaceScheduleCourses('s1', [_c('高等数学', '孙老师')]);
        expect(provider.courseDataVersion.value, 7);

        // 8. deleteSchedule -> version = 8
        await provider.deleteSchedule('s2');
        expect(provider.courseDataVersion.value, 8);

        // 9. clearAllData -> version = 9
        await provider.clearAllData();
        expect(provider.courseDataVersion.value, 9);
      },
    );

    test('CourseProvider.runBatch 合并发布：多操作仅触发一次递增，支持嵌套与异常兜底，空批次不触发', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      addTearDown(() => db.close());
      await db.execute(
        'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE schedules (id TEXT PRIMARY KEY, config_json TEXT NOT NULL)',
      );
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
      final dbService = DatabaseService.forTesting(db);
      final provider = CourseProvider(dbService);
      await Future<void>.delayed(Duration.zero);

      var versionBumpCount = 0;
      provider.courseDataVersion.addListener(() => versionBumpCount++);

      // 1. runBatch 内没有发生写操作，批次结束时不递增
      await provider.runBatch(() async {
        await provider.switchSchedule('unknown');
      });
      expect(provider.courseDataVersion.value, 0);
      expect(versionBumpCount, 0);

      // 2. 批量写操作跨多个 await 仅在最外层批次完成时合并发布一次递增
      final cfg = _cfg(id: 's1', semesterName: '2024-2025学年秋');
      await provider.runBatch(() async {
        await provider.addSchedule(cfg);
        await provider.addCourse(_c('课程1', '教师1'));
        await provider.addCourse(_c('课程2', '教师2'));
        await provider.replaceScheduleCourses('s1', [
          _c('课程1', '教师1-改'),
          _c('课程2', '教师2-改'),
        ]);
        await provider.updateScheduleConfig(
          cfg.copyWith(semesterName: '2024-2025秋'),
        );
        // 在批次执行过程中，版本号尚未发布
        expect(provider.courseDataVersion.value, 0);
      });
      // 批次结束：合并为 1 次递增
      expect(provider.courseDataVersion.value, 1);
      expect(versionBumpCount, 1);

      // 3. 嵌套 runBatch：内层批次不提前发布，最外层批次退出时发布一次
      await provider.runBatch(() async {
        await provider.addCourse(_c('课程3', '教师3'));
        await provider.runBatch(() async {
          await provider.addCourse(_c('课程4', '教师4'));
          expect(provider.courseDataVersion.value, 1);
        });
        expect(provider.courseDataVersion.value, 1);
      });
      expect(provider.courseDataVersion.value, 2);
      expect(versionBumpCount, 2);

      // 4. 批次中途抛出异常但已有写操作落库：finally 依然递增一次保持数据与索引一致
      await expectLater(
        provider.runBatch(() async {
          await provider.addCourse(_c('课程5', '教师5'));
          throw StateError('Simulated error during batch');
        }),
        throwsStateError,
      );
      expect(provider.courseDataVersion.value, 3);
      expect(versionBumpCount, 3);
    });

    test(
      'CourseProvider.updateScheduleConfig 元数据过滤：非学期设置变更不递增，学期元数据变更才递增',
      () async {
        final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        addTearDown(() => db.close());
        await db.execute(
          'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE schedules (id TEXT PRIMARY KEY, config_json TEXT NOT NULL)',
        );
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
        final dbService = DatabaseService.forTesting(db);
        final provider = CourseProvider(dbService);
        await Future<void>.delayed(Duration.zero);

        final initialCfg = _cfg(
          id: 's1',
          academicYear: '2024-2025',
          termName: '秋',
          semesterName: '2024-2025学年秋',
        );
        await provider.addSchedule(initialCfg);
        expect(provider.courseDataVersion.value, 1);

        // 1. 修改非学期设置（总周数、学期开始日期、时间表、作息）：不递增版本号
        final nonMetaCfg1 = initialCfg.copyWith(totalWeeks: 18);
        await provider.updateScheduleConfig(nonMetaCfg1);
        expect(provider.courseDataVersion.value, 1);

        final nonMetaCfg2 = nonMetaCfg1.copyWith(
          semesterStartDate: DateTime(2024, 9, 8),
        );
        await provider.updateScheduleConfig(nonMetaCfg2);
        expect(provider.courseDataVersion.value, 1);

        final nonMetaCfg3 = nonMetaCfg2.copyWith(
          courseDuration: 50,
          breakDuration: 15,
        );
        await provider.updateScheduleConfig(nonMetaCfg3);
        expect(provider.courseDataVersion.value, 1);

        // 2. 修改学期名称：递增
        final metaCfg1 = nonMetaCfg3.copyWith(semesterName: '2024-2025第一学期');
        await provider.updateScheduleConfig(metaCfg1);
        expect(provider.courseDataVersion.value, 2);

        // 3. 修改学年代码：递增
        final metaCfg2 = metaCfg1.copyWith(academicYearCode: '2024-2025-1');
        await provider.updateScheduleConfig(metaCfg2);
        expect(provider.courseDataVersion.value, 3);

        // 4. 修改学期标识：递增
        final metaCfg3 = metaCfg2.copyWith(termName: '秋季学期');
        await provider.updateScheduleConfig(metaCfg3);
        expect(provider.courseDataVersion.value, 4);

        // 5. 原地修改（identical 保护）或未知 scheduleId：递增
        final unknownCfg = _cfg(id: 'unknown_id', semesterName: '新课表');
        await provider.updateScheduleConfig(unknownCfg);
        expect(provider.courseDataVersion.value, 5);
      },
    );

    test(
      'CourseTeacherIndexController 跨 await 尾随合并：加载在途时不并发重载，完成后仅触发一次最新尾随重载',
      () async {
        final reload1Completer = Completer<CourseTeacherIndex?>();
        var loadCount = 0;
        var currentTeacher = '第1代老师';

        final listenable = ValueNotifier<int>(0);
        final controller = CourseTeacherIndexController(
          courseDataListenable: listenable,
          loader: ([db]) {
            loadCount++;
            if (loadCount == 1) {
              return reload1Completer.future;
            }
            return Future.value(
              CourseTeacherIndex.fromSchedules([
                (
                  config: _cfg(academicYear: '2024-2025', termName: '秋'),
                  courses: [_c('高等数学', currentTeacher)],
                ),
              ]),
            );
          },
        );

        // 初始创建触发 reload() #1，进入 in-flight
        expect(loadCount, 1);

        // 在 reload() #1 运行期间，多次触发 scheduleReload() / courseDataListenable 变更
        // 并跨越多个 await / microtask 边界
        currentTeacher = '第2代老师';
        listenable.value = 1;
        await Future<void>.delayed(Duration.zero);
        expect(loadCount, 1);

        currentTeacher = '第3代老师';
        listenable.value = 2;
        controller.scheduleReload();
        await Future<void>.delayed(Duration.zero);
        expect(loadCount, 1);

        currentTeacher = '最新第4代老师';
        listenable.value = 3;
        controller.scheduleReload();
        await Future<void>.delayed(Duration.zero);
        expect(loadCount, 1); // 依然没有发起并发加载！

        // 完成第 1 次加载
        final initialIndex = CourseTeacherIndex.fromSchedules([
          (
            config: _cfg(academicYear: '2024-2025', termName: '秋'),
            courses: [_c('高等数学', '第1代老师')],
          ),
        ]);
        reload1Completer.complete(initialIndex);
        // 等待第 1 次完成及其触发的尾随微任务
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // 仅触发了一次尾随 reload()，loadCount 为 2
        expect(loadCount, 2);
        expect(
          controller.index?.getTeacher(
            academicYear: '2024-2025',
            termSeason: '秋',
            courseName: '高等数学',
          ),
          '最新第4代老师',
        );

        // 后续不再有多余的 reload 请求
        await Future<void>.delayed(Duration.zero);
        expect(loadCount, 2);

        controller.dispose();
      },
    );
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
