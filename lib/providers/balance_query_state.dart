// 本文件是 `balance_query_provider.dart` 的 part：状态模型与内部缓存载体。
//
// 包含 UI 消费的不可变快照（BalanceResourceState / BalanceTrendState /
// RoomBinding）与 Provider 内部的可变缓存条目（_ResourceEntry / key 类 /
// _TrendEntry）。私有类经 part 共享给主文件，外部仍只 import 主文件。
part of 'balance_query_provider.dart';

/// Provider 暴露给 UI 的资源快照。
///
/// 余额、校区、楼栋和单元均由 Provider 统一维护此状态；页面只读取快照
/// 并发出「确保加载」或「强制刷新」意图，不再保存重复的数据副本。
@immutable
class BalanceResourceState<T> {
  const BalanceResourceState({
    this.value,
    this.updatedAt,
    this.isLoading = false,
    this.error,
  });

  final T? value;
  final DateTime? updatedAt;
  final bool isLoading;
  final Object? error;

  bool get hasValue => value != null;
}

class _ResourceEntry<T> {
  T? value;
  DateTime? updatedAt;
  bool isLoading = false;
  Object? error;
  Future<T>? inFlight;

  BalanceResourceState<T> get state => BalanceResourceState<T>(
    value: value,
    updatedAt: updatedAt,
    isLoading: isLoading,
    error: error,
  );
}

class _BalanceCacheKey {
  const _BalanceCacheKey(this.roomKey, this.balanceType);

  final String roomKey;
  final int balanceType;

  @override
  bool operator ==(Object other) =>
      other is _BalanceCacheKey &&
      other.roomKey == roomKey &&
      other.balanceType == balanceType;

  @override
  int get hashCode => Object.hash(roomKey, balanceType);
}

/// Provider 暴露给余额趋势页的历史记录快照。
///
/// 日期范围是查询条件的一部分，因此每个房间、余额类型和范围各自拥有一份
/// 内存状态；页面只保存范围选择等纯交互状态。
@immutable
class BalanceTrendState {
  const BalanceTrendState({
    this.records = const [],
    this.trend = const TrendResult.empty(),
    this.hasValue = false,
    this.isLoading = false,
    this.error,
  });

  final List<BalanceRecord> records;
  final TrendResult trend;
  final bool hasValue;
  final bool isLoading;
  final Object? error;
}

class _TrendCacheKey {
  const _TrendCacheKey(this.roomKey, this.balanceType, this.since, this.until);

  final String roomKey;
  final int balanceType;
  final DateTime? since;
  final DateTime? until;

  @override
  bool operator ==(Object other) =>
      other is _TrendCacheKey &&
      other.roomKey == roomKey &&
      other.balanceType == balanceType &&
      other.since == since &&
      other.until == until;

  @override
  int get hashCode => Object.hash(roomKey, balanceType, since, until);
}

class _TrendEntry {
  List<BalanceRecord>? records;
  TrendResult trend = const TrendResult.empty();
  bool isLoading = false;
  Object? error;
  Future<void>? inFlight;

  BalanceTrendState get state => BalanceTrendState(
    records: records ?? const [],
    trend: trend,
    hasValue: records != null,
    isLoading: isLoading,
    error: error,
  );
}

/// 绑定的房间信息（缴费平台校验通过后持久化）。
///
/// 余额是房间维度的公共数据，绑定与当前房间全局持久化，不按登录账号隔离
/// （见 `docs/decisions/0005-remove-balance-history-account-isolation.md`）。
class RoomBinding {
  final String cusNo;
  final String cusName;
  final String schoolCode;
  final String schoolName;
  final String regCode;
  final String regName;
  final String unitCode;
  final String unitName;
  final String roomNo;

  RoomBinding({
    required this.cusNo,
    required this.cusName,
    required this.schoolCode,
    required this.schoolName,
    required this.regCode,
    required this.regName,
    required this.unitCode,
    required this.unitName,
    required this.roomNo,
  });

  String get displayName => '$schoolName $regName $unitName $roomNo';

  factory RoomBinding.fromJson(Map<String, dynamic> json) {
    return RoomBinding(
      cusNo: json['cusNo']?.toString() ?? '',
      cusName: json['cusName']?.toString() ?? '',
      schoolCode: json['schoolCode']?.toString() ?? '',
      schoolName: json['schoolName']?.toString() ?? '',
      regCode: json['regCode']?.toString() ?? '',
      regName: json['regName']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      roomNo: json['roomNo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'cusNo': cusNo,
    'cusName': cusName,
    'schoolCode': schoolCode,
    'schoolName': schoolName,
    'regCode': regCode,
    'regName': regName,
    'unitCode': unitCode,
    'unitName': unitName,
    'roomNo': roomNo,
  };
}
