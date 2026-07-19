import 'package:bugaoshan/models/balance_record.dart';

/// 电费/空调余额趋势计算纯函数工具。
///
/// 给定按时间升序排列的原始 [BalanceRecord] 列表,先按"日历日(UTC)"聚合
/// 取每日最后一条作为日代表点,再对相邻日代表点按段加权平均:
///   - 段消耗 Δb = b_a - b_b (余额减少为正)
///   - 段均价 p_avg = (p_a + p_b) / 2 (电价波动时插值)
///   - 充值段 (Δb < 0) 跳过,不计入总消耗
///   - 日均电费 = Σ(Δb × p_avg) / Σ(Δt_days)
class BalanceTrendCalculator {
  static TrendResult calculate(List<BalanceRecord> records) {
    if (records.isEmpty) {
      return const TrendResult.empty();
    }

    // 1. 按日聚合:同一日历日(UTC)取最后一条
    final dailyMap = <DateTime, BalanceRecord>{};
    for (final r in records) {
      final day = DateTime.utc(
        r.timestamp.year,
        r.timestamp.month,
        r.timestamp.day,
      );
      final existing = dailyMap[day];
      if (existing == null || r.timestamp.isAfter(existing.timestamp)) {
        dailyMap[day] = r;
      }
    }
    final dailyPoints = dailyMap.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 2. 按段加权平均
    double totalCost = 0;
    double totalKwh = 0;
    double totalDays = 0;
    int skippedRechargeSegments = 0;

    for (int i = 0; i < dailyPoints.length - 1; i++) {
      final a = dailyPoints[i];
      final b = dailyPoints[i + 1];
      final dt = b.timestamp.difference(a.timestamp).inMinutes / 1440.0;
      if (dt <= 0) continue;
      final db = a.balance - b.balance;
      if (db < 0) {
        skippedRechargeSegments++;
        continue;
      }
      final pAvg = (a.price + b.price) / 2;
      totalCost += db * pAvg;
      totalKwh += db;
      totalDays += dt;
    }

    return TrendResult(
      dailyPoints: dailyPoints,
      dailyAvgCost: totalDays > 0 ? totalCost / totalDays : 0,
      dailyAvgKwh: totalDays > 0 ? totalKwh / totalDays : 0,
      totalCost: totalCost,
      totalKwh: totalKwh,
      totalDays: totalDays,
      skippedRechargeSegments: skippedRechargeSegments,
      recordCount: records.length,
      firstRecordTime: records.first.timestamp,
      lastRecordTime: records.last.timestamp,
      currentPrice: dailyPoints.last.price,
    );
  }
}

class TrendResult {
  /// 日代表点序列(按时间升序),用于绘图
  final List<BalanceRecord> dailyPoints;

  /// 日均电费(元/天)
  final double dailyAvgCost;

  /// 日均消耗度数(度/天)
  final double dailyAvgKwh;

  /// 累计消耗金额(元)
  final double totalCost;

  /// 累计消耗度数(度)
  final double totalKwh;

  /// 统计总天数(跳过充值段)
  final double totalDays;

  /// 已识别并跳过的充值段数
  final int skippedRechargeSegments;

  /// 原始记录总条数
  final int recordCount;

  /// 最早一条原始记录时间
  final DateTime? firstRecordTime;

  /// 最新一条原始记录时间
  final DateTime? lastRecordTime;

  /// 当前单价(元/度)
  final double currentPrice;

  const TrendResult({
    required this.dailyPoints,
    required this.dailyAvgCost,
    required this.dailyAvgKwh,
    required this.totalCost,
    required this.totalKwh,
    required this.totalDays,
    required this.skippedRechargeSegments,
    required this.recordCount,
    required this.firstRecordTime,
    required this.lastRecordTime,
    required this.currentPrice,
  });

  const TrendResult.empty()
    : dailyPoints = const [],
      dailyAvgCost = 0,
      dailyAvgKwh = 0,
      totalCost = 0,
      totalKwh = 0,
      totalDays = 0,
      skippedRechargeSegments = 0,
      recordCount = 0,
      firstRecordTime = null,
      lastRecordTime = null,
      currentPrice = 0;
}
