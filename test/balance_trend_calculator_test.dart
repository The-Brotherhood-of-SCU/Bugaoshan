import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/services/balance/balance_trend_calculator.dart';

BalanceRecord _rec(
  DateTime t,
  double balance,
  double price, {
  String roomKey = 'r',
}) {
  return BalanceRecord(
    roomKey: roomKey,
    balanceType: 1,
    timestamp: t,
    balance: balance,
    price: price,
  );
}

void main() {
  group('BalanceTrendCalculator', () {
    test('empty list → empty result', () {
      final r = BalanceTrendCalculator.calculate(const []);
      expect(r.dailyPoints, isEmpty);
      expect(r.dailyAvgCost, 0);
      expect(r.dailyAvgKwh, 0);
      expect(r.totalCost, 0);
      expect(r.totalKwh, 0);
      expect(r.totalDays, 0);
      expect(r.skippedRechargeSegments, 0);
      expect(r.recordCount, 0);
      expect(r.firstRecordTime, isNull);
      expect(r.lastRecordTime, isNull);
      expect(r.currentPrice, 0);
    });

    test('single point → no segments, zero stats', () {
      final t = DateTime.utc(2026, 1, 1, 10);
      final r = BalanceTrendCalculator.calculate([_rec(t, 100, 0.5)]);
      expect(r.dailyPoints.length, 1);
      expect(r.dailyAvgCost, 0);
      expect(r.totalDays, 0);
      expect(r.recordCount, 1);
      expect(r.currentPrice, 0.5);
      expect(r.firstRecordTime, t);
      expect(r.lastRecordTime, t);
    });

    test('two points normal consumption', () {
      // 1月1日余额100,1月3日余额94,6度消耗,单价恒定0.5元/度
      // Δb=6,Δt=2天,p_avg=0.5
      // totalCost=6*0.5=3元,dailyAvgCost=3/2=1.5元/天
      // totalKwh=6,dailyAvgKwh=6/2=3度/天
      final a = DateTime.utc(2026, 1, 1, 10);
      final b = DateTime.utc(2026, 1, 3, 10);
      final r = BalanceTrendCalculator.calculate([
        _rec(a, 100, 0.5),
        _rec(b, 94, 0.5),
      ]);
      expect(r.dailyPoints.length, 2);
      expect(r.totalKwh, 6);
      expect(r.totalCost, 3);
      expect(r.totalDays, 2);
      expect(r.dailyAvgKwh, 3);
      expect(r.dailyAvgCost, 1.5);
      expect(r.skippedRechargeSegments, 0);
      expect(r.currentPrice, 0.5);
    });

    test('price changes between segments → use average', () {
      // 1月1日 余额100 单价0.5,1月3日 余额94 单价0.7
      // Δb=6,p_avg=(0.5+0.7)/2=0.6
      // totalCost=6*0.6=3.6元
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2026, 1, 1, 10), 100, 0.5),
        _rec(DateTime.utc(2026, 1, 3, 10), 94, 0.7),
      ]);
      expect(r.totalKwh, 6);
      expect(r.totalCost, closeTo(3.6, 1e-9));
      expect(r.totalDays, 2);
      expect(r.dailyAvgCost, closeTo(1.8, 1e-9));
      expect(r.currentPrice, 0.7);
    });

    test('recharge segment (Δb<0) is skipped', () {
      // 1月1日 余额100 单价0.5
      // 1月3日 余额94 单价0.5  (消耗6度)
      // 1月5日 余额150 单价0.5  (充值,Δb=-56,跳过)
      // 1月7日 余额140 单价0.5  (消耗10度)
      // 总消耗=6+10=16度,总金额=16*0.5=8元,总天数=2+2=4天(中间段跳过)
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2026, 1, 1, 10), 100, 0.5),
        _rec(DateTime.utc(2026, 1, 3, 10), 94, 0.5),
        _rec(DateTime.utc(2026, 1, 5, 10), 150, 0.5),
        _rec(DateTime.utc(2026, 1, 7, 10), 140, 0.5),
      ]);
      expect(r.skippedRechargeSegments, 1);
      expect(r.totalKwh, 16);
      expect(r.totalCost, 8);
      expect(r.totalDays, 4);
      expect(r.dailyAvgKwh, 4);
      expect(r.dailyAvgCost, 2);
    });

    test('same-day multiple records → take last as daily point', () {
      // 同一北京日 1月1日 有3条记录,只应保留最后一条作为日代表点。
      // 时间戳以 UTC 表示,确保均落在北京 01-01:
      //   UTC 01-01 00:00 = 北京 01-01 08:00
      //   UTC 01-01 06:00 = 北京 01-01 14:00
      //   UTC 01-01 12:00 = 北京 01-01 20:00
      //   UTC 01-02 02:00 = 北京 01-02 10:00
      // 日代表点:北京 01-01 20:00 余额90,北京 01-02 10:00 余额85
      // Δb=5,Δt=14h=7/12天,p_avg=0.5
      // totalCost=2.5元,dailyAvgCost=2.5/(7/12)=30/7≈4.286元/天
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2026, 1, 1, 0), 100, 0.5),
        _rec(DateTime.utc(2026, 1, 1, 6), 95, 0.5),
        _rec(DateTime.utc(2026, 1, 1, 12), 90, 0.5),
        _rec(DateTime.utc(2026, 1, 2, 2), 85, 0.5),
      ]);
      expect(r.dailyPoints.length, 2);
      expect(r.dailyPoints[0].balance, 90);
      expect(r.dailyPoints[1].balance, 85);
      expect(r.recordCount, 4);
      expect(r.totalKwh, 5);
      expect(r.totalCost, closeTo(2.5, 1e-9));
      expect(r.totalDays, closeTo(7 / 12, 1e-9));
      expect(r.dailyAvgCost, closeTo(2.5 / (7 / 12), 1e-9));
    });

    test('cross year/month boundary', () {
      // 2025年12月31日 → 2026年1月2日,Δt=2天
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2025, 12, 31, 10), 100, 0.5),
        _rec(DateTime.utc(2026, 1, 2, 10), 90, 0.5),
      ]);
      expect(r.totalKwh, 10);
      expect(r.totalDays, 2);
      expect(r.totalCost, 5);
      expect(r.dailyAvgCost, 2.5);
    });

    test('zero consumption (same balance) → zero cost, days counted', () {
      // 用户两次查询余额没变(没用电)
      // Δb=0,理论上 cost=0,kwh=0,days 累计
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2026, 1, 1, 10), 100, 0.5),
        _rec(DateTime.utc(2026, 1, 4, 10), 100, 0.5),
      ]);
      expect(r.totalKwh, 0);
      expect(r.totalCost, 0);
      expect(r.totalDays, 3);
      // Δb=0 不算充值段(因为 db<0 才跳过)
      expect(r.skippedRechargeSegments, 0);
      // dailyAvgCost = 0 / 3 = 0
      expect(r.dailyAvgCost, 0);
    });

    test('records not sorted by time → handled correctly', () {
      // 输入乱序,calculator 应基于日代表点排序后计算
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2026, 1, 5, 10), 80, 0.5),
        _rec(DateTime.utc(2026, 1, 1, 10), 100, 0.5),
        _rec(DateTime.utc(2026, 1, 3, 10), 90, 0.5),
      ]);
      expect(r.dailyPoints.length, 3);
      expect(r.dailyPoints[0].timestamp, DateTime.utc(2026, 1, 1, 10));
      expect(r.dailyPoints[1].timestamp, DateTime.utc(2026, 1, 3, 10));
      expect(r.dailyPoints[2].timestamp, DateTime.utc(2026, 1, 5, 10));
      expect(r.totalKwh, 20);
      expect(r.totalCost, 10);
      expect(r.totalDays, 4);
    });

    test('records spanning Beijing midnight aggregate by Beijing day', () {
      // 北京 2026-07-20 02:00 = UTC 2026-07-19 18:00
      // 北京 2026-07-20 23:30 = UTC 2026-07-20 15:30
      // 同一北京日,应聚合为 1 个日代表点(取最后一条)
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2026, 7, 19, 18), 100, 0.5),
        _rec(DateTime.utc(2026, 7, 20, 15, 30), 94, 0.5),
      ]);
      expect(r.dailyPoints.length, 1);
      expect(r.dailyPoints[0].balance, 94);
      expect(r.recordCount, 2);
      expect(r.totalKwh, 0); // 单点无段
    });

    test('Beijing day boundary splits two-day records', () {
      // 北京 2026-07-20 23:30 = UTC 2026-07-20 15:30
      // 北京 2026-07-21 02:00 = UTC 2026-07-20 18:00
      // 不同北京日,应聚合为 2 个日代表点
      final r = BalanceTrendCalculator.calculate([
        _rec(DateTime.utc(2026, 7, 20, 15, 30), 100, 0.5),
        _rec(DateTime.utc(2026, 7, 20, 18), 94, 0.5),
      ]);
      expect(r.dailyPoints.length, 2);
      expect(r.totalKwh, 6);
    });
  });
}
