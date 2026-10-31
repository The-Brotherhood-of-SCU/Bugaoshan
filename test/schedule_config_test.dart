import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/schedule_config.dart';

void main() {
  group('ScheduleConfig 学期元数据与序列化测试', () {
    test('默认情况下 academicYearCode 和 termName 为 null', () {
      final config = ScheduleConfig(semesterStartDate: DateTime(2024, 9, 1));
      expect(config.academicYearCode, isNull);
      expect(config.termName, isNull);
    });

    test('构造函数支持指定 academicYearCode 和 termName', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2024, 9, 1),
        academicYearCode: '2024-2025',
        termName: '秋',
      );
      expect(config.academicYearCode, '2024-2025');
      expect(config.termName, '秋');
    });

    test('toJson 包含学术学年与学期字段（当有值时）', () {
      final config = ScheduleConfig(
        id: 'test_id',
        semesterName: '2024-2025学年秋',
        semesterStartDate: DateTime(2024, 9, 1),
        academicYearCode: '2024-2025',
        termName: '秋',
      );
      final json = config.toJson();
      expect(json['academicYearCode'], '2024-2025');
      expect(json['termName'], '秋');
    });

    test('toJson 不包含 academicYearCode 和 termName（当为 null 时）', () {
      final config = ScheduleConfig(
        id: 'test_id',
        semesterStartDate: DateTime(2024, 9, 1),
      );
      final json = config.toJson();
      expect(json.containsKey('academicYearCode'), isFalse);
      expect(json.containsKey('termName'), isFalse);
    });

    test('fromJson 能够解析老版本不含学期元数据的 JSON', () {
      final legacyJson = {
        'id': 'legacy_id',
        'semesterName': '旧课表',
        'semesterStartDate': '2023-09-01',
        'totalWeeks': 20,
        'morningSections': 4,
        'afternoonSections': 5,
        'eveningSections': 3,
        'courseDuration': 45,
        'breakDuration': 10,
        'autoSyncTime': true,
        'timeSlots': [],
      };
      final config = ScheduleConfig.fromJson(legacyJson);
      expect(config.academicYearCode, isNull);
      expect(config.termName, isNull);
      expect(config.semesterName, '旧课表');
    });

    test('fromJson 能够解析包含学期元数据的新版本 JSON', () {
      final json = {
        'id': 'new_id',
        'semesterName': '2025-2026学年春',
        'semesterStartDate': '2026-03-01',
        'totalWeeks': 20,
        'morningSections': 4,
        'afternoonSections': 5,
        'eveningSections': 3,
        'courseDuration': 45,
        'breakDuration': 10,
        'autoSyncTime': true,
        'timeSlots': [],
        'academicYearCode': '2025-2026',
        'termName': '春',
      };
      final config = ScheduleConfig.fromJson(json);
      expect(config.academicYearCode, '2025-2026');
      expect(config.termName, '春');
    });

    test('JSON 往返序列化无损', () {
      final original = ScheduleConfig(
        id: 'roundtrip_id',
        semesterName: '2025-2026学年秋',
        semesterStartDate: DateTime(2025, 9, 1),
        academicYearCode: '2025-2026',
        termName: '秋',
      );
      final json = original.toJson();
      final restored = ScheduleConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.semesterName, original.semesterName);
      expect(restored.academicYearCode, '2025-2026');
      expect(restored.termName, '秋');
    });

    test('copyWith 可以更新学期元数据且保留其余属性', () {
      final original = ScheduleConfig(
        id: 'orig',
        semesterName: '用户自定义名称',
        semesterStartDate: DateTime(2024, 9, 1),
        courseDuration: 50,
      );

      final updated = original.copyWith(
        academicYearCode: '2024-2025',
        termName: '秋',
      );

      expect(updated.id, 'orig');
      expect(updated.semesterName, '用户自定义名称');
      expect(updated.courseDuration, 50);
      expect(updated.academicYearCode, '2024-2025');
      expect(updated.termName, '秋');

      // 再次 copyWith 不传参保留原值
      final preserved = updated.copyWith(semesterName: '新名称');
      expect(preserved.semesterName, '新名称');
      expect(preserved.academicYearCode, '2024-2025');
      expect(preserved.termName, '秋');
    });
    test(
      'matchAcademicYear、resolveTermSeason 与 parseSemesterMetadata 正常工作',
      () {
        expect(matchAcademicYear('2024-2025学年秋'), '2024-2025');
        expect(matchAcademicYear('无学年'), isNull);
        expect(matchAcademicYear(null), isNull);

        expect(resolveTermSeason('2024-2025学年秋'), '秋');
        expect(resolveTermSeason('2024-2025学年春'), '春');
        expect(resolveTermSeason('2024-2025-1'), '秋');
        expect(resolveTermSeason('2024-2025-2'), '春');
        expect(resolveTermSeason(null), isNull);

        final meta = parseSemesterMetadata('2025-2026学年春(当前)', '2025-2026-2-1');
        expect(meta.academicYearCode, '2025-2026');
        expect(meta.termName, '春');
      },
    );
  });
}
