/// 培养进度计算：把成绩行归并到培养方案的课程类别上。
///
/// 数据链（2026-09-21 抓包定案）：
/// - 要求学分（总 ZDXF / 每类 ZDXF）来自 `wdkclbtj.do`；
/// - KCDM → 课程类别的归属来自 `wdfakcxx.do` 的方案课程明细；
/// - 已修 = 成绩行（`xscjcx.do`）里**及格且有效**的课程；同一课程代码
///   多次通过（重修/补考）只计一次，学分取首条及格记录。
///
/// 口径约定：
/// - **方案内已修**（[graduateTrainPlanEarnedInPlan]）与方案要求（ZDXF）
///   同口径，用作总进度的分子；
/// - 建课程→类别映射时**跳过 wdfakcxx 里的「方案外」行**（实测混有此类
///   选课行），其成绩落「方案外」区块单列展示；
/// - 归属到方案课程、但其类别码不在分类要求行里的已修课，进「未匹配
///   类别」兜底区块（属方案内、无要求分），**绝不静默丢学分**；
/// - 方案课程明细里完全找不到的成绩行落「方案外」区块，单列展示，
///   不计入总进度的分子。
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
    this.outOfPlan = false,
  });

  /// 区块标题（类别名；兜底区块用类别码/名称，方案外区块用数据原文）。
  final String title;

  /// 该区块已修（通过）学分。
  final double earnedCredits;

  /// 该区块要求学分（无要求定义的区块为 0，UI 不画进度条）。
  final double requiredCredits;

  /// 已修课程（按学期序，每门课取首条及格记录）。
  final List<GraduateGradeRow> rows;

  /// 是否方案外区块（不计入方案内已修总和）。
  final bool outOfPlan;
}

/// 归并主入口：返回全部区块。
///
/// 顺序：wdkclbtj 分类行主序 → 方案内「未匹配类别」兜底区块（方案课程
/// 的 kclbdm 有成绩落、但分类行没有该码）→「方案外」垫底。
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

  // 方案课程 → 类别。**跳过「方案外」行**：fakcxx 实测混有方案外选课行
  // （2026-09-21 抓包 66 行中 18 行，如导师要求的专业课），它们不算方案内，
  // 其成绩应落「方案外」区块，否则会被算进方案内分子（口径泄漏）。
  final planCategoryByCourse = <String, String>{
    for (final course in planCourses)
      if (course.kcdm.isNotEmpty && !course.outOfPlan)
        course.kcdm: course.kclbdm,
  };

  // 按类别归已修行；方案内匹配不到的进 outOfPlan。
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

  // 方案内兜底：分类行里没有、但方案课程确实归类了的类别码。
  final coveredCodes = {for (final category in categories) category.dm};
  final orphanTitles = <String, String>{};
  for (final course in planCourses) {
    final code = course.kclbdm;
    if (code.isEmpty || coveredCodes.contains(code)) continue;
    orphanTitles[code] ??= course.kclbdmDisplay.isNotEmpty
        ? course.kclbdmDisplay
        : code;
  }

  final sections = [
    for (final category in categories)
      TrainPlanProgressSection(
        title: category.mc.isEmpty ? category.dm : category.mc,
        earnedCredits: _creditsOf(rowsByCategory[category.dm] ?? const []),
        requiredCredits: category.requiredCredits,
        rows: rowsByCategory[category.dm] ?? const [],
      ),
    // 未匹配类别兜底：这些行已在方案内归类，只是分类行缺码。
    for (final entry in orphanTitles.entries)
      TrainPlanProgressSection(
        title: entry.value,
        earnedCredits: _creditsOf(rowsByCategory[entry.key] ?? const []),
        requiredCredits: 0.0,
        rows: rowsByCategory[entry.key] ?? const [],
      ),
  ];
  if (outOfPlan.isNotEmpty) {
    sections.add(
      TrainPlanProgressSection(
        title: '方案外',
        earnedCredits: _creditsOf(outOfPlan),
        requiredCredits: 0.0,
        rows: outOfPlan,
        outOfPlan: true,
      ),
    );
  }
  return sections;
}

/// 方案内已修学分总和：全部**非方案外**区块每门及格课程计一次
/// （行已按课程代码去重）。与 [GraduateTrainPlanCreditStats.requiredCredits]
/// 同口径，作总进度分子。
double graduateTrainPlanEarnedInPlan(List<TrainPlanProgressSection> sections) {
  var total = 0.0;
  for (final section in sections) {
    if (section.outOfPlan) continue;
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
