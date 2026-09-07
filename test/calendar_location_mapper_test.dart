import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/utils/calendar_location_mapper.dart';

/// 专注测试 `CalendarLocationMapper` 的地名解析（拆自 calendar_event_utils）。
///
/// 该模块是全库最容易回归的纯逻辑：120+ 条建筑 pattern + 多重正则，
/// 新增/改动 buildingKeywords 时保证行为可预测。
void main() {
  group('CalendarLocationMapper.resolve — 校区识别', () {
    test('location 内含校区关键词时优先命中该校区的建筑', () {
      final jiangAn = CalendarLocationMapper.resolve('江安 一教A101');
      expect(jiangAn.title, contains('四川大学江安校区'));
      expect(jiangAn.title, contains('第一教学楼A座'));
      expect(jiangAn.title, contains('A101'));
    });

    test('campusName 显式指定时不出校区的同名校区建筑不串场', () {
      // "一教" 仅存在于江安，显式指定望江时不会误命中
      final wangJiang = CalendarLocationMapper.resolve(
        '一教A101',
        campusName: '望江校区',
      );
      expect(wangJiang.title, isNot(contains('第一教学楼')));
    });

    test('无校区关键词时按建筑关键词推断校区', () {
      final huaXi = CalendarLocationMapper.resolve('八教302');
      expect(huaXi.title, contains('四川大学华西校区'));
      expect(huaXi.title, contains('第八教学楼'));
    });
  });

  group('CalendarLocationMapper.resolve — 座号与房间号提取', () {
    test('一教A101 → 第一教学楼A座 · A101', () {
      final loc = CalendarLocationMapper.resolve('一教A101');
      expect(loc.title, contains('第一教学楼A座'));
      expect(loc.title, contains('A101'));
      // 座号不应丢失，也不应出现重复座号
      expect(loc.title, isNot(contains('A A101')));
    });

    test('综C407 → 逸夫教学楼（综C）· C407', () {
      final loc = CalendarLocationMapper.resolve('综C407');
      expect(loc.title, contains('四川大学江安校区'));
      expect(loc.title, contains('C407'));
      expect(loc.title, contains('(综C)'));
    });

    test('基础教学楼B101 → 基础教学楼B座 · B101', () {
      final loc = CalendarLocationMapper.resolve('基础教学楼B101');
      expect(loc.title, contains('基础教学楼B座'));
      expect(loc.title, contains('B101'));
    });

    test('"一教 A101" 空格形态命中 A 座并保留房间号', () {
      // "一教 A 101" 中的 "一教 A" 整体命中带座号 pattern（长 pattern 优先），
      // 剩余 "101" 作为房间号输出（不会出现重复座号 "A A101"）。
      final loc = CalendarLocationMapper.resolve('一教 A 101');
      expect(loc.title, contains('第一教学楼A座'));
      expect(loc.title, contains('101'));
      expect(loc.title, isNot(contains('A A101')));
    });

    test('仅带座号无房间号（一教A座）不产出幽灵房间号', () {
      final loc = CalendarLocationMapper.resolve('一教A座');
      expect(loc.title, isNot(contains('A座 · A')));
    });
  });

  group('CalendarLocationMapper.resolve — 兜底与边界', () {
    test('空地点 + 无校区 → 空标题', () {
      final loc = CalendarLocationMapper.resolve('');
      expect(loc.title, isEmpty);
    });

    test('空地点 + 校区 → 校区全称', () {
      final loc = CalendarLocationMapper.resolve('', campusName: '望江校区');
      expect(loc.title, '四川大学望江校区');
    });

    test('未知地点原样返回，不带坐标', () {
      final loc = CalendarLocationMapper.resolve('线上考试');
      expect(loc.title, '线上考试');
      expect(loc.structuredLocation, isNull);
    });

    test('随机教学楼名不会被误判为已匹配建筑', () {
      final loc = CalendarLocationMapper.resolve('启明楼 202');
      // 启明楼是江安一教的别称
      expect(loc.title, contains('第一教学楼'));
    });
  });
}
