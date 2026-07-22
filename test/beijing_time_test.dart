import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/utils/beijing_time.dart';

void main() {
  group('beijingDayBucket', () {
    test('same Beijing day → same bucket', () {
      // 北京 2026-07-20 02:00 = UTC 2026-07-19 18:00
      // 北京 2026-07-20 23:30 = UTC 2026-07-20 15:30
      expect(
        beijingDayBucket(DateTime.utc(2026, 7, 19, 18)),
        beijingDayBucket(DateTime.utc(2026, 7, 20, 15, 30)),
      );
    });

    test('different Beijing day → different bucket', () {
      // 北京 2026-07-20 23:30 = UTC 2026-07-20 15:30
      // 北京 2026-07-21 00:30 = UTC 2026-07-20 16:30
      expect(
        beijingDayBucket(DateTime.utc(2026, 7, 20, 15, 30)),
        isNot(beijingDayBucket(DateTime.utc(2026, 7, 20, 16, 30))),
      );
    });

    test('accepts local DateTime input', () {
      // 设备时区不影响结果:DateTime.utc 构造的 UTC 时刻固定
      expect(
        beijingDayBucket(DateTime.utc(2026, 7, 19, 16)),
        DateTime.utc(2026, 7, 20),
      );
    });
  });

  group('beijingStartOfDayUtc', () {
    test('returns Beijing midnight in UTC', () {
      // 北京 2026-07-20 00:00 = UTC 2026-07-19 16:00
      // 输入北京 2026-07-20 13:00 = UTC 2026-07-20 05:00
      expect(
        beijingStartOfDayUtc(DateTime.utc(2026, 7, 20, 5)),
        DateTime.utc(2026, 7, 19, 16),
      );
    });

    test('early morning Beijing time → previous Beijing day start', () {
      // 北京 2026-07-20 02:00 = UTC 2026-07-19 18:00
      // 该时刻所在北京日为 07-20,其 00:00 = UTC 07-19 16:00
      expect(
        beijingStartOfDayUtc(DateTime.utc(2026, 7, 19, 18)),
        DateTime.utc(2026, 7, 19, 16),
      );
    });
  });

  group('beijingDateToUtc', () {
    test('Beijing midnight converts to UTC', () {
      // 北京 2026-07-20 00:00 = UTC 2026-07-19 16:00
      expect(beijingDateToUtc(2026, 7, 20), DateTime.utc(2026, 7, 19, 16));
    });

    test('end-of-day converts with hour/minute/second/millisecond', () {
      // 北京 2026-07-20 23:59:59.999 = UTC 2026-07-20 15:59:59.999
      expect(
        beijingDateToUtc(
          2026,
          7,
          20,
          hour: 23,
          minute: 59,
          second: 59,
          millisecond: 999,
        ),
        DateTime.utc(2026, 7, 20, 15, 59, 59, 999),
      );
    });

    test('round-trips with beijingStartOfDayUtc', () {
      final start = beijingDateToUtc(2026, 7, 20);
      final startOfDay = beijingStartOfDayUtc(start);
      expect(start, startOfDay);
    });
  });

  group('formatBeijing', () {
    test('formats UTC instant as Beijing date', () {
      // UTC 2026-07-19 18:00 = 北京 2026-07-20 02:00
      expect(
        formatBeijing(DateTime.utc(2026, 7, 19, 18), 'yyyy-MM-dd'),
        '2026-07-20',
      );
    });

    test('formats UTC instant as Beijing date+time', () {
      // UTC 2026-07-20 15:30 = 北京 2026-07-20 23:30
      expect(
        formatBeijing(DateTime.utc(2026, 7, 20, 15, 30), 'yyyy-MM-dd HH:mm'),
        '2026-07-20 23:30',
      );
    });

    test('cross-day boundary: UTC 16:00 → Beijing next day 00:00', () {
      expect(
        formatBeijing(DateTime.utc(2026, 7, 19, 16), 'yyyy-MM-dd HH:mm'),
        '2026-07-20 00:00',
      );
    });
  });
}
