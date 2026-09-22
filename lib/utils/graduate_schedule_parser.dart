import 'dart:convert';

import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/class_week_parser.dart';
import 'package:bugaoshan/utils/gs_json_envelope.dart';
import 'package:flutter/material.dart' show Colors, TimeOfDay;

/// 研究生课表解析器（纯函数，无网络 / 无状态）。
///
/// 两个入口，对应两条取数路径：
/// - [graduateCoursesFromJson]：接口路径。输入是裸数组或已确认的 EMAP 信封。
/// - [graduateCoursesFromCapturedJson]：WebView 抓取路径。输入是页面自己的
///   数据请求被钩子记下来的**响应体原文**，结构无法预知，靠形态特征识别。
///
/// **真实字段名仍待最终确认**（TODO(gs-api)）。当前同时兼容金智 EMAP 常见命名
/// （`kcmc` 课程名 / `xm` 教师 / `cdmc` 场地 / `xqj` 星期 / `jcs` 节次 /
/// `zcd` 周次 / `xqmc` 校区）与英文别名（`courseName` / `startWeek` …）。
///
/// 取值一律走宽松 helper 并带取值范围校验：脏数据、位串、全 `null` 字段只会
/// 退化成默认值，不会崩溃，也不会造出第 9999 周的课。
List<Course> graduateCoursesFromJson(Object? json) {
  return assignColorsByName(
    mergeAdjacentSections(gsRows(json).expand(_coursesFromRow).toList()),
  );
}

/// 从 WebView 捕获到的原始响应体里解析课表。
///
/// 每一段响应体都可能是：EMAP 信封、`{"kbList":[…]}` 这类业务对象、或直接
/// 就是数组。所以先按标准信封试（只保留确实像课程的行），失败再退回到
/// [graduateCourseRowsFrom] 做形态识别。
///
/// 同一门课可能出现在多段响应里（页面切周次会重复请求），结果按课程特征去重。
List<Course> graduateCoursesFromCapturedJson(List<String> payloads) {
  final courses = <Course>[];
  for (final raw in payloads) {
    final decoded = _tryDecodeJson(raw);
    if (decoded == null) continue;
    courses.addAll(_coursesFromAnyShape(decoded));
  }
  return assignColorsByName(mergeAdjacentSections(_dedupeCourses(courses)));
}

/// 在任意深度的 JSON 里找「最像课表」的那个对象数组。
///
/// 捕获到的负载结构无法预先知道，因此按**形态特征**找而不是按固定键名找：
/// 收集所有「过半元素都像课程行」的数组，取最长的一个（课表通常是最长的那个，
/// 而学期列表、校区字典之类都很短）。
List<Map<String, dynamic>> graduateCourseRowsFrom(Object? node) {
  final candidates = <List<Map<String, dynamic>>>[];
  _collectCourseRowLists(node, candidates, 0);
  if (candidates.isEmpty) return const [];
  candidates.sort((a, b) => b.length.compareTo(a.length));
  return candidates.first;
}

/// 过滤掉落在课表范围之外的课程（周次 / 节次越界 / 星期非法）。
///
/// 判定标准与本科导入的 `validateImportedSchedule` 一致，区别是**逐条过滤**
/// 而不是抛异常中断整次导入——一条脏数据不该毁掉整张课表。
///
/// 返回保留下来的课程与被丢弃的数量，调用方据此记日志 / 提示用户。
({List<Course> courses, int dropped}) clampGraduateCourses(
  List<Course> courses, {
  required int totalWeeks,
  required int sectionsPerDay,
}) {
  final kept = <Course>[];
  var dropped = 0;
  for (final course in courses) {
    final inRange =
        course.startWeek >= 1 &&
        course.endWeek >= course.startWeek &&
        course.endWeek <= totalWeeks &&
        course.dayOfWeek >= 1 &&
        course.dayOfWeek <= 7 &&
        course.startSection >= 1 &&
        course.endSection >= course.startSection &&
        course.endSection <= sectionsPerDay;
    if (inRange) {
      kept.add(course);
    } else {
      dropped++;
    }
  }
  return (courses: kept, dropped: dropped);
}

/// 单日最大节数（用于挡掉"看着像数字但明显不是节次"的脏数据）。
const int _maxSectionsPerDay = 20;

