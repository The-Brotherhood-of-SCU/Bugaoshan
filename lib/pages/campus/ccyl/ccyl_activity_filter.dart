/// 活动搜索页的筛选条件（issue #339）。
///
/// - [level]（院/校级）、[org]（主办方）直接透传给
///   `list-activity-library` 的服务端参数，由服务端过滤；
/// - [phases]（状态）与 [minClassHour]（学时）为本地筛选，作用于已加载
///   条目——接口没有学时参数，而学生视角的状态本身就在客户端推算。
library;

import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_phase.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';

/// 活动等级筛选选项（code 透传服务端，name 用于展示）。
class CcylLevelOption {
  final String code;
  final String name;

  const CcylLevelOption({required this.code, required this.name});
}

/// 筛选条件集合。[CcylActivityFilter.empty] 表示不筛选。
class CcylActivityFilter {
  /// 命中的状态集合（多选；空 = 不限）。
  final Set<CcylActivityPhase> phases;

  /// 最低学时（0 = 不限）。
  final int minClassHour;

  /// 活动等级 code（'' = 不限）。
  final String level;

  /// 主办方组织编号（'' = 不限）。
  final String org;

  const CcylActivityFilter({
    this.phases = const {},
    this.minClassHour = 0,
    this.level = '',
    this.org = '',
  });

  static const CcylActivityFilter empty = CcylActivityFilter();

  /// 是否启用本地筛选（状态 / 学时）。
  bool get hasLocalFilter => phases.isNotEmpty || minClassHour > 0;

  /// 是否启用了服务端筛选（等级 / 主办方）。
  bool get hasServerFilter => level.isNotEmpty || org.isNotEmpty;

  /// 是否有任何筛选生效。
  bool get isActive => hasLocalFilter || hasServerFilter;

  /// 本地维度判定：[activity] 是否命中状态与学时条件。
  ///
  /// 条目实际展示的状态标签（1~2 个）与 [phases] 有交集即命中；
  /// [phasesOverride] 用于携带系列详情页回传的场次归并状态（见
  /// `ActivityLibDetailPage.onSubActivitiesResolved`）；
  /// 服务端维度（等级 / 主办方）不在此判定——它们已经在请求参数里生效。
  bool matches(
    CyclActivity activity, {
    DateTime? now,
    List<CcylActivityPhase>? phasesOverride,
  }) {
    if (minClassHour > 0 && activity.classHour < minClassHour) return false;
    if (phases.isNotEmpty) {
      final shown = (phasesOverride != null && phasesOverride.isNotEmpty)
          ? phasesOverride
          : resolveCcylActivityPhases(activity, now: now);
      if (!shown.any(phases.contains)) return false;
    }
    return true;
  }

  CcylActivityFilter copyWith({
    Set<CcylActivityPhase>? phases,
    int? minClassHour,
    String? level,
    String? org,
  }) {
    return CcylActivityFilter(
      phases: phases ?? this.phases,
      minClassHour: minClassHour ?? this.minClassHour,
      level: level ?? this.level,
      org: org ?? this.org,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CcylActivityFilter &&
        _phaseKey(other.phases) == _phaseKey(phases) &&
        other.minClassHour == minClassHour &&
        other.level == level &&
        other.org == org;
  }

  @override
  int get hashCode => Object.hash(_phaseKey(phases), minClassHour, level, org);

  static String _phaseKey(Set<CcylActivityPhase> phases) {
    final indexes = phases.map((p) => p.index).toList()..sort();
    return indexes.join(',');
  }
}
