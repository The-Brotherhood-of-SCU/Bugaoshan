/// 班级课表 - 班级列表中的一个班级
class ClassInfo {
  final String planCode; // executiveEducationPlanNumber
  final String classCode; // classNum
  final String planName; // executiveEducationPlanName
  final String className; // className
  final String departmentName;
  final String subjectName;

  ClassInfo({
    required this.planCode,
    required this.classCode,
    required this.planName,
    required this.className,
    required this.departmentName,
    required this.subjectName,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as Map<String, dynamic>;
    return ClassInfo(
      planCode: id['executiveEducationPlanNumber'] as String? ?? '',
      classCode: id['classNum'] as String? ?? '',
      planName: json['executiveEducationPlanName'] as String? ?? '',
      className: json['className'] as String? ?? '',
      departmentName: json['departmentName'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
    );
  }
}

/// 学年学期筛选选项
class SemesterOption {
  final String value; // e.g. "2026-2027-1-1"
  final String label; // e.g. "2026-2027学年秋"

  SemesterOption({required this.value, required this.label});

  factory SemesterOption.fromSelectOption(String value, String label) =>
      SemesterOption(value: value, label: label);
}

/// 院系筛选选项
class DepartmentOption {
  final String value; // e.g. "201"
  final String name; // e.g. "数学学院"

  DepartmentOption({required this.value, required this.name});
}

/// 专业筛选选项
class SubjectOption {
  final String code; // e.g. "0701018"
  final String name; // e.g. "数学与智能科技双学士学位"

  SubjectOption({required this.code, required this.name});

  factory SubjectOption.fromJson(Map<String, dynamic> json) => SubjectOption(
    code: json['subjectCode'] as String? ?? '',
    name: json['subjectName'] as String? ?? '',
  );
}

/// 班级筛选选项
class ClassOption {
  final String code; // e.g. "242010801"
  final String name; // e.g. "242010801"

  ClassOption({required this.code, required this.name});

  factory ClassOption.fromJson(Map<String, dynamic> json) => ClassOption(
    code: json['classCode'] as String? ?? '',
    name: json['className'] as String? ?? '',
  );
}

/// 班级课表 - 课表中的一门课程
class ClassScheduleInquiryItem {
  final int dayOfWeek; // skxq: 1-7 (星期一~星期日)
  final int startPeriod; // skjc: 开始节次
  final int duration; // cxjc: 持续节数
  final String courseCode; // kch: 课程号
  final String courseSeq; // kxh: 课序号
  final String courseName; // kcm: 课程名
  final String teacherName; // jsm: 教师名
  final String weeksDescription; // zcsm: 周次说明
  final String campus; // xqm: 校区
  final String building; // jxlm: 教学楼
  final String classroom; // jasm: 教室

  ClassScheduleInquiryItem({
    required this.dayOfWeek,
    required this.startPeriod,
    required this.duration,
    required this.courseCode,
    required this.courseSeq,
    required this.courseName,
    required this.teacherName,
    required this.weeksDescription,
    required this.campus,
    required this.building,
    required this.classroom,
  });

  factory ClassScheduleInquiryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as Map<String, dynamic>;
    return ClassScheduleInquiryItem(
      dayOfWeek: int.tryParse(id['skxq']?.toString() ?? '') ?? 0,
      startPeriod: int.tryParse(id['skjc']?.toString() ?? '') ?? 0,
      duration: int.tryParse(json['cxjc']?.toString() ?? '') ?? 0,
      courseCode: id['kch'] as String? ?? '',
      courseSeq: id['kxh'] as String? ?? '',
      courseName: json['kcm'] as String? ?? '',
      teacherName: json['jsm'] as String? ?? '',
      weeksDescription: json['zcsm'] as String? ?? '',
      campus: json['xqm'] as String? ?? '',
      building: json['jxlm'] as String? ?? '',
      classroom: json['jasm'] as String? ?? '',
    );
  }
}
