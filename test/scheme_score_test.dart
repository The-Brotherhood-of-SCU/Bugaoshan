import 'package:bugaoshan/models/scheme_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchemeScoreItem.fromJson courseScore 取值', () {
    // schemeScores 接口（2026-09 起）：courseScore 嵌在复合主键 id 对象里
    test('parses courseScore nested inside the id object', () {
      final item = SchemeScoreItem.fromJson(_schemeItemJson());
      expect(item.courseScore, 74.0);
      expect(item.gradePointScore, 3.0);
    });

    // allPassingScores 接口：courseScore 仍在顶层，不能回归
    test('still parses top-level courseScore from passing scores', () {
      final item = SchemeScoreItem.fromJson({
        ..._schemeItemJson()..remove('id'),
        'courseScore': 74.0,
      });
      expect(item.courseScore, 74.0);
    });

    test('nested courseScore wins when both locations exist', () {
      final item = SchemeScoreItem.fromJson({
        ..._schemeItemJson(),
        'courseScore': 1.0,
      });
      expect(item.courseScore, 74.0);
    });
  });

  group('均分统计（真实响应形状）', () {
    test('weighted averages ignore invalid scores and compute correctly', () {
      final summary = SchemeScoreSummary.fromJson({
        'lnList': [
          {
            'cjlx': '计算机科学与技术培养方案',
            'cjList': [
              _schemeItemJson(), // 必修 74 分 3 学分
              {
                ..._schemeItemJson(),
                'courseName': '形势与政策-6',
                'credit': '0',
              }, // 必修 0 学分，不计
              {
                ..._schemeItemJson(),
                'courseName': '体育四',
                'courseAttributeName': '任选',
                'gradePointScore': -1, // 无效绩点，不计
              },
            ],
          },
        ],
      });

      expect(summary.weightedAvgScore, 74.0);
      expect(summary.requiredWeightedAvgScore, 74.0);
      expect(summary.requiredGpa, 3.0);
    });
  });
}

/// 与 schemeScores 接口真实返回一致的形状：courseScore 在 id 里
Map<String, dynamic> _schemeItemJson() => {
  'id': {
    'executiveEducationPlanNumber': '2025-2026-2-1',
    'courseNumber': '304475020',
    'courseScore': 74.0,
  },
  'courseName': '编译原理',
  'englishCourseName': 'Principle of Compiler',
  'courseAttributeName': '必修',
  'credit': '3',
  'cj': '74.0',
  'gradePointScore': 3.0,
  'gradeName': 'B-',
  'academicYearCode': '2025-2026',
  'termName': '春',
};