/// 学期最大周数上限。位串（如 `"1111111100"`）会被当成一个巨大的整数，
/// 靠这个上限挡掉，否则会造出第 1111111100 周的课。
///
/// 直接复用 [kMaxCourseWeeks]，与 [Course] 接受的上界保持单一来源——超过该
/// 上限的周次在模型层也会被丢弃，两处独立定义迟早会漂移。
const int _maxWeeksPerTerm = kMaxCourseWeeks;

/// 形态识别下探的最大深度（负载嵌套不会很深，防御异常结构）。
const int _maxCaptureDepth = 6;

// ── 字段候选键 ────────────────────────────────────────────────────
//
// 顺序即优先级。EMAP 用中文拼音首字母缩写，英文别名兜底；全大写形式是同一
// 列在部分接口里的写法。`xm`/`xq` 这类歧义键只在语义确定的位置使用
// （`xm` 在课表行里是教师姓名，`xq` 沿用既有约定表示星期）。
//
// `rkjs` / `skdd` / `jcdm` / `jsdm` / `jcxx` / `skzs` / `dsz` / `rq` 来自金智
// 研究生系统（gsapp）的课表行——字段名与 WakeUp课程表 反汇编出的 KingoInfo
// 一致：`rkjs` 任课教师、`skdd` 上课地点、`jcdm`/`jsdm` 起止节次（两位零填充
// 代码）、`jcxx` 节次信息文本、`skzs` 上课周数、`dsz` 单双周、`rq` 上课日期
// 或星期文本。
//
// `zcbh` / `kssj` / `jssj` 来自川大研教务（ehall xspkjgcx.do）2026-09-20
// 抓包实测的行字段：`zcbh` 周次位串（逐周上课位图，周次权威源头）、
// `kssj`/`jssj` 每节课起止时刻（形如 800 → 8:00 的分钟数）。

const List<String> _kIdKeys = [
  'id',
  'ID',
  'wid',
  'WID',
  'jxbid',
  'JXBID',
  'skbh',
  'SKBH',
];
const List<String> _kNameKeys = [
  'kcmc',
  'KCMC',
  'courseName',
  'name',
  'kcbm_mc',
  'KCBM_MC',
];
const List<String> _kTeacherKeys = [
  'jsxm',
  'JSXM',
  'xm',
  'XM',
  'teacher',
  'skls',
  'SKLS',
  'jsmc',
  'rkjs',
  'RKJS',
];
const List<String> _kLocationKeys = [
  'cdmc',
  'CDMC',
  'jasmc',
  'JASMC',
  'classroom',
  'location',
  'skdd',
  'SKDD',
];
const List<String> _kCampusKeys = [
  'xqmc',
  'XQMC',
  'cxmc',
  'CXMC',
  'campus',
  'campusName',
];
const List<String> _kDayKeys = [
  'xqj',
  'XQJ',
  'dayOfWeek',
  'xq',
  'XQ',
  'rq',
  'RQ',
];
const List<String> _kSectionRangeKeys = ['jcs', 'JCS', 'jcxx', 'JCXX'];
const List<String> _kStartSectionKeys = [
  'jc',
  'JC',
  'startSection',
  'jcdm',
  'JCDM',
  'ksjcdm',
  'KSJCDM',
];
const List<String> _kEndSectionKeys = [
  'jc1',
  'JC1',
  'endSection',
  'jsdm',
  'JSDM',
  'jsjcdm',
  'JSJCDM',
];
const List<String> _kWeekRangeKeys = [
  'zcbh',
  'ZCBH',
  'zcd',
  'ZCD',
  'zcmc',
  'ZCMC',
  'skzs',
  'SKZS',
];

/// 上课起止时刻（分钟数，形如 800 → 8:00；研教务行内自带，精确于预置作息）。
const List<String> _kClassStartKeys = ['KSSJ', 'kssj'];
const List<String> _kClassEndKeys = ['JSSJ', 'jssj'];
const List<String> _kStartWeekKeys = ['startWeek', 'zc', 'ZC'];
const List<String> _kEndWeekKeys = ['endWeek', 'zc1', 'ZC1'];

/// 单双周标记（金智研究生：`dsz`，取值如「单」/「双」/空）。
const List<String> _kWeekParityKeys = ['dsz', 'DSZ'];

