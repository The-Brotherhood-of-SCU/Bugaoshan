/// 培养进度计算：把成绩行归并到培养方案的课程类别上。
///
/// 数据链（2026-09-21 抓包定案）：
/// - 要求学分（总 ZDXF / 每类 ZDXF）来自 `wdkclbtj.do`；
/// - KCDM → 课程类别的归属来自 `wdfakcxx.do` 的方案课程明细；
/// - 已修 = 成绩行（`xscjcx.do`）里**及格且有效**的课程；同一课程代码
///   多次通过（重修/补考）只计一次，学分取首条及格记录；
/// - 方案课程明细里找不到的成绩行视为「方案外」课程。
///
/// 注意：培养计划官方页的「当前选课学分」是**选课侧**口径（含未出成绩的
/// 在修课程），与本文件「已修（通过）」口径不同，不要混用。
library;

import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/models/graduate_train_plan.dart';

/// 一个课程类别的已修汇总区块。
class TrainPlanProgressSection {
  const TrainPlanProgressSection({
    required this.title,
    required this.earnedCredits,
    required this.requiredCredits,
    required this.rows,
  });

  /// 类别名（方案外的区块标题用数据原文「方案外」）。
  final String title;

  /// 该类已修（通过）学分。
  final double earnedCredits;

  /// 该类要求学分（方案外区块为 0，UI 不画进度条）。
  final double requiredCredits;

  /// 已修课程（按学期序，每门课取首条及格记录）。
  final List<GraduateGradeRow> rows;
}

/// 培养进度计算结果。
class TrainPlanProgress {
  const TrainPlanProgress({required this.sections, required this.earnedTotal});

  /// 各区块（方案类别为主序，方案外垫底）。
  final List<TrainPlanProgressSection> sections;

  /// 已修（通过）学分总和，含方案外。
  final double earnedTotal;
}

/// 归并主入口。
List<TrainPlanProgressSection> graduateTrainPlanSections({
  required List<GraduateTrainPlanCategoryProgress> categories,
  required List<GraduateTrainPlanCourse> planCourses,
  required List<GraduateGradeRow> gradeRows,
}) {
  // 及格且有效的成绩行；同 KCDM 只保留首条（重修/补考不重复计学分）。
  final passedByCourse = <String, GraduateGradeRow>{};
  for (final row in gradeRows) {
    if (!row.passed || !row.valid) continue;
    if (row.courseCode.isEmpty) continue;
    passedByCourse.putIfAbsent(row.courseCode, () => row);
  }

  // 方案课程 → 类别。
  final planCategoryByCourse = <String, String>{
    for (final course in planCourses)
      if (course.kcdm.isNotEmpty) course.kcdm: course.kclbdm,
  };

  // 按类别归已修行。
  final rowsByCategory = <String, List<GraduateGradeRow>>{};
  final outOfPlan = <GraduateGradeRow>[];
  for (final row in passedByCourse.values) {
    final kclbdm = planCategoryByCourse[row.courseCode];
    if (kclbdm == null || kclbdm.isEmpty) {
      outOfPlan.add(row);
      continue;
    }
    rowsByCategory.putIfAbsent(kclbdm, () => []).add(row);
  }

  final sections = [
    for (final category in categories)
      TrainPlanProgressSection(
        title: category.mc.isEmpty ? category.dm : category.mc,
        earnedCredits: _creditsOf(rowsByCategory[category.dm] ?? const []),
        requiredCredits: category.requiredCredits,
        rows: rowsByCategory[category.dm] ?? const [],
      ),
  ];
  if (outOfPlan.isNotEmpty) {
    sections.add(
      TrainPlanProgressSection(
        title: '方案外',
        earnedCredits: _creditsOf(outOfPlan),
        requiredCredits: 0.0,
        rows: outOfPlan,
      ),
    );
  }
  return sections;
}

/// 已修学分总和：全部区块每门及格课程计一次（行已按课程代码去重）。
double graduateTrainPlanEarnedTotal(List<TrainPlanProgressSection> sections) {
  var total = 0.0;
  for (final section in sections) {
    for (final row in section.rows) {
      total += row.credit;
    }
  }
  return total;
}

double _creditsOf(List<GraduateGradeRow> rows) {
  var total = 0.0;
  for (final row in rows) {
    total += row.credit;
  }
  return total;
}

/// 学分数字显示：整数去尾零（14.0 → 14），其余原样（5.5 → 5.5）。
String graduateTrainPlanFmtCredits(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';
