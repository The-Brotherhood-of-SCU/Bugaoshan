import 'package:bugaoshan/scu_backend/reservation/models/reservation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reservationResourcesFromJson（真实信封形状）', () {
    // 2026-10-23 抓包：`d.data` 直接是数组，每项带 `base`。
    Map<String, dynamic> envelope() => {
      'data': [
        {
          'base': {
            'id': 493,
            'name': '党建活动室',
            'type': 1,
            'attribute': [
              {
                'name': '容量/人数',
                'type': 0,
                'enable': 1,
                'data': '28',
              },
            ],
            'config': {'book': true},
          },
          'time': const [],
          'appointmen_list_info': const [],
        },
        {
          'base': {'id': 490, 'name': '学术交流室', 'config': {'book': true}},
          'time': const [],
          'appointmen_list_info': const [],
        },
      ],
      'resources': const [],
      'total': 17,
      'page': 1,
      'perpage': 100,
    };

    test('从 d.data[].base 解析出资源列表', () {
      final resources = reservationResourcesFromJson(envelope());

      expect(resources, hasLength(2));
      expect(resources.first.id, '493');
      expect(resources.first.name, '党建活动室');
      expect(resources.last.id, '490');
    });

    test('缺 data / data 非数组时返回空列表，不抛异常', () {
      expect(reservationResourcesFromJson(const {}), isEmpty);
      expect(reservationResourcesFromJson(const {'data': null}), isEmpty);
      expect(reservationResourcesFromJson(const {'data': 'oops'}), isEmpty);
      expect(reservationResourcesFromJson(null), isEmpty);
    });

    test('跳过没有 base 或 base 缺 id 的脏行', () {
      final resources = reservationResourcesFromJson({
        'data': [
          {'base': {'id': 1, 'name': '有效'}},
          {'time': const []},
          {'base': {'name': '无 id'}},
          'oops',
        ],
      });

      expect(resources, hasLength(1));
      expect(resources.single.id, '1');
    });
  });

  group('ReservationCalendar', () {
    // 2026-10-23 抓包样本（脱敏：仅保留结构与数值）。
    Map<String, dynamic> sample() => {
      'time': [
        {
          'id': 5103,
          'str_time': '08:00-12:00',
          'start_time': '08:00:00',
          'end_time': '12:00:00',
        },
        {
          'id': 5104,
          'str_time': '12:00-18:00',
          'start_time': '12:00:00',
          'end_time': '18:00:00',
        },
        {
          'id': 5105,
          'str_time': '18:00-22:00',
          'start_time': '18:00:00',
          'end_time': '22:00:00',
        },
      ],
      'day': ['2026-10-23', '2026-10-24'],
      'data': {
        '2026-10-23': {
          '5103': {'status': 3, 'total': 1, 'amount': 0, 'num': 0},
          '5104': {'status': 3, 'total': 1, 'amount': 0, 'num': 0},
          '5105': {'status': 0, 'total': 1, 'amount': 0, 'num': 1},
        },
        '2026-10-24': {
          '5103': {'status': 3, 'total': 1, 'amount': 0, 'num': 0},
          '5104': {'status': 0, 'total': 1, 'amount': 0, 'num': 1},
          '5105': {'status': 0, 'total': 1, 'amount': 0, 'num': 1},
        },
      },
    };

    test('解析时段、日期与占用矩阵', () {
      final calendar = ReservationCalendar.fromJson(sample());

      expect(calendar.slots, hasLength(3));
      expect(calendar.slots.first.id, '5103');
      expect(calendar.slots.first.label, '08:00-12:00');
      expect(calendar.days, ['2026-10-23', '2026-10-24']);

      final first = calendar.stateOf('2026-10-23', '5103');
      expect(first.status, ReservationSlotStatus.full);
      expect(first.bookable, isFalse);

      final third = calendar.stateOf('2026-10-23', '5105');
      expect(third.status, ReservationSlotStatus.available);
      expect(third.remaining, 1);
      expect(third.bookable, isTrue);
    });

    test('缺失的日期/时段按未开放处理，不抛异常', () {
      final calendar = ReservationCalendar.fromJson(sample());

      final missing = calendar.stateOf('2026-12-31', '5103');
      expect(missing.status, ReservationSlotStatus.notOpen);
      expect(missing.bookable, isFalse);

      final missingSlot = calendar.stateOf('2026-10-23', '9999');
      expect(missingSlot.status, ReservationSlotStatus.notOpen);
    });

    test('status 编码映射：0 可约 / 1 未开放 / 2 已过期 / 3 约满 / 4 已禁用', () {
      expect(
        ReservationSlotStatus.fromCode(0),
        ReservationSlotStatus.available,
      );
      expect(ReservationSlotStatus.fromCode(1), ReservationSlotStatus.notOpen);
      expect(ReservationSlotStatus.fromCode(2), ReservationSlotStatus.expired);
      expect(ReservationSlotStatus.fromCode(3), ReservationSlotStatus.full);
      expect(ReservationSlotStatus.fromCode(4), ReservationSlotStatus.disabled);
      // 未知编码归入「已禁用」，不误判为可预约。
      expect(ReservationSlotStatus.fromCode(99), ReservationSlotStatus.disabled);
    });

    test('可约但剩余为 0 时不算可预约', () {
      final calendar = ReservationCalendar.fromJson({
        'time': [
          {'id': 1, 'start_time': '08:00:00', 'end_time': '12:00:00'},
        ],
        'day': ['2026-10-23'],
        'data': {
          '2026-10-23': {
            '1': {'status': 0, 'total': 1, 'num': 0},
          },
        },
      });

      expect(calendar.stateOf('2026-10-23', '1').bookable, isFalse);
    });

    test('脏数据：非 Map / 空对象退化为空日历', () {
      expect(ReservationCalendar.fromJson(null).isEmpty, isTrue);
      expect(ReservationCalendar.fromJson('oops').isEmpty, isTrue);
      expect(ReservationCalendar.fromJson(const {}).isEmpty, isTrue);
    });

    test('时段缺 start_time/end_time 的行被丢弃', () {
      final calendar = ReservationCalendar.fromJson({
        'time': [
          {'id': 1, 'start_time': '08:00:00', 'end_time': '12:00:00'},
          {'id': 2, 'start_time': '12:00:00'},
          {'id': 3},
          {'start_time': '18:00:00', 'end_time': '22:00:00'},
        ],
        'day': ['2026-10-23'],
        'data': const {},
      });

      expect(calendar.slots, hasLength(1));
      expect(calendar.slots.single.id, '1');
    });
  });

  group('ReservationResource', () {
    // 2026-10-23 抓包样本的 config 结构（脱敏）。
    Map<String, dynamic> sample() => {
      'id': 493,
      'name': '党建活动室',
      'attribute': [
        {
          'name': '容量/人数',
          'type': 0,
          'enable': 1,
          'data': '28',
          'attribute_config': const {},
          'child': const [],
        },
        {
          'name': '校区',
          'type': 1,
          'enable': 1,
          'data': [
            {'id': '1', 'value': '望江校区'},
          ],
          'attribute_config': {
            'value': {'id': '1'},
          },
          'child': const [],
        },
      ],
      'config': {
        'book': true,
        'rule': [
          {'class': 'ResourceUseDayTimesRule', 'times': 2, 'type': 'd'},
          {'class': 'SinglePeriodNumRule', 'min': 1, 'num': 1},
        ],
        'approval': {
          'format': 'minute',
          'is_lock': 0,
          'time_out': '30',
          'relate_app': 479,
        },
        'calendar': {'max_date': null, 'default_date': 0},
      },
    };

    test('解析名称、属性、审批与每日时段上限', () {
      final resource = ReservationResource.fromJson(sample())!;

      expect(resource.id, '493');
      expect(resource.name, '党建活动室');
      expect(resource.needsApproval, isTrue);
      expect(resource.maxPeriodsPerDay, 2);
    });

    test('无 approval / 无 rule 时安全降级', () {
      final resource = ReservationResource.fromJson({
        'id': 1,
        'name': '测试房间',
        'config': {'book': true},
      })!;

      expect(resource.needsApproval, isFalse);
      expect(resource.maxPeriodsPerDay, 0);
      expect(resource.attributes, isEmpty);
    });

    test('选项型属性优先取 attribute_config 选中的那一项', () {
      final resource = ReservationResource.fromJson({
        'id': 1,
        'name': '测试',
        'attribute': [
          {
            'name': '分区',
            'type': 1,
            'enable': 1,
            'data': [
              {'id': '1', 'value': '党建思政活动区'},
              {'id': '2', 'value': '学术交流研讨区'},
            ],
            'attribute_config': {
              'value': {'id': '2'},
            },
          },
        ],
        'config': {'book': true},
      })!;

      expect(resource.attributes.single.name, '分区');
      expect(resource.attributes.single.value, '学术交流研讨区');
    });

    test('缺 id 返回 null', () {
      expect(ReservationResource.fromJson({'name': '无 id'}), isNull);
      expect(ReservationResource.fromJson(null), isNull);
    });
  });
}