// ── 单行 → Course ─────────────────────────────────────────────────

/// 一行 → 若干门课。
///
/// 之所以是「若干」：周次若为位串（`"1111111100…"`，教务系统常用写法），稀疏
/// 模式无法用单个 `startWeek`/`endWeek` 表达，必须按段拆成多条。这与本科导入
/// （`lib/pages/course/import/jwxt_parser.dart`）的处理方式一致，靠
/// [parseClassWeekSegments] 保证既不凭空增加、也不丢失周次。
List<Course> _coursesFromRow(Map<String, dynamic> json) {
  // 节次：`jcs` 是区间串（"3-4"），`jc` / `jc1` 是分开的起止。
  final sectionRange = _parseNumberRange(
    _firstValue(json, _kSectionRangeKeys),
    max: _maxSectionsPerDay,
  );
  final startSectionOnly = _parseNumberRange(
    _firstValue(json, _kStartSectionKeys),
    max: _maxSectionsPerDay,
  );
  final endSectionOnly = _parseNumberRange(
    _firstValue(json, _kEndSectionKeys),
    max: _maxSectionsPerDay,
  );

  final startSection = sectionRange?.start ?? startSectionOnly?.start ?? 1;
  final endSection = sectionRange?.end ?? endSectionOnly?.end ?? startSection;

  final rowId = _firstString(json, _kIdKeys);
  final segments = _weekSegmentsOf(json);

  return [
    for (var index = 0; index < segments.length; index++)
      Course(
        // 一行拆成多条时必须另起 ID，否则同一 id 会被重复写进库里。
        id: rowId == null
            ? null
            : (segments.length == 1 ? rowId : '${rowId}_$index'),
        name: _firstString(json, _kNameKeys) ?? '',
        teacher: _firstString(json, _kTeacherKeys) ?? '',
        location: _firstString(json, _kLocationKeys) ?? '',
        campus: _firstString(json, _kCampusKeys) ?? '',
        startWeek: segments[index].startWeek,
        endWeek: segments[index].endWeek,
        dayOfWeek: _parseDayOfWeek(json) ?? 1,
        startSection: startSection,
        endSection: endSection,
        colorValue: _firstInt(json, const ['colorValue']) ?? 0,
        weekType: segments[index].weekType,
      ),
  ];
}

/// 星期解析：先按数字取，失败再认中文星期文本。
///
/// 金智研究生接口的 `xq`/`rq` 可能是「星期一」「周一」这类文本；`rq` 也可能
/// 是具体日期（`2025-09-15`），文本匹配不上任何中文星期时会安全返回 null。
int? _parseDayOfWeek(Map<String, dynamic> json) {
  final asInt = _firstInt(json, _kDayKeys);
  if (asInt != null) return asInt;
  final text = _firstString(json, _kDayKeys);
  if (text == null) return null;
  const names = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '日': 7,
    '天': 7,
  };
  for (final entry in names.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return null;
}

/// 周次 → 可精确表达的若干区间。
///
/// 依 [_kWeekRangeKeys] 的优先级逐键尝试：位串（`"1100110011001100"`，
/// 研教务 ZCBH 逐周位图，权威源头）→ 区间串（`"1-16周(单)"`）→ 分开的
/// 起止字段（`zc`/`zc1`）。金智研究生的 `skzs` 通常只给周数区间，单双周
/// 由独立的 `dsz` 字段标记；位串与区间文本自带的「单/双」优先于 `dsz`。
/// 全 0 位串是脏数据（解析不出周次），跳过看下一个候选键。
List<ClassWeekSegment> _weekSegmentsOf(Map<String, dynamic> json) {
  for (final key in _kWeekRangeKeys) {
    final raw = json[key];
    if (raw == null) continue;

    final bitString = _asWeekBitString(raw);
    if (bitString != null) {
      final segments = parseClassWeekSegments(bitString);
      if (segments.isNotEmpty) return segments;
      continue;
    }

    final parity = _weekParityOf(json);
    final range = _parseWeekSpec(raw);
    if (range != null) {
      // 文本未带「单/双」时，`dsz` 是单双周的权威来源；区间文本自带的
      // 情况（`_parseWeekSpec` 已推断）优先级更高，不覆盖。
      final weekType = (range.weekType == WeekType.every && parity != null)
          ? parity
          : range.weekType;
      return [(startWeek: range.start, endWeek: range.end, weekType: weekType)];
    }
  }

  return [
    (
      startWeek: _firstInt(json, _kStartWeekKeys) ?? 1,
      endWeek: _firstInt(json, _kEndWeekKeys) ?? 1,
      weekType: _weekParityOf(json) ?? WeekType.every,
    ),
  ];
}

