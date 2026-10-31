import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/schedule_config.dart';
import 'package:bugaoshan/pages/course/import/jwxt_parser.dart';

void main() {
  group('jwxt_parser', () {
    test('parses standard teachingBuildingName and classroomName', () {
      final mockData = {
        'xkxx': [
          {
            'course1': {
              'courseName': '高等数学',
              'attendClassTeacher': '张老师',
              'id': {'coureSequenceNumber': '01'},
              'timeAndPlaceList': [
                {
                  'classDay': 1,
                  'classSessions': 1,
                  'continuingSession': 2,
                  'teachingBuildingName': '第一教学楼',
                  'classroomName': 'A101',
                  'campusName': '江安校区',
                  'classWeek': '111100',
                },
              ],
            },
          },
        ],
      };

      final result = parseJwxtData(mockData, '默认课表');
      expect(result.courses, hasLength(1));
      final course = result.courses.first;
      expect(course.name, '高等数学 (01)');
      expect(course.location, '第一教学楼A101');
      expect(course.campus, '江安校区');
      expect(course.teacher, '张老师');
      expect(course.dayOfWeek, 1);
      expect(course.startSection, 1);
      expect(course.endSection, 2);
    });

    test('falls back to customPlace when building and room are empty', () {
      final mockData = {
        'xkxx': [
          {
            'course2': {
              'courseName': '大学体育',
              'attendClassTeacher': '李老师',
              'id': {'coureSequenceNumber': '02'},
              'timeAndPlaceList': [
                {
                  'classDay': 3,
                  'classSessions': 5,
                  'continuingSession': 2,
                  'customPlace': '江安东区游泳池',
                  'campusName': '江安校区',
                  'classWeek': '111111',
                },
              ],
            },
          },
        ],
      };

      final result = parseJwxtData(mockData, '默认课表');
      expect(result.courses, hasLength(1));
      final course = result.courses.first;
      expect(course.name, '大学体育 (02)');
      expect(course.location, '江安东区游泳池');
      expect(course.campus, '江安校区');
    });

    test('falls back to jxlm and jasm shorthand keys', () {
      final mockData = {
        'xkxx': [
          {
            'course3': {
              'courseName': '大学物理实验',
              'attendClassTeacher': '赵老师',
              'id': {'coureSequenceNumber': '03'},
              'timeAndPlaceList': [
                {
                  'classDay': 4,
                  'classSessions': 3,
                  'continuingSession': 2,
                  'jxlm': '第二基础实验大楼',
                  'jasm': 'B501',
                  'campusName': '江安校区',
                  'classWeek': '1100',
                },
              ],
            },
          },
        ],
      };

      final result = parseJwxtData(mockData, '默认课表');
      expect(result.courses, hasLength(1));
      final course = result.courses.first;
      expect(course.location, '第二基础实验大楼B501');
    });

    test('tolerates non-String field values via toString fallback', () {
      // 教务接口偶发数字型字段（如 classroomName 为 int），不应抛类型错误。
      final mockData = {
        'xkxx': [
          {
            'course4': {
              'courseName': '程序设计',
              'attendClassTeacher': '王老师',
              'id': {'coureSequenceNumber': '04'},
              'timeAndPlaceList': [
                {
                  'classDay': 2,
                  'classSessions': 1,
                  'continuingSession': 1,
                  'teachingBuildingName': '第一教学楼',
                  'classroomName': 101,
                  'campusName': '江安校区',
                  'classWeek': '1010',
                },
              ],
            },
          },
        ],
      };

      final result = parseJwxtData(mockData, '默认课表');
      expect(result.courses, hasLength(1));
      expect(result.courses.first.location, '第一教学楼101');
    });

    test('parseSemesterMetadata 正确解析学年与学期代码', () {
      final meta1 = parseSemesterMetadata('2025-2026学年春(当前)', '2025-2026-2-1');
      expect(meta1.academicYearCode, '2025-2026');
      expect(meta1.termName, '春');

      final meta2 = parseSemesterMetadata('2024-2025学年秋', '2024-2025-1-1');
      expect(meta2.academicYearCode, '2024-2025');
      expect(meta2.termName, '秋');

      final meta3 = parseSemesterMetadata('2023-2024-2', '2023-2024-2-1');
      expect(meta3.academicYearCode, '2023-2024');
      expect(meta3.termName, '春');

      // 仅传入 label 时同样能正确解析学期序号
      final meta3LabelOnly = parseSemesterMetadata('2023-2024-2');
      expect(meta3LabelOnly.academicYearCode, '2023-2024');
      expect(meta3LabelOnly.termName, '春');

      final meta4 = parseSemesterMetadata('我的自定义课表');
      expect(meta4.academicYearCode, isNull);
      expect(meta4.termName, isNull);
    });

    group('computeUpdatedScheduleConfig', () {
      final baseConfig = ScheduleConfig(
        id: 'sch1',
        semesterName: '旧课表',
        semesterStartDate: DateTime(2024, 9, 1),
        totalWeeks: 18,
      );

      final dummyCourse = Course(
        name: '普通课程',
        teacher: '老师',
        location: '',
        campus: '江安校区',
        startWeek: 1,
        endWeek: 16,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0,
      );

      test('当已有课表学期元数据为空时，更新写回 academicYearCode 与 termName', () {
        final updated = computeUpdatedScheduleConfig(
          existing: baseConfig,
          newCourses: [dummyCourse],
          academicYearCode: '2024-2025',
          termName: '秋',
        );

        expect(updated, isNotNull);
        expect(updated!.academicYearCode, '2024-2025');
        expect(updated.termName, '秋');
        expect(updated.semesterName, '旧课表'); // 保留原有名称
      });

      test('当传入校历起止日期与周数时，正确更新校历信息', () {
        final newDate = DateTime(2025, 3, 3);
        final updated = computeUpdatedScheduleConfig(
          existing: baseConfig,
          newCourses: [dummyCourse],
          semesterStartDate: newDate,
          totalWeeks: 20,
        );

        expect(updated, isNotNull);
        expect(updated!.semesterStartDate, newDate);
        expect(updated.totalWeeks, 20);
      });

      test('当用户自定义过时间表（非预置）时，保留用户时间表不覆盖，但仍更新元数据', () {
        final customSlots = [
          const TimeSlot(
            startTime: TimeOfDay(hour: 7, minute: 0),
            endTime: TimeOfDay(hour: 8, minute: 0),
          ),
        ];
        final customConfig = baseConfig.copyWith(timeSlots: customSlots);

        final updated = computeUpdatedScheduleConfig(
          existing: customConfig,
          newCourses: [
            Course(
              name: '望江课',
              teacher: '',
              location: '望江东三教',
              campus: '望江校区',
              startWeek: 1,
              endWeek: 16,
              dayOfWeek: 1,
              startSection: 1,
              endSection: 2,
              colorValue: 0,
            ),
          ],
          academicYearCode: '2024-2025',
          termName: '秋',
        );

        expect(updated, isNotNull);
        expect(updated!.academicYearCode, '2024-2025');
        expect(updated.termName, '秋');
        // 自定义时间表未被覆盖
        expect(updated.timeSlots.length, 1);
        expect(updated.timeSlots.first.startTime.hour, 7);
      });

      test('当课程主导校区变更且为预置时间表时，按主导校区刷新时间表', () {
        // baseConfig 默认为江安时间表（8:15 开始）
        final updated = computeUpdatedScheduleConfig(
          existing: baseConfig,
          newCourses: [
            Course(
              name: '望江课程',
              teacher: '',
              location: '',
              campus: '望江校区',
              startWeek: 1,
              endWeek: 16,
              dayOfWeek: 1,
              startSection: 1,
              endSection: 2,
              colorValue: 0,
            ),
          ],
        );

        expect(updated, isNotNull);
        // 望江第1节课 8:00 开始
        expect(updated!.timeSlots.first.startTime.hour, 8);
        expect(updated.timeSlots.first.startTime.minute, 0);
      });

      test('当配置字段全部一致时返回 null，避免无谓数据库写操作', () {
        final alreadyUpdated = baseConfig.copyWith(
          academicYearCode: '2024-2025',
          termName: '秋',
        );

        final result = computeUpdatedScheduleConfig(
          existing: alreadyUpdated,
          newCourses: [dummyCourse],
          academicYearCode: '2024-2025',
          termName: '秋',
          semesterStartDate: baseConfig.semesterStartDate,
          totalWeeks: baseConfig.totalWeeks,
        );

        expect(result, isNull);
      });
    });
  });
}
