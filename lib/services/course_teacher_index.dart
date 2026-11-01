import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/schedule_config.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/app_log.dart';

/// 课程历史教师索引。
///
/// 利用用户已导入的历史课表数据，为成绩页和培养方案完成度页提供
/// 基于「学期 + 归一化课程名」的已修课程授课教师映射。
class CourseTeacherIndex {
  static const String _tag = 'CourseTeacherIndex';

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
    return stripCourseSequenceSuffix(
      rawName
          .trim()
          .replaceAll('（', '(')
          .replaceAll('）', ')')
          .replaceAll('—', '-')
          .replaceAll('－', '-'),
    ).trim();
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

  /// 教师字符串拆分、清理与去重，保留教务处返回的先后顺序。
  static List<String> parseTeachers(String rawTeacher) {
    final trimmed = rawTeacher.trim();
    if (trimmed.isEmpty) return const [];
    final seen = <String>{};
    return trimmed
        .split(_teacherSplitRegExp)
        .where((s) => s.isNotEmpty)
        .where(seen.add)
        .toList();
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
  ///   「大二上」等不含学年学期的名称，该学期将降级为不展示教师；
  /// - 同一学期内同名课程若存在多个不同教师组合（如公共课多班次），
  ///   视为歧义并不展示教师（返回 null），避免错误猜测。
  factory CourseTeacherIndex.fromSchedules(
    List<({ScheduleConfig config, List<Course> courses})> schedules,
  ) {
    // 每个课程键保存“规范化签名 -> 首次出现时的显示顺序”。
    // 规范化签名用于识别不同班次/记录的教师组合是否一致，显示值保留
    // 教务处返回的主讲教师、助教先后顺序。
    final candidateSignatures = <String, Map<String, String>>{};

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
        final canonicalSignature = [...teachers]..sort();
        final canonicalKey = canonicalSignature.join('、');
        final key = '$termKey::$normName';
        (candidateSignatures[key] ??= {})[canonicalKey] ??= teacherSignature;

        // 为体育专项课建立规范化别名索引（如「体育-1气排球」建立「体育-1」别名，且「体育-10」不误匹配「体育-1」）
        final peMatch = _peCourseRegExp.firstMatch(normName);
        if (peMatch != null) {
          final peKey = '$termKey::体育-${peMatch[1]}';
          if (peKey != key) {
            (candidateSignatures[peKey] ??= {})[canonicalKey] ??=
                teacherSignature;
          }
        }
      }
    }