/// 从 `dsz` 读取单双周标记：含「单」→ 单周，「双」→ 双周，其余 → null。
WeekType? _weekParityOf(Map<String, dynamic> json) {
  final text = _firstString(json, _kWeekParityKeys);
  if (text == null) return null;
  if (text.contains('单')) return WeekType.odd;
  if (text.contains('双')) return WeekType.even;
  return null;
}

/// 识别周次位串：只含 `0`/`1`，且长度像一学期。
///
/// 必须**先于**区间解析判断——位串（第 n 位为 1 表示第 n 周上课）会被数字提取
/// 当成一个巨大的整数。长度下限是为了不和"第 1 周"这种单个数字混淆。
String? _asWeekBitString(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.length < _minWeekBitStringLength ||
      text.length > _maxWeekBitStringLength) {
    return null;
  }
  return _weekBitStringPattern.hasMatch(text) ? text : null;
}

final RegExp _weekBitStringPattern = RegExp(r'^[01]+$');

/// 位串长度下限：更短的 0/1 串更可能只是个周次数字。
const int _minWeekBitStringLength = 8;

/// 位串长度上限：一学期不会比默认周数长太多。
const int _maxWeekBitStringLength = 30;

// ── 形态识别 ──────────────────────────────────────────────────────

/// 是否像一条课程记录：有课程名，且星期 / 节次 / 周次三个信号至少满足两个。
///
/// 金智研究生行不带 EMAP 的 `jcs` 区间和 `zcd` 位串，靠 `jcdm`/`skzs` 提供信号，
/// 「三者取二」能容住个别字段缺失，又不至于把参数表（只有名字）误认为课表。
bool _looksLikeCourseRow(Map<String, dynamic> row) {
  if (_firstString(row, _kNameKeys) == null) return false;
  var signals = 0;
  if (_parseDayOfWeek(row) != null) signals++;
  if (_hasSectionSignal(row)) signals++;
  final rawWeek = _firstValue(row, _kWeekRangeKeys);
  final hasWeek =
      _asWeekBitString(rawWeek) != null || _parseWeekSpec(rawWeek) != null;
  if (hasWeek) signals++;
  return signals >= 2;
}

/// 节次信号：区间串（`jcs`/`jcxx`）或分开的起止键（`jc`/`jc1`、金智的
/// `jcdm`/`jsdm`）任一可解析即可。
bool _hasSectionSignal(Map<String, dynamic> row) {
  final range = _parseNumberRange(
    _firstValue(row, _kSectionRangeKeys),
    max: _maxSectionsPerDay,
  );
  if (range != null) return true;
  final start = _parseNumberRange(
    _firstValue(row, _kStartSectionKeys),
    max: _maxSectionsPerDay,
  );
  final end = _parseNumberRange(
    _firstValue(row, _kEndSectionKeys),
    max: _maxSectionsPerDay,
  );
  return start != null || end != null;
}

List<Course> _coursesFromAnyShape(Object? decoded) {
  final rows = _rowsLenient(decoded).where(_looksLikeCourseRow);
  if (rows.isNotEmpty) return rows.expand(_coursesFromRow).toList();
  return graduateCourseRowsFrom(decoded).expand(_coursesFromRow).toList();
}

/// [gsRows] 的容错版：捕获到的响应里可能混着错误响应，跳过而不是抛出。
List<Map<String, dynamic>> _rowsLenient(Object? decoded) {
  try {
    return gsRows(decoded);
  } on ScuException {
    return const [];
  }
}

