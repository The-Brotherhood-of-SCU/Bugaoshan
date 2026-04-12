class SchemeScoreItem {
  final String courseName;
  final String courseAttributeName; // 必修/选修/任选
  final String credit;
  final String cj; // 原始成绩
  final double courseScore;
  final double gradePointScore;
  final String gradeName; // A/B+/F 等
  final String academicYearCode;
  final String termName; // 秋/春
  final bool passed; // gradeName != 'F'

  const SchemeScoreItem({
    required this.courseName,
    required this.courseAttributeName,
    required this.credit,
    required this.cj,
    required this.courseScore,
    required this.gradePointScore,
    required this.gradeName,
    required this.academicYearCode,
    required this.termName,
    required this.passed,
  });

  factory SchemeScoreItem.fromJson(Map<String, dynamic> json) {
    final gradeName = json['gradeName']?.toString() ?? '';
    return SchemeScoreItem(
      courseName: json['courseName']?.toString() ?? '',
      courseAttributeName: json['courseAttributeName']?.toString() ?? '',
      credit: json['credit']?.toString() ?? '0',
      cj: json['cj']?.toString() ?? '',
      courseScore: (json['courseScore'] as num?)?.toDouble() ?? 0.0,
      gradePointScore: (json['gradePointScore'] as num?)?.toDouble() ?? 0.0,
      gradeName: gradeName,
      academicYearCode: json['academicYearCode']?.toString() ?? '',
      termName: json['termName']?.toString() ?? '',
      passed: gradeName != 'F' && gradeName.isNotEmpty,
    );
  }
}

class SchemeScoreSummary {
  final double zxf; // 总学分
  final double yxxf; // 已修学分
  final int tgms; // 通过门数
  final int wtgms; // 未通过门数
  final int zms; // 总门数
  final String cjlx; // 方案名称
  final List<SchemeScoreItem> items;

  const SchemeScoreSummary({
    required this.zxf,
    required this.yxxf,
    required this.tgms,
    required this.wtgms,
    required this.zms,
    required this.cjlx,
    required this.items,
  });

  factory SchemeScoreSummary.fromJson(Map<String, dynamic> json) {
    final lnList = json['lnList'] as List?;
    final first =
        (lnList?.isNotEmpty == true ? lnList![0] : null)
            as Map<String, dynamic>?;
    final cjList =
        (first?['cjList'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SchemeScoreItem.fromJson)
            .toList() ??
        [];

    return SchemeScoreSummary(
      zxf: (first?['zxf'] as num?)?.toDouble() ?? 0.0,
      yxxf: (first?['yxxf'] as num?)?.toDouble() ?? 0.0,
      tgms: (first?['tgms'] as num?)?.toInt() ?? 0,
      wtgms: (first?['wtgms'] as num?)?.toInt() ?? 0,
      zms: (first?['zms'] as num?)?.toInt() ?? 0,
      cjlx: first?['cjlx']?.toString() ?? '',
      items: cjList,
    );
  }

  // 按学年+学期分组，返回有序列表 [(label, items)]
  List<({String label, List<SchemeScoreItem> items})> get groupedByTerm {
    final map = <String, List<SchemeScoreItem>>{};
    for (final item in items) {
      final key = '${item.academicYearCode} ${item.termName}学期';
      map.putIfAbsent(key, () => []).add(item);
    }
    // 按学年倒序排列
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) => (label: k, items: map[k]!)).toList();
  }

  double get gpa {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final item in items) {
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit > 0 && item.passed) {
        totalPoints += item.gradePointScore * credit;
        totalCredits += credit;
      }
    }
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  /// 必修 GPA
  double get requiredGpa {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final item in items) {
      if (!item.passed || item.courseAttributeName != '必修') continue;
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit <= 0) continue;
      totalPoints += item.gradePointScore * credit;
      totalCredits += credit;
    }
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  /// 已修学分（仅计及格课程）
  double get earnedCredits {
    return items.fold(0.0, (sum, item) {
      if (!item.passed) return sum;
      return sum + (double.tryParse(item.credit) ?? 0);
    });
  }

  /// 平均成绩：及格科目的学分加权平均分
  double get weightedAvgScore {
    double totalScore = 0;
    double totalCredits = 0;
    for (final item in items) {
      if (!item.passed) continue;
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit <= 0) continue;
      totalScore += item.courseScore * credit;
      totalCredits += credit;
    }
    return totalCredits > 0 ? totalScore / totalCredits : 0.0;
  }

  /// 必修均分：及格必修科目的学分加权均分
  double get requiredWeightedAvgScore {
    double totalScore = 0;
    double totalCredits = 0;
    for (final item in items) {
      if (!item.passed || item.courseAttributeName != '必修') continue;
      final credit = double.tryParse(item.credit) ?? 0;
      if (credit <= 0) continue;
      totalScore += item.courseScore * credit;
      totalCredits += credit;
    }
    return totalCredits > 0 ? totalScore / totalCredits : 0.0;
  }

  /// 必修已修学分（及格）
  double get requiredCredits => _creditsByAttr('必修');

  /// 选修已修学分（及格）
  double get electiveCredits => _creditsByAttr('选修');

  /// 任选已修学分（及格）
  double get optionalCredits => _creditsByAttr('任选');

  double _creditsByAttr(String attr) => items.fold(0.0, (sum, item) {
    if (!item.passed || item.courseAttributeName != attr) return sum;
    return sum + (double.tryParse(item.credit) ?? 0);
  });
}

