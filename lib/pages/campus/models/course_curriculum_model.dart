export 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart'
    show ClassScheduleInquiryItem, SemesterOption, DepartmentOption;

/// 课程课表 - 课程列表中的一门课程（教学班）
class CourseSectionInfo {
  final String planCode; // ZXJXJHH, e.g. "2026-2027-1-1"
  final String planName; // ZXJXJHM, e.g. "2026-2027学年秋"
  final String courseCode; // KCH
  final String courseName; // KCM
  final String courseSeq; // KXH
  final String credits; // XF
  final String category; // KCLBMC
  final String examType; // KSLXMC
  final String department; // KKXSM
  final String teachers; // JSM

  CourseSectionInfo({
    required this.planCode,
    required this.planName,
    required this.courseCode,
    required this.courseName,
    required this.courseSeq,
    required this.credits,
    required this.category,
    required this.examType,
    required this.department,
    required this.teachers,
  });

  factory CourseSectionInfo.fromJson(Map<String, dynamic> json) =>
      CourseSectionInfo(
        planCode: json['ZXJXJHH'] as String? ?? '',
        planName: json['ZXJXJHM'] as String? ?? '',
        courseCode: json['KCH'] as String? ?? '',
        courseName: json['KCM'] as String? ?? '',
        courseSeq: json['KXH'] as String? ?? '',
        credits: json['XF'] as String? ?? '',
        category: json['KCLBMC'] as String? ?? '',
        examType: json['KSLXMC'] as String? ?? '',
        department: json['KKXSM'] as String? ?? '',
        teachers: json['JSM'] as String? ?? '',
      );
}

/// 课程类别筛选选项
class CourseCategoryOption {
  final String code; // e.g. "5"
  final String name; // e.g. "国际周课程"

  CourseCategoryOption({required this.code, required this.name});
}