void _collectCourseRowLists(
  Object? node,
  List<List<Map<String, dynamic>>> out,
  int depth,
) {
  if (depth > _maxCaptureDepth) return;
  if (node is Map) {
    for (final value in node.values) {
      _collectCourseRowLists(value, out, depth + 1);
    }
    return;
  }
  if (node is! List) return;

  final rows = node.whereType<Map<String, dynamic>>().toList();
  if (rows.isNotEmpty &&
      rows.where(_looksLikeCourseRow).length * 2 > rows.length) {
    out.add(rows);
  }
  for (final value in node) {
    _collectCourseRowLists(value, out, depth + 1);
  }
}

/// 按课程特征去重，保留首次出现的顺序。
List<Course> _dedupeCourses(List<Course> courses) {
  final seen = <String>{};
  final result = <Course>[];
  for (final course in courses) {
    final key = [
      course.name,
      course.teacher,
      course.location,
      course.dayOfWeek,
      course.startSection,
      course.endSection,
      course.startWeek,
      course.endWeek,
      course.weekType.index,
    ].join('|');
    if (seen.add(key)) result.add(course);
  }
  return result;
}

/// 合并同课程同周次的相邻节次。
///
/// 研教务（金智系）返回的课程行是**每节课一行**：同一门「数值分析」
/// 第 2、3、4 节会拆成三条记录，周次/教师/教室完全相同。课表展示与
/// 入库都以「连堂大节」为单位，因此按（课名/教师/地点/校区/星期/
/// 周次/单双周）分组后，把节次区间相邻的行合并成一条（保留首行 ID）；
/// 中间隔节（如只有第 2、4 节）不合并。
List<Course> mergeAdjacentSections(List<Course> courses) {
  String keyOf(Course c) => [
    c.name,
    c.teacher,
    c.location,
    c.campus,
    c.dayOfWeek,
    c.startWeek,
    c.endWeek,
    c.weekType.index,
  ].join('|');

  final groups = <String, List<Course>>{};
  for (final course in courses) {
    groups.putIfAbsent(keyOf(course), () => []).add(course);
  }

  final result = <Course>[];
  for (final group in groups.values) {
    final sorted = [...group]
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
    var current = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      if (next.startSection > current.endSection + 1) {
        // 节次不连续：另一次上课，独立成条
        result.add(current);
        current = next;
      } else if (next.endSection > current.endSection) {
        // 相邻或重叠：扩展结束节次（保留首行 ID）
        current = current.copyWith(endSection: next.endSection);
      }
      // 否则完全被当前区间覆盖，丢弃
    }
    result.add(current);
  }
  return result;
}

// ── 区间与周次解析 ────────────────────────────────────────────────

/// 为课程按**课程名**分配稳定的课表颜色。
///
/// 与本科导入（jwxt_parser）使用同一套调色板（[Colors.primaries]），
/// 按课程名首次出现顺序循环取色——同一门课的多段（不同周次/不同教师）
/// 拿到同一颜色，不同课程颜色互不相同。
List<Course> assignColorsByName(List<Course> courses) {
  final seen = <String, int>{};
  return [
    for (final course in courses)
      course.copyWith(
        colorValue: Colors
            .primaries[seen.putIfAbsent(course.name, () => seen.length) %
                Colors.primaries.length]
            .toARGB32(),
      ),
  ];
}

/// 解析节次表示：`"1-2"`、`"3"`、`"1,2,3"`、`"1-2节"`。
///
/// 取最小值为起、最大值为止。落在 `1..max` 之外的数字整体视为脏数据
/// （返回 null），避免把 `"1234"` 这种值当成第 1234 节。
({int start, int end})? _parseNumberRange(Object? value, {required int max}) {
  final numbers = _extractInts(value).where((n) => n >= 1 && n <= max).toList();
  if (numbers.isEmpty) return null;
  return (
    start: numbers.reduce((a, b) => a < b ? a : b),
    end: numbers.reduce((a, b) => a > b ? a : b),
  );
}