/// 及格成绩 - 单学期分组
class PassingScoreGroup {
  final String label; // cjlx，如 "2023-2024学年秋(两学期)"
  final double yxxf;
  final int tgms;
  final int wtgms;
  final List<SchemeScoreItem> items;

  const PassingScoreGroup({
    required this.label,
    required this.yxxf,
    required this.tgms,
    required this.wtgms,
    required this.items,
  });

  factory PassingScoreGroup.fromJson(Map<String, dynamic> json) {
    final items =
        (json['cjList'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SchemeScoreItem.fromJson)
            .toList() ??
        [];
    return PassingScoreGroup(
      label: json['cjlx']?.toString() ?? '',
      yxxf: (json['yxxf'] as num?)?.toDouble() ?? 0.0,
      tgms: (json['tgms'] as num?)?.toInt() ?? 0,
      wtgms: (json['wtgms'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }
}

/// 及格成绩 - 完整结果
class PassingScoreResult {
  final List<PassingScoreGroup> groups; // 已按学期倒序排列

  const PassingScoreResult({required this.groups});

  factory PassingScoreResult.fromJson(Map<String, dynamic> json) {
    final lnList =
        (json['lnList'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(PassingScoreGroup.fromJson)
            .toList() ??
        [];
    // 倒序：最新学期在前，同学年内春季在前、秋季在后
    lnList.sort((a, b) {
      // zxjxjhh 格式如 "2024-2025-2-1"，直接比较可以正确排序
      // 但这里用 label 里的学年+termCode 来排
      // label 格式: "2024-2025学年春(两学期)" / "2024-2025学年秋(两学期)"
      // 提取学年部分做主排序，再用春/秋做次排序（春>秋，因为春是第2学期）
      final yearA = a.label.substring(0, 9); // "2024-2025"
      final yearB = b.label.substring(0, 9);
      final cmp = yearB.compareTo(yearA); // 学年倒序
      if (cmp != 0) return cmp;
      // 同学年：春(termCode=2) 排前，秋(termCode=1) 排后
      final isSpringA = a.label.contains('春');
      final isSpringB = b.label.contains('春');
      if (isSpringA && !isSpringB) return -1;
      if (!isSpringA && isSpringB) return 1;
      return 0;
    });
    return PassingScoreResult(groups: lnList);
  }

  double get gpa {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final g in groups) {
      for (final item in g.items) {
        final credit = double.tryParse(item.credit) ?? 0;
        if (credit > 0 && item.passed) {
          totalPoints += item.gradePointScore * credit;
          totalCredits += credit;
        }
      }
    }
    return totalCredits > 0 ? totalPoints / totalCredits : 0.0;
  }

  double get totalCredits => groups.fold(0.0, (sum, g) => sum + g.yxxf);

  int get totalPassed => groups.fold(0, (sum, g) => sum + g.tgms);

  /// 平均成绩：所有及格科目的学分加权平均分
  double get weightedAvgScore {
    double totalScore = 0;
    double totalCredits = 0;
    for (final g in groups) {
      for (final item in g.items) {
        if (!item.passed) continue;
        final credit = double.tryParse(item.credit) ?? 0;
        if (credit <= 0) continue;
        totalScore += item.courseScore * credit;
        totalCredits += credit;
      }
    }
    return totalCredits > 0 ? totalScore / totalCredits : 0.0;
  }

  /// 必修均分：所有及格必修科目的学分加权均分
  double get requiredWeightedAvgScore {
    double totalScore = 0;
    double totalCredits = 0;
    for (final g in groups) {
      for (final item in g.items) {
        if (!item.passed || item.courseAttributeName != '必修') continue;
        final credit = double.tryParse(item.credit) ?? 0;
        if (credit <= 0) continue;
        totalScore += item.courseScore * credit;
        totalCredits += credit;
      }
    }
    return totalCredits > 0 ? totalScore / totalCredits : 0.0;
  }
}
