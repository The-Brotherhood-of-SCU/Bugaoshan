import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/utils/class_week_parser.dart';

/// 剥离教务处学期标签中的"（当前）"标记。
String cleanSemesterLabel(String label) {
  return label.replaceAll('（当前）', '').replaceAll('(当前)', '').trim();
}

/// 校验导入的课表是否合法，非法时抛 [FormatException]。
void validateImportedSchedule(ScheduleConfig config, List<Course> courses) {
  if (config.totalWeeks < 1 || config.timeSlots.isEmpty) {
    throw const FormatException('Invalid schedule config');
  }
  final maxSection = config.timeSlots.length;
  for (final course in courses) {
    if (course.startWeek < 1 ||
        course.endWeek < course.startWeek ||
        course.endWeek > config.totalWeeks ||
        course.dayOfWeek < 1 ||
        course.dayOfWeek > 7 ||
        course.startSection < 1 ||
        course.endSection < course.startSection ||
        course.endSection > maxSection) {
      throw FormatException('Invalid course range: ${course.name}');
    }
  }
}

/// 解析教务处原始 JSON 为 [ScheduleConfig] + [Course] 列表。
///
/// [defaultScheduleName] 为空课表时的默认名称（原先取自 l10n.importedScheduleName）。
/// 返回的 `hasWeekend` 供调用方决定是否开启 `showWeekend`。
({ScheduleConfig config, List<Course> courses, bool hasWeekend}) parseJwxtData(
  dynamic data,
  String defaultScheduleName,
) {
  final Map<String, dynamic> jwxtData = data as Map<String, dynamic>;
  final List<dynamic> xkxx = jwxtData['xkxx'] as List<dynamic>;

  final config = ScheduleConfig(
    semesterStartDate: DateTime.now().toMonday(),
    semesterName: defaultScheduleName,
  );

  final List<Course> courses = [];
  final colors = Colors.primaries;
  int colorIdx = 0;

  for (final item in xkxx) {
    final Map<String, dynamic> courseMap = item as Map<String, dynamic>;
    courseMap.forEach((key, value) {
      final Map<String, dynamic> details = value as Map<String, dynamic>;
      final String rawName = details['courseName'] as String? ?? 'Unknown';
      final String courseSequence =
          details['id']?['coureSequenceNumber'] as String? ?? '';
      final String courseName = '$rawName ($courseSequence)';
      final String teacher = details['attendClassTeacher'] as String? ?? '';
      final List<dynamic> timeAndPlaceList =
          details['timeAndPlaceList'] as List<dynamic>? ?? [];

      for (final tp in timeAndPlaceList) {
        final Map<String, dynamic> tpMap = tp as Map<String, dynamic>;
        final int dayOfWeek = tpMap['classDay'] as int;
        final int startSection = tpMap['classSessions'] as int;
        final int continuingSession = tpMap['continuingSession'] as int;
        final int endSection = startSection + continuingSession - 1;
        final String building =
            (tpMap['teachingBuildingName'] ??
                    tpMap['jxlm'] ??
                    tpMap['building'] ??
                    '')
                as String;
        final String room =
            (tpMap['classroomName'] ??
                    tpMap['jasm'] ??
                    tpMap['classroom'] ??
                    '')
                as String;
        var location = '$building$room'.trim();
        if (location.isEmpty) {
          location =
              (tpMap['customPlace'] ??
                      tpMap['teachingPlace'] ??
                      tpMap['place'] ??
                      tpMap['skdd'] ??
                      '')
                  as String;
          location = location.trim();
        }
        final String campusName = tpMap['campusName'] as String? ?? '';
        final String classWeek = tpMap['classWeek'] as String? ?? '';

        final weekSegments = parseClassWeekSegments(classWeek);
        if (weekSegments.isNotEmpty) {
          final colorValue = colors[colorIdx % colors.length].toARGB32();
          for (final segment in weekSegments) {
            courses.add(
              Course(
                name: courseName,
                teacher: teacher,
                location: location,
                campus: campusName,
                startWeek: segment.startWeek,
                endWeek: segment.endWeek,
                dayOfWeek: dayOfWeek,
                startSection: startSection,
                endSection: endSection,
                colorValue: colorValue,
                weekType: segment.weekType,
              ),
            );
          }
          colorIdx++;
        }
      }
    });
  }

  final hasWeekend = courses.any((c) => c.dayOfWeek == 6 || c.dayOfWeek == 7);

  return (config: config, courses: courses, hasWeekend: hasWeekend);
}
