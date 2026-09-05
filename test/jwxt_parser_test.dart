import 'package:flutter_test/flutter_test.dart';
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
  });
}
