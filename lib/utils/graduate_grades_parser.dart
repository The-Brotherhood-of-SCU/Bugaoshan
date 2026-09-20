import 'package:bugaoshan/models/graduate_grades.dart';

/// 研究生成绩行列表解析：GS 信封解包后的 rows → [GraduateGradeRow]。
List<GraduateGradeRow> graduateGradeRowsFromJson(List<dynamic> rows) {
  return [
    for (final row in rows)
      if (row is Map<String, dynamic>) GraduateGradeRow.fromJson(row),
  ];
}

/// 由成绩行计算统计四指标；rows 为空返回 null（页面呈现「暂无成绩」空态）。
///
/// 口径见 [GraduateGradesStats]：计数按有效行，加权均分只算有百分成绩的行，
/// 通过率按门数占比。
GraduateGradesStats? graduateGradesStatsFromRows(
  List<GraduateGradeRow> rows,
) {
  final valid = rows.where((row) => row.valid).toList();
  if (valid.isEmpty) return null;

  final totalCredit = valid.fold<double>(0, (sum, row) => sum + row.credit);
  final weighted = valid.where((row) => row.percentile != null).toList();
  double? weightedAverage;
  if (weighted.isNotEmpty) {
    final creditSum = weighted.fold<double>(0, (sum, row) => sum + row.credit);
    weightedAverage = creditSum > 0
        ? weighted.fold<double>(
                0,
                (sum, row) => sum + row.percentile! * row.credit,
              ) /
              creditSum
        : null;
  }

  return GraduateGradesStats(
    courseCount: valid.length,
    totalCredit: totalCredit,
    passedCount: valid.where((row) => row.passed).length,
    weightedAverage: weightedAverage,
  );
}
