import 'package:flutter/material.dart';

/// 体测通知。
class FitnessNotice {
  final String title;
  final String content;
  final String plainContent;
  final String createTime;
  final int readNum;
  final bool isSticky;

  const FitnessNotice({
    required this.title,
    required this.content,
    required this.plainContent,
    required this.createTime,
    required this.readNum,
    required this.isSticky,
  });

  factory FitnessNotice.fromJson(Map<String, dynamic> json) {
    final content = json['content']?.toString() ?? '';
    return FitnessNotice(
      title: json['title']?.toString() ?? '',
      content: content,
      plainContent: stripFitnessHtml(content),
      createTime: json['create_time']?.toString() ?? '',
      readNum: _toInt(json['read_num']),
      isSticky: json['is_stick'] == 1 || json['is_stick']?.toString() == '1',
    );
  }

  /// 将通知 HTML 转为可阅读的纯文本。
  ///
  /// 与页面原有 [_stripHtml] 行为一致，抽至此处使 Page 不再承担解析职责。
  static String stripFitnessHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<p>|<p\s[^>]*>'), '')
        .replaceAll('</p>', '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is num) return value.toInt();
  return 0;
}

/// 单项体测成绩（BMI / 肺活量 / 立定跳远 …）。
class FitnessScoreItem {
  final String rawScore;
  final String gradedScore;
  final String grade;
  final String colorClass;

  const FitnessScoreItem({
    required this.rawScore,
    required this.gradedScore,
    required this.grade,
    required this.colorClass,
  });

  bool get isFail => colorClass == 'red';
}

/// 体测总成绩。
class FitnessScore {
  final int totalScore;
  final String totalGrade;
  final String studentName;
  final String studentNum;
  final String sex;
  final String studentYear;
  final String reportType;
  final String reportStatus;

  final FitnessScoreItem bmi;
  final FitnessScoreItem vitalCapacity;
  final FitnessScoreItem jump;
  final FitnessScoreItem sitAndReach;
  final FitnessScoreItem pullAndSit;
  final FitnessScoreItem fiftyM;
  final FitnessScoreItem run;

  const FitnessScore({
    required this.totalScore,
    required this.totalGrade,
    required this.studentName,
    required this.studentNum,
    required this.sex,
    required this.studentYear,
    required this.reportType,
    required this.reportStatus,
    required this.bmi,
    required this.vitalCapacity,
    required this.jump,
    required this.sitAndReach,
    required this.pullAndSit,
    required this.fiftyM,
    required this.run,
  });

  factory FitnessScore.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '-';
    String scoreStr(String key) => json[key]?.toString() ?? '-';
    String gradeStr(String key) => json[key]?.toString() ?? '-';
    String classStr(String key) => json[key]?.toString() ?? 'green';

    return FitnessScore(
      totalScore: _toInt(json['total_score']),
      totalGrade: s(json['total_grade']),
      studentName: s(json['student_name']),
      studentNum: s(json['student_num']),
      sex: s(json['sex']),
      studentYear: s(json['studentYear']),
      reportType: s(json['report_type']),
      reportStatus: s(json['report_status']),
      bmi: FitnessScoreItem(
        rawScore: scoreStr('bmi_score'),
        gradedScore: scoreStr('bmi_score2'),
        grade: gradeStr('bmi_grade'),
        colorClass: classStr('bmi_class'),
      ),
      vitalCapacity: FitnessScoreItem(
        rawScore: scoreStr('vc_score'),
        gradedScore: scoreStr('vc_score2'),
        grade: gradeStr('vc_grade'),
        colorClass: classStr('vc_class'),
      ),
      jump: FitnessScoreItem(
        rawScore: scoreStr('jump_score'),
        gradedScore: scoreStr('jump_score2'),
        grade: gradeStr('jump_grade'),
        colorClass: classStr('jump_class'),
      ),
      sitAndReach: FitnessScoreItem(
        rawScore: scoreStr('sit_and_reach_score'),
        gradedScore: scoreStr('sit_and_reach_score2'),
        grade: gradeStr('sit_and_reach_grade'),
        colorClass: classStr('sit_and_reach_class'),
      ),
      pullAndSit: FitnessScoreItem(
        rawScore: scoreStr('pull_and_sit_score'),
        gradedScore: scoreStr('pull_and_sit_score2'),
        grade: gradeStr('pull_and_sit_grade'),
        colorClass: classStr('pull_and_sit_class'),
      ),
      fiftyM: FitnessScoreItem(
        rawScore: scoreStr('50m_score'),
        gradedScore: scoreStr('50m_score2'),
        grade: gradeStr('50m_grade'),
        colorClass: classStr('50m_class'),
      ),
      run: FitnessScoreItem(
        rawScore: scoreStr('run_score'),
        gradedScore: scoreStr('run_score2'),
        grade: gradeStr('run_grade'),
        colorClass: classStr('run_class'),
      ),
    );
  }

  /// 总分等级对应的展示颜色，与原 Page [_getGradeColor] 一致。
  Color gradeColorFor(BuildContext context) {
    final grade = totalGrade;
    if (grade.contains('优秀') || grade.contains('Excellent')) {
      return Colors.blue;
    }
    if (grade.contains('良好') || grade.contains('Good')) return Colors.green;
    if (grade.contains('及格') || grade.contains('Pass')) return Colors.orange;
    if (grade.contains('不及格') || grade.contains('Fail')) {
      return Colors.red;
    }
    return Colors.grey;
  }
}