/// 解析周次表示：`"1-16"`、`"1-16周"`、`"1-16周(单)"`、`"1,3,5"`、`"1-8,10-16"`。
///
/// 起止取最小/最大值；含「单」「双」时据此定 [WeekType]，否则按全奇/全偶推断。
/// 稀疏周次（如 `"1,5,9"`）只能近似成首尾区间——[Course] 的模型表达不了，
/// 这是已知的精度损失。
({int start, int end, WeekType weekType})? _parseWeekSpec(Object? value) {
  final numbers = _extractInts(
    value,
  ).where((w) => w >= 1 && w <= _maxWeeksPerTerm).toList();
  if (numbers.isEmpty) return null;

  final text = value.toString();
  final WeekType weekType;
  if (text.contains('单')) {
    weekType = WeekType.odd;
  } else if (text.contains('双')) {
    weekType = WeekType.even;
  } else if (_isContiguousRange(text)) {
    // 「a-b」连续区间：端点的奇偶不代表单双周。线上回归：研教务会把
    // 每周都上课的课写成「3-17周」，两端恰好全奇，按数字推断会被
    // 误标成单周。单双周课程必有显式标记（文本「单/双」或 `dsz` 字段）。
    weekType = WeekType.every;
  } else {
    weekType = _inferWeekType(numbers);
  }

  return (
    start: numbers.reduce((a, b) => a < b ? a : b),
    end: numbers.reduce((a, b) => a > b ? a : b),
    weekType: weekType,
  );
}

/// 是否为单一连续区间的周次文本（`"3-17"`、`"1-16周"`、`"第3-17周"`、
/// `"3-17周(每周)"`）。
///
/// 容忍可选的「第」前缀（两段各自可有）与括号尾注——尾注内容若含「单/双」
/// 已在 [_parseWeekSpec] 提前判定，不会走到这里。逗号分隔的稀疏周次
/// （`"1,3,5"`、`"1-8,10-16"`）不算——那种形态下数字列表本身携带奇偶
/// 信息，仍交给 [_inferWeekType] 推断。
bool _isContiguousRange(String text) => _contiguousRangePattern.hasMatch(text);

final RegExp _contiguousRangePattern = RegExp(
  r'^\s*第?\s*\d+\s*周?\s*[-–—]\s*第?\s*\d+\s*周?\s*(?:（[^）]*）|\([^)]*\))?\s*$',
);

/// 全奇数 → 单周，全偶数 → 双周，其余 → 每周。单个周次不构成交替规律。
WeekType _inferWeekType(List<int> weeks) {
  if (weeks.length < 2) return WeekType.every;
  if (weeks.every((w) => w.isOdd)) return WeekType.odd;
  if (weeks.every((w) => w.isEven)) return WeekType.even;
  return WeekType.every;
}

/// 抽出值里的所有整数。`"1-16周"` → `[1, 16]`，`3` → `[3]`，其余 → `[]`。
List<int> _extractInts(Object? value) {
  if (value == null) return const [];
  if (value is int) return [value];
  if (value is num) return [value.toInt()];
  return RegExp(
    r'\d+',
  ).allMatches(value.toString()).map((m) => int.parse(m.group(0)!)).toList();
}

// ── 宽松取值 ──────────────────────────────────────────────────────

Object? _firstValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  final text = _firstValue(json, keys)?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

int? _firstInt(Map<String, dynamic> json, List<String> keys) =>
    _toInt(_firstValue(json, keys));

int? _toInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

// ── 接口精确时刻（KSSJ / JSSJ）───────────────────────────────────

/// 从研教务课表行生成该课表专属的每节起止时刻表。
///
/// `xspkjgcx.do` 每行带 `KSSJ` / `JSSJ`（形如 800 → 8:00 的分钟数，与
/// 节次代码 KSJCDM/JSJCDM 一一对应）：节次起点取「该行起始节 → 该行
/// KSSJ」，终点同理。同一节次多行观测投票取众数；未观测到的节次用
/// [fallback]（通常是望江/华西预置作息）补齐，保证返回长度与 [fallback]
/// 一致。没有任何可用时刻时返回 null，调用方沿用预置。
List<TimeSlot>? graduateTimeSlotsFromRows(
  List<Map<String, dynamic>> rows, {
  required List<TimeSlot> fallback,
}) {
  // section -> {时刻(分钟数): 票数}
  final startVotes = <int, Map<int, int>>{};
  final endVotes = <int, Map<int, int>>{};
  for (final row in rows) {
    final startSection = _firstInt(row, _kStartSectionKeys);
    final endSection = _firstInt(row, _kEndSectionKeys);
    final startMinute = _classMinuteOf(row, _kClassStartKeys);
    final endMinute = _classMinuteOf(row, _kClassEndKeys);
    if (startSection != null && startMinute != null) {
      startVotes.putIfAbsent(startSection, () => {})[startMinute] =
          (startVotes[startSection]?[startMinute] ?? 0) + 1;
    }
    if (endSection != null && endMinute != null) {
      endVotes.putIfAbsent(endSection, () => {})[endMinute] =
          (endVotes[endSection]?[endMinute] ?? 0) + 1;
    }
  }
  if (startVotes.isEmpty && endVotes.isEmpty) return null;

  return [
    for (var index = 0; index < fallback.length; index++)
      _observedOrDefault(startVotes, endVotes, index, fallback[index]),
  ];
}

