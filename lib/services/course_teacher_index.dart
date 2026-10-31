import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/schedule_config.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/app_log.dart';

/// 课程历史教师索引服务。
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

  static CourseTeacherIndex? _cachedInstance;
  static Future<CourseTeacherIndex?>? _buildingFuture;

  /// 索引失效与版本更新通知。
  ///
  /// 当 [invalidate] 被调用时版本号递增，页面可监听此通知自动重新加载最新索引。
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 使当前内存中的教师索引失效。
  ///
  /// 应在课表新增、删除、课程替换、课程编辑以及学期元数据更新后调用。
  static void invalidate() {
    _cachedInstance = null;
    _buildingFuture = null;
    revision.value++;
  }

  /// 测试用：直接注入预先构建好的索引实例。
  @visibleForTesting
  static void setInstanceForTesting(CourseTeacherIndex? instance) {
    _cachedInstance = instance;
    _buildingFuture = null;
    revision.value++;
  }

  /// 获取或异步构建教师索引。
  ///
  /// 优先返回内存缓存；若正在加载中则合并等待请求。
  /// 可传入自定义 [db]，默认从 GetIt 获取已注册的 [DatabaseService]。
  /// 若数据库未就绪或加载失败则记录日志并安全返回 null。
  static Future<CourseTeacherIndex?> load([DatabaseService? db]) async {
    if (_cachedInstance != null) return _cachedInstance;
    if (_buildingFuture != null) return _buildingFuture;

    final future = _safeBuild(db);
    _buildingFuture = future;
    return future;
  }

  static Future<CourseTeacherIndex?> _safeBuild(DatabaseService? db) async {
    try {
      final database = db ?? getIt<DatabaseService>();
      final instance = await _build(database);
      _cachedInstance = instance;
      return instance;
    } catch (e, st) {
      AppLog.e(_tag, '加载教师索引失败', error: e, stackTrace: st);
      return null;
    } finally {
      _buildingFuture = null;
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

  /// 从给定的课表及课程列表构建索引。
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
