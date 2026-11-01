import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/schedule_config.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/app_log.dart';

/// 课程历史教师索引。
///
/// 利用用户已导入的历史课表数据，为成绩页和培养方案完成度页提供
/// 基于「学期 + 归一化课程名」的已修课程授课教师映射。
class CourseTeacherIndex {
  static const String _tag = 'CourseTeacherIndex';

  static final _courseNumberSuffixRegExp = RegExp(r'\s+\([A-Za-z0-9]*\)\s*$');
  static final _teacherSplitRegExp = RegExp(r'[,，、;\s/；]+');
  static final _gradeDateRegExp = RegExp(
    r'(?:^|[^\d])(20\d{2})(0[1-9]|1[0-2])\d{2}(?:[^\d]|$)',
  );
  static final _peCourseRegExp = RegExp(r'^体育-(\d+)');

  // Key: '${termKey}::${normalizedCourseName}' -> Value: '教师A' 或 '教师A、教师B'
  final Map<String, String> _index;

  CourseTeacherIndex._(this._index);

  /// 纯无状态构建教师索引（不缓存静态实例）。
  ///
  /// 若传入 [db] 则使用 [db]；否则直接从 GetIt 获取已注册的 [DatabaseService]。
  /// 若加载失败则记录日志并安全返回 null。
  static Future<CourseTeacherIndex?> load([DatabaseService? db]) async {
    try {
      final database = db ?? getIt<DatabaseService>();
      return await _build(database);
    } catch (e, st) {
      AppLog.e(_tag, '加载教师索引失败', error: e, stackTrace: st);
      return null;
    }
  }

  static Future<CourseTeacherIndex> _build(DatabaseService db) async {
    final schedules = db.getAllSchedules();
    final scheduleData = await Future.wait(
      schedules.map(
        (s) async =>
            (config: s, courses: await db.getCoursesAsync(scheduleId: s.id)),
      ),
    );
    return CourseTeacherIndex.fromSchedules(scheduleData);
  }

  /// 归一化课程名：
  /// 1. 统一全角括号为半角括号，统一破折号；
  /// 2. 剥除由教务解析器追加的课序号后缀，如 ' (01)', ' (101)', ' (A1)', ' ()'；
  /// 3. 去除首尾空白。
  static String normalizeCourseName(String rawName) {
    return rawName
        .trim()
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('—', '-')
        .replaceAll('－', '-')
        .replaceFirst(_courseNumberSuffixRegExp, '');
  }

  /// 归一化学期标识，格式形如 '2024-2025_秋' 或 '2024-2025_春'。
  ///
  /// 优先使用明确的 [academicYear] 与 [termSeason]；若缺失则从 [rawTermLabel] 中提取。
  static String? normalizeTerm({
    String? academicYear,
    String? termSeason,
    String? rawTermLabel,
  }) {
    final year =
        matchAcademicYear(academicYear) ?? matchAcademicYear(rawTermLabel);
    final season =
        resolveTermSeason(termSeason) ?? resolveTermSeason(rawTermLabel);

    return (year != null && season != null) ? '${year}_$season' : null;
  }

  /// 教师字符串拆分、清理与去重排序。
  static List<String> parseTeachers(String rawTeacher) {
    final trimmed = rawTeacher.trim();
    if (trimmed.isEmpty) return const [];
    final set = trimmed
        .split(_teacherSplitRegExp)
        .where((s) => s.isNotEmpty)
        .toSet();
    return set.toList()..sort();
  }

  /// 从成绩日期代码（如 '20260115'）推断实际开课学期标识（如 '2025-2026_秋'）。
  ///
  /// 四川大学学年学期时间窗口规律：
  /// - 9月至12月、次年1月至2月录入的成绩对应秋季学期；
  /// - 3月至8月录入的成绩对应春季学期。
  static String? termFromGradeDate(String text) {
    final match = _gradeDateRegExp.firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);

