/// 第二课堂活动的「学生视角」状态判定。
///
/// 服务端 `status` / `statusName` / `doing` / `subscribed` 在不同端点之间
/// 口径不一致（同一活动在列表里 `doing=false`、详情里 `doing=true`；尚未
/// 开始的活动也可能显示进行中），因此凡是时间窗能判定的，一律以时间窗
/// 为准（见 issue #339）。搜索列表与子活动列表共用同一套判断逻辑：
///
/// 1. 已预约          —— 服务端 `subscribed == true`，直接显示；
/// 2. 报名中·进行中   —— 报名时段 / 活动时段分别独立匹配，可同时展示；
/// 3. 未开始          —— 时间窗都未命中，且能明确判定「在当前时间之后」：
///    活动开始时间或报名开始时间可解析且在未来；
/// 4. 已结束          —— 活动结束时间可解析且已过；
/// 5. 报名中 / 可预约 —— 其余情况（时间信息不完整等）回退服务端 `doing`：
///    负责人已开始活动按「报名中」展示，否则按「可预约」展示。
library;

import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/utils/beijing_time.dart';

/// 学生视角的活动状态。
enum CcylActivityPhase {
  /// 已预约（服务端 `subscribed == true`）。
  subscribed,

  /// 可预约（时间窗无法判定时的服务端兜底：`doing == false`）。
  available,

  /// 报名时段命中。
  enrolling,

  /// 活动时段命中。
  ongoing,

  /// 未开始：活动开始时间或报名开始时间可解析且在未来。
  notStarted,

  /// 已结束：活动结束时间可解析且已过。
  ended,
}

/// 返回条目应展示的状态标签（1~2 个）。
///
/// [now] 传本地时刻即可，内部统一转为 UTC 即时比较。
List<CcylActivityPhase> resolveCcylActivityPhases(
  CyclActivity activity, {
  DateTime? now,
}) {
  return resolveCcylActivityPhasesFromTimes(
    doing: activity.doing,
    subscribed: activity.subscribed,
    enrollStartTime: activity.enrollStartTime,
    enrollEndTime: activity.enrollEndTime,
    startTime: activity.startTime,
    endTime: activity.endTime,
    now: now,
  );
}

/// [resolveCcylActivityPhases] 的纯参数版本，便于单测。
List<CcylActivityPhase> resolveCcylActivityPhasesFromTimes({
  bool doing = false,
  bool subscribed = false,
  String? enrollStartTime,
  String? enrollEndTime,
  String? startTime,
  String? endTime,
  DateTime? now,
}) {
  // 已预约含义明确，直接沿用服务端口径。
  if (subscribed) return const [CcylActivityPhase.subscribed];

  // 时间窗能判定的优先（服务端 doing 在不同端点间不一致，不可作为依据）。
  final instant = (now ?? DateTime.now()).toUtc();
  final enrollStart = parseCcylServerTime(enrollStartTime);
  final enrollEnd = parseCcylServerTime(enrollEndTime);
  final activityStart = parseCcylServerTime(startTime);
  final activityEnd = parseCcylServerTime(endTime);

  final phases = <CcylActivityPhase>[
    if (_matchesWindow(enrollStart, enrollEnd, instant))
      CcylActivityPhase.enrolling,
    if (_matchesWindow(activityStart, activityEnd, instant))
      CcylActivityPhase.ongoing,
  ];
  if (phases.isNotEmpty) return phases;

  // 都未命中：能明确判定「在当前时间之后」（未开始）或「已结束」时显示
  // 对应状态；系列活动的列表条目往往不携带各场次的时间段（子活动各自
  // 报名），此时回退服务端 doing：已开始活动按「报名中」，否则按「可预约」。
  if (activityEnd != null && instant.isAfter(activityEnd)) {
    return const [CcylActivityPhase.ended];
  }
  if (activityStart != null && instant.isBefore(activityStart)) {
    return const [CcylActivityPhase.notStarted];
  }
  if (enrollStart != null && instant.isBefore(enrollStart)) {
    return const [CcylActivityPhase.notStarted];
  }
  return doing
      ? const [CcylActivityPhase.enrolling]
      : const [CcylActivityPhase.available];
}