    // 同学期同名课若存在多个不同教师组合（常见于大学英语、体育等公共课
    // 的多班次），无法从成绩接口得知具体班级，安全起见不猜测，整项不展示。
    return CourseTeacherIndex._({
      for (final entry in candidateSignatures.entries)
        if (entry.value.length == 1) entry.key: entry.value.values.first,
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
/// 在其 State 中创建与销毁）。
/// 仅监听课程数据变更（[CourseProvider.courseDataVersion] 或注入的 [courseDataListenable]）
/// 并通过 [scheduleReload] 更新，避免把与课表无关的成绩/培养方案刷新误当成索引失效信号。
/// 支持 [retryIfNeeded] 在初次或先前数据库加载失败后恢复索引，而在索引已就绪时不会产生多余查询。
/// 支持微任务合并连续变更、异步竞态守卫与页面卸载守卫。
class CourseTeacherIndexController extends ChangeNotifier {
  static const String _tag = 'CourseTeacherIndexController';

  CourseTeacherIndexController({
    DatabaseService? database,
    CourseTeacherIndex? initialIndex,
    Future<CourseTeacherIndex?> Function([DatabaseService? db])? loader,
    Listenable? courseDataListenable,
  }) : _database = database,
       _loader = loader ?? CourseTeacherIndex.load,
       _index = initialIndex {
    if (courseDataListenable != null) {
      _attachCourseDataListenable(courseDataListenable);
    } else if (database == null &&
        loader == null &&
        getIt.isRegistered<CourseProvider>()) {
      bool isReady = false;
      try {
        isReady = getIt.isReadySync<CourseProvider>();
      } catch (_) {
        // 同步注册的单例在 isReadySync 时会抛出 ArgumentError，直接视为已就绪
        isReady = true;
      }
      if (isReady) {
        _attachCourseDataListenable(getIt<CourseProvider>().courseDataVersion);
      } else {
        unawaited(_bindAsyncCourseProvider());
      }
    }
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
  bool _latestInFlight = false;
  bool _reloadPendingAfterInFlight = false;
  bool _needsRetry = false;
  Listenable? _courseDataListenable;

  void _attachCourseDataListenable(Listenable listenable) {
    _courseDataListenable = listenable;
    listenable.addListener(_onCourseDataChanged);
  }

  void _onCourseDataChanged() => scheduleReload();

  Future<void> _bindAsyncCourseProvider() async {
    try {
      await getIt.isReady<CourseProvider>();
    } catch (_) {
      return;
    }
    if (_disposed ||
        _courseDataListenable != null ||
        !getIt.isRegistered<CourseProvider>()) {
      return;
    }
    _attachCourseDataListenable(getIt<CourseProvider>().courseDataVersion);
    retryIfNeeded();
  }

  /// 当前已就绪的教师索引；若尚未加载完成或加载失败则为 null。
  CourseTeacherIndex? get index => _index;

  /// 调度微任务合并同一事件循环内的多次重新加载请求。
  ///
  /// 若当前已有加载正在进行中（[_latestInFlight] 为 true），则仅置位
  /// [_reloadPendingAfterInFlight]，在该次加载完成后由 finally 块触发一次尾随重载，
  /// 避免并发多路重载引发无意义的重叠全表扫描。
  void scheduleReload() {
    if (_disposed || _reloadScheduled) return;
    if (_latestInFlight) {
      _reloadPendingAfterInFlight = true;
      return;
    }
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      if (_disposed) return;
      if (_latestInFlight) {
        _reloadPendingAfterInFlight = true;
        return;
      }
      unawaited(reload());
    });
  }

  /// 若初次加载或最近一次重载失败（[_needsRetry] 为 true 或 [index] 仍为 null），
  /// 且当前最新一代加载未在进行中，则通过 [scheduleReload] 触发一次重试。
  ///
  /// 索引已正常就绪时调用为空操作，不会在课表未变更时产生额外数据库查询。
  void retryIfNeeded() {
    if (_disposed || (!_needsRetry && _index != null) || _latestInFlight) {
      return;
    }
    scheduleReload();
  }

  /// 重新从数据库加载教师索引。
  ///
  /// 具备异步竞态守卫：若加载期间有更新的请求发起，较早发起的请求结果将被丢弃。
  Future<void> reload() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _latestInFlight = true;
    CourseTeacherIndex? loaded;
    try {
      loaded = await _loader(_database);
    } catch (e, st) {
      if (!_disposed && generation == _loadGeneration) {
        _needsRetry = true;
      }
      AppLog.e(_tag, '重新加载教师索引失败', error: e, stackTrace: st);
      return;
    } finally {
      if (generation == _loadGeneration) {
        _latestInFlight = false;
        final shouldScheduleTrailing =
            _reloadPendingAfterInFlight && !_disposed;
        _reloadPendingAfterInFlight = false;
        if (shouldScheduleTrailing) {
          scheduleReload();
        }
      }
    }
    if (_disposed || generation != _loadGeneration) return;

    if (loaded == null) {
      _needsRetry = true;
      return;
    }

    _needsRetry = false;
    if (!identical(_index, loaded)) {
      _index = loaded;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reloadPendingAfterInFlight = false;
    _courseDataListenable?.removeListener(_onCourseDataChanged);
    _courseDataListenable = null;
    _index = null;
    super.dispose();
  }
}