    final startYear = month >= 9 ? year : year - 1;
    final season = (month >= 9 || month <= 2) ? '秋' : '春';
    return '$startYear-${startYear + 1}_$season';
  }

  /// 从给定的课表及课程列表构建不可变索引。
  ///
  /// 降级路径说明：
  /// - 教务在线导入的课表带有 [ScheduleConfig.academicYearCode] 与
  ///   [ScheduleConfig.termName]，重命名课表不会影响匹配；
  /// - 手动新建、历史旧数据或旧版分享 JSON 导入的课表仅能通过
  ///   [ScheduleConfig.semesterName] 解析学期；若用户将其重命名为
  ///   「大二上」等不含学年学期的名称，该学期将降级为不展示教师。
  factory CourseTeacherIndex.fromSchedules(
    List<({ScheduleConfig config, List<Course> courses})> schedules,
  ) {
    final candidateSignatures = <String, Set<String>>{};

    for (final schedule in schedules) {
      final termKey = normalizeTerm(
        academicYear: schedule.config.academicYearCode,
        termSeason: schedule.config.termName,
        rawTermLabel: schedule.config.semesterName,
      );
      if (termKey == null) continue;

      for (final course in schedule.courses) {
        final teachers = parseTeachers(course.teacher);
        if (teachers.isEmpty) continue;

        final normName = normalizeCourseName(course.name);
        if (normName.isEmpty) continue;

        final teacherSignature = teachers.join('、');
        final key = '$termKey::$normName';
        (candidateSignatures[key] ??= {}).add(teacherSignature);

        // 为体育专项课建立规范化别名索引（如「体育-1气排球」建立「体育-1」别名，且「体育-10」不误匹配「体育-1」）
        final peMatch = _peCourseRegExp.firstMatch(normName);
        if (peMatch != null) {
          final peKey = '$termKey::体育-${peMatch[1]}';
          if (peKey != key) {
            (candidateSignatures[peKey] ??= {}).add(teacherSignature);
          }
        }
      }
    }

    return CourseTeacherIndex._({
      for (final entry in candidateSignatures.entries)
        if (entry.value.length == 1) entry.key: entry.value.first,
    });
  }

  /// 查询指定学期与课程的授课教师。
  String? getTeacher({
    String? academicYear,
    String? termSeason,
    String? rawTermLabel,
    String? gradeInfo,
    required String courseName,
  }) {
    final normName = normalizeCourseName(courseName);
    if (normName.isEmpty) return null;

    // 1. 优先使用显式指定的学年/学期或原始标签匹配
    final termKey = normalizeTerm(
      academicYear: academicYear,
      termSeason: termSeason,
      rawTermLabel: rawTermLabel,
    );

    if (termKey != null) {
      final direct = _lookup(termKey, normName);
      if (direct != null) return direct;
    }

    // 2. 方案修读页面的选修课/自选课：以 gradeInfo 里的真实成绩录入时间戳推导实际修读学期兜底
    if (gradeInfo != null) {
      final derivedTermKey = termFromGradeDate(gradeInfo);
      if (derivedTermKey != null && derivedTermKey != termKey) {
        return _lookup(derivedTermKey, normName);
      }
    }

    return null;
  }

  String? _lookup(String termKey, String normName) =>
      _index['$termKey::$normName'];
}

/// 页面级课程教师索引控制器。
///
/// 生命周期严格绑定于所属页面（由 [GradesPage] 或 [PlanCompletionPage]
/// 在其 State 中创建与销毁），作为 API 数据的派生状态存在。
/// 不监听任何全局 Provider；由所在页面在接口数据（成绩、培养方案）发生变更时触发重新加载。
/// 支持微任务合并连续变更、异步竞态守卫与页面卸载守卫。
class CourseTeacherIndexController extends ChangeNotifier {
  CourseTeacherIndexController({
    DatabaseService? database,
    CourseTeacherIndex? initialIndex,
    Future<CourseTeacherIndex?> Function([DatabaseService? db])? loader,
  }) : _database = database,
       _loader = loader ?? CourseTeacherIndex.load,
       _index = initialIndex {
    if (initialIndex == null) {
      unawaited(reload());
    }
  }

  final DatabaseService? _database;
  final Future<CourseTeacherIndex?> Function([DatabaseService? db]) _loader;

  CourseTeacherIndex? _index;
  int _loadGeneration = 0;
  bool _reloadScheduled = false;
  bool _disposed = false;

  /// 当前已就绪的教师索引；若尚未加载完成或加载失败则为 null。
  CourseTeacherIndex? get index => _index;

  /// 调度微任务合并同一事件循环内的多次重新加载请求。
  void scheduleReload() {
    if (_disposed || _reloadScheduled) return;
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      if (!_disposed) {
        unawaited(reload());
      }
    });
  }

  /// 重新从数据库加载教师索引。
  ///
  /// 具备异步竞态守卫：若加载期间有更新的请求发起，较早发起的请求结果将被丢弃。
  Future<void> reload() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    final loaded = await _loader(_database);
    if (_disposed || generation != _loadGeneration) return;

    if (!identical(_index, loaded)) {
      _index = loaded;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _index = null;
    super.dispose();
  }
}
