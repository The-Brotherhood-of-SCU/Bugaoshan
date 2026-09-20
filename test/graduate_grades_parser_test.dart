import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/utils/graduate_grades_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('免修通过样本行解析：编码成绩不误当数字，百分成绩与及格标志正确', () {
    final row = GraduateGradeRow.fromJson(const {
      'KCDM': 'S00000101',
      'KCMC': '学术英语（中级）',
      'KCMCYW': 'English for Academic Purpose (Intermediate)',
      'XNXQDM': '20261',
      'XNXQDM_DISPLAY': '2026年 秋季学期',
      'KCLBMC': '必修课',
      'CJ': '008',
      'CJXSZ': '免修通过',
      'CJXSZYWMC': 'Passed',
      'CJFZDM_DISPLAY': '免修通过制',
      'DYBFZCJ': 80.0,
      'XF': 2.0,
      'JDZ': 0.0,
      'SFJG': 1,
      'SFYX': 1,
      'KSXZDM_DISPLAY': '首修',
      'BZSM': '免修合格',
    });

    expect(row.courseCode, 'S00000101');
    expect(row.courseName, '学术英语（中级）');
    expect(row.termCode, '20261');
    expect(row.credit, 2.0);
    expect(row.gradeText, '008');
    expect(row.gradeDisplay, '免修通过');
    expect(row.percentile, 80.0);
    expect(row.percentileLabel, '80');
    expect(row.passed, isTrue);
    expect(row.valid, isTrue);
    expect(row.remark, '免修合格');
  });

  test('字段缺省与脏值容错：DYBFZCJ 非数值、SFJG 缺省', () {
    final row = GraduateGradeRow.fromJson(const {
      'KCDM': 'S00000102',
      'KCMC': '自然辩证法',
      'XNXQDM': 20261,
      'XF': '3.0',
      'DYBFZCJ': 'not-a-number',
      'SFJG': '0',
      'SFYX': 0,
    });

    expect(row.termCode, '20261');
    expect(row.credit, 3.0);
    expect(row.percentile, isNull);
    expect(row.percentileLabel, isNull);
    expect(row.passed, isFalse);
    expect(row.valid, isFalse);
  });

  test('统计口径：计数按有效行，加权均分只算有百分成绩的行，通过率按门数', () {
    final rows = graduateGradeRowsFromJson([
      // 85.0×3 + 80.0×2 = 415，除以 5 → 83.0
      {'KCMC': '课程A', 'XF': 3.0, 'DYBFZCJ': 85.0, 'SFJG': 1, 'SFYX': 1},
      {'KCMC': '课程B', 'XF': 2.0, 'DYBFZCJ': 80.0, 'SFJG': 0, 'SFYX': 1},
      // 无百分成绩的两级制行：参与门数与学分，不参与均分
      {'KCMC': '课程C', 'XF': 1.0, 'CJXSZ': '通过', 'SFJG': 1, 'SFYX': 1},
      // 无效行不进统计
      {'KCMC': '课程D', 'XF': 2.0, 'DYBFZCJ': 60.0, 'SFJG': 0, 'SFYX': 0},
    ]);

    final stats = graduateGradesStatsFromRows(rows);

    expect(stats, isNotNull);
    expect(stats!.courseCount, 3);
    expect(stats.totalCredit, 6.0);
    expect(stats.passedCount, 2);
    expect(stats.weightedAverage, closeTo(83.0, 1e-9));
    expect(stats.passRate, closeTo(66.6667, 0.0001));
  });

  test('全部学分都在无百分成绩的行上时，加权均分为 null', () {
    final rows = graduateGradeRowsFromJson([
      {'KCMC': '课程A', 'XF': 2.0, 'CJXSZ': '通过', 'SFJG': 1, 'SFYX': 1},
    ]);

    final stats = graduateGradesStatsFromRows(rows)!;

    expect(stats.courseCount, 1);
    expect(stats.totalCredit, 2.0);
    expect(stats.weightedAverage, isNull);
  });

  test('rows 为空或全无效 → null，页面呈现空态', () {
    expect(graduateGradesStatsFromRows(const []), isNull);
    expect(
      graduateGradesStatsFromRows([
        GraduateGradeRow.fromJson(const {
          'KCMC': '无效行',
          'XF': 1.0,
          'SFYX': 0,
        }),
      ]),
      isNull,
    );
  });

  test('非 Map 行被跳过不抛错', () {
    final rows = graduateGradeRowsFromJson([
      {'KCMC': '课程A', 'XF': 2.0, 'SFJG': 1, 'SFYX': 1},
      'garbage',
      null,
    ]);

    expect(rows, hasLength(1));
    expect(rows.single.courseName, '课程A');
  });

  test('副显示与备注冗余判定', () {
    // 免修样本：副显示给百分成绩 80（与「免修通过」不同），备注冗余。
    final exempt = GraduateGradeRow.fromJson(const {
      'KCMC': '学术英语（中级）',
      'CJ': '008',
      'CJXSZ': '免修通过',
      'CJFZDM_DISPLAY': '免修通过制',
      'DYBFZCJ': 80.0,
      'BZSM': '免修合格',
    });
    expect(exempt.gradeSubLabel, '80');
    expect(exempt.remarkIsRedundant, isTrue);

    // 百分制样本：百分成绩与显示值相同 → 无副显示；备注不同 → 不冗余。
    final graded = GraduateGradeRow.fromJson(const {
      'KCMC': '矩阵论',
      'CJXSZ': '85',
      'CJFZDM_DISPLAY': '百分制',
      'DYBFZCJ': 85.0,
      'BZSM': '缓考',
    });
    expect(graded.gradeSubLabel, isNull);
    expect(graded.remarkIsRedundant, isFalse);

    // 两级制样本：无百分成绩 → 显示分制标签。
    final level = GraduateGradeRow.fromJson(const {
      'KCMC': '学术规范',
      'CJXSZ': '通过',
      'CJFZDM_DISPLAY': '两级制',
    });
    expect(level.gradeSubLabel, '两级制');
  });
}