/// 系列条目的状态是否为乐观兜底（自身时间信息不足以判定）。
///
/// 恰为 [resolveCcylActivityPhasesFromTimes] 走到 `doing` 回退分支的情形：
/// 报名/活动时间窗都未命中，也无法明确判定未开始/已结束。此时系列条目
/// 展示的「报名中/可预约」只是猜测，需要场次数据（`get-lib-detail`）才能
/// 确定真实状态——两个维护点必须同步修改。
bool isCcylSeriesPhaseAmbiguous(CyclActivity activity, {DateTime? now}) {
  if (activity.subscribed || !activity.doing) return false;
  final instant = (now ?? DateTime.now()).toUtc();
  final enrollStart = parseCcylServerTime(activity.enrollStartTime);
  final enrollEnd = parseCcylServerTime(activity.enrollEndTime);
  final activityStart = parseCcylServerTime(activity.startTime);
  final activityEnd = parseCcylServerTime(activity.endTime);
  if (_matchesWindow(enrollStart, enrollEnd, instant)) return false;
  if (_matchesWindow(activityStart, activityEnd, instant)) return false;
  if (activityEnd != null && instant.isAfter(activityEnd)) return false;
  if (activityStart != null && instant.isBefore(activityStart)) return false;
  if (enrollStart != null && instant.isBefore(enrollStart)) return false;
  return true;
}

/// 由各场次状态归并出系列状态：报名中/进行中优先（可并存），
/// 其次未开始，再次已结束；空场次列表或场次状态无有效信息时返回空列表
/// （由调用方保留原兜底状态）。
///
/// 系列详情页用它回传给上层列表，搜索列表也用它做后台校准
/// （见 `ActivityLibDetailPage.onSubActivitiesResolved`）。
List<CcylActivityPhase> mergeCcylSeriesPhases(
  Iterable<CyclActivity> subs, {
  DateTime? now,
}) {
  final union = <CcylActivityPhase>{};
  for (final sub in subs) {
    union.addAll(resolveCcylActivityPhases(sub, now: now));
  }
  if (union.contains(CcylActivityPhase.enrolling) ||
      union.contains(CcylActivityPhase.ongoing)) {
    return [
      if (union.contains(CcylActivityPhase.enrolling))
        CcylActivityPhase.enrolling,
      if (union.contains(CcylActivityPhase.ongoing)) CcylActivityPhase.ongoing,
    ];
  }
  if (union.contains(CcylActivityPhase.notStarted)) {
    return const [CcylActivityPhase.notStarted];
  }
  if (union.contains(CcylActivityPhase.ended)) {
    return const [CcylActivityPhase.ended];
  }
  return const [];
}

/// 解析服务端时间字符串为 UTC 即时；无法解析时返回 null。
///
/// 服务端时间为北京时间墙钟字符串（如 `2026-09-20 14:00:00`），与设备时区
/// 无关——统一按 UTC+8 解释，境外设备上也得到正确结论。兼容三种输入：
/// 纯数字时间戳（秒/毫秒）、带时区标记的 ISO 串、以及上述墙钟字符串
///（`/` 分隔与日期only 也一并兼容）。
DateTime? parseCcylServerTime(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  if (_epochPattern.hasMatch(value)) {
    final millis = value.length >= 13
        ? int.parse(value)
        : int.parse(value) * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis).toUtc();
  }
  if (_tzSuffixPattern.hasMatch(value)) {
    return DateTime.tryParse(value)?.toUtc();
  }

  final normalized = value.replaceAll('/', '-');
  final match = _wallClockPattern.firstMatch(normalized);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4) ?? '0');
  final minute = int.parse(match.group(5) ?? '0');
  final second = int.parse(match.group(6) ?? '0');

  // DateTime.tryParse 对溢出字段（如 2026-13-40）会静默进位，这里显式校验。
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > _daysInMonth(year, month)) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;

  return beijingDateToUtc(
    year,
    month,
    day,
    hour: hour,
    minute: minute,
    second: second,
  );
}

final RegExp _epochPattern = RegExp(r'^\d{10,14}$');
final RegExp _tzSuffixPattern = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$');
final RegExp _wallClockPattern = RegExp(
  r'^(\d{4})-(\d{1,2})-(\d{1,2})'
  r'(?:[T ](\d{1,2}):(\d{1,2})(?::(\d{1,2})(?:\.\d+)?)?)?$',
);

int _daysInMonth(int year, int month) {
  if (month == 12) return 31;
  return DateTime.utc(year, month + 1, 0).day;
}

/// 宽松窗口匹配：任一侧时间可解析即可参与判定，缺省一侧视为不设限。
///
/// 含多个时间段子活动的系列活动条目，服务端往往只返回其中一个场次的时间、
/// 或仅起/止一侧。按 issue #339 的口径「多时段子活动优先显示报名中/进行中
/// 而不是未开始」，只有能明确排除时才判负：
/// - 两侧都无法解析 → 无法判定 → 不命中；
/// - 当前时刻早于可解析的开始时间 → 明确未开始 → 不命中；
/// - 当前时刻晚于可解析的结束时间 → 明确已结束 → 不命中；
/// - 其余情况（含单侧缺失、时间段之间的空档）→ 命中。
bool _matchesWindow(DateTime? start, DateTime? end, DateTime now) {
  if (start == null && end == null) return false;
  if (start != null && now.isBefore(start)) return false;
  if (end != null && now.isAfter(end)) return false;
  return true;
}
