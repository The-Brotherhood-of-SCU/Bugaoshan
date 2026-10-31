import 'dart:convert';

import 'package:bugaoshan/pages/campus/reservation/models/reservation_models.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildLaunchBody：字段结构与官方前端一致（data/captcha 为 JSON 字符串）', () {
    final body = buildLaunchBody(
      resourceId: '493',
      slots: const [
        ReservationLaunchSlot(date: '2026-10-25', periodId: '5103'),
        ReservationLaunchSlot(date: '2026-10-26', periodId: '5104'),
      ],
      number: 2,
    );

    final data = jsonDecode(body['data'] as String) as List;
    expect(data, hasLength(1));
    final row = data.single as Map;
    expect(row['resource_id'], '493');
    expect(row['number'], 2);
    expect(row['period'], [
      {'date': '2026-10-25', 'period_id': '5103'},
      {'date': '2026-10-26', 'period_id': '5104'},
    ]);

    expect(body['data_colle'], '[]');
    expect(body['code'], '');
    expect(body['number'], 2);
    expect(body['collective'], 0);

    final captcha = jsonDecode(body['captcha'] as String) as Map;
    expect(captcha['token'], '');
    expect(captcha['pointJson'], '');
  });
}