/// 单个节次：观测到起止且起在止前 → 用观测值，否则用预置。
TimeSlot _observedOrDefault(
  Map<int, Map<int, int>> startVotes,
  Map<int, Map<int, int>> endVotes,
  int index,
  TimeSlot preset,
) {
  final section = index + 1;
  final start = _majorityMinute(startVotes[section]);
  final end = _majorityMinute(endVotes[section]);
  if (start == null || end == null || start >= end) return preset;
  return TimeSlot(
    startTime: _timeOfDayOfMinutes(start),
    endTime: _timeOfDayOfMinutes(end),
  );
}

/// 时刻字段换算与校验：形如 800 → 8:00、1045 → 10:45。
/// 分钟位 ≥60、小时位 ≥24 或负数视为脏数据返回 null。
int? _classMinuteOf(Map<String, dynamic> json, List<String> keys) {
  final raw = _firstInt(json, keys);
  if (raw == null || raw < 0 || raw >= 2400 || raw % 100 >= 60) return null;
  return raw;
}

TimeOfDay _timeOfDayOfMinutes(int minutes) =>
    TimeOfDay(hour: minutes ~/ 100, minute: minutes % 100);

/// 多行观测投票取众数（并列时取先观测到的时刻）。
int? _majorityMinute(Map<int, int>? votes) {
  if (votes == null || votes.isEmpty) return null;
  final sorted = votes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.first.key;
}

// ── 学期起始日 ────────────────────────────────────────────────────

/// 从「首次上课日期」行推算学期第 1 周周一。
///
/// 输入是研教务 `xsjxrwcx.do` 的行（已解包），每行含：
/// - `SCSKRQ`：该教学班首次上课日期（如 `2026-09-14`）；
/// - `PKSJ`：排课时间文本，起始周在段首（如 `3-14周 星期一[05-08节]`）。
///
/// 第 1 周周一 = SCSKRQ − (起始周−1)×7 天，再回退到当周周一
/// （首次上课日未必是周一，如波谱分析首课在周三）。多行投票取众数，
/// 个别脏行（日期解析失败 / 周次缺失）自动忽略。
DateTime? semesterStartMondayFromFirstClassRows(List<dynamic> rows) {
  final votes = <DateTime, int>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final dateText = row['SCSKRQ']?.toString().trim();
    final pksj = row['PKSJ']?.toString().trim() ?? '';
    final startWeekMatch = RegExp(r'^\s*(\d+)').firstMatch(pksj);
    if (dateText == null || dateText.isEmpty || startWeekMatch == null) {
      continue;
    }
    final firstClass = DateTime.tryParse(dateText);
    final startWeek = int.tryParse(startWeekMatch.group(1)!);
    if (firstClass == null || startWeek == null || startWeek < 1) continue;

    final sameWeekdayInWeek1 = DateTime(
      firstClass.year,
      firstClass.month,
      firstClass.day - (startWeek - 1) * 7,
    );
    final monday = DateTime(
      sameWeekdayInWeek1.year,
      sameWeekdayInWeek1.month,
      sameWeekdayInWeek1.day - (sameWeekdayInWeek1.weekday - 1),
    );
    final day = DateTime(monday.year, monday.month, monday.day);
    votes[day] = (votes[day] ?? 0) + 1;
  }
  if (votes.isEmpty) return null;
  DateTime best = votes.keys.first;
  var bestCount = -1;
  votes.forEach((day, count) {
    if (count > bestCount) {
      best = day;
      bestCount = count;
    }
  });
  return best;
}

Object? _tryDecodeJson(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}
