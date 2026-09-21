/// 研究生成绩行（ehall `xscjcx.do`，2026-09-20 抓包定案）。
///
/// 与本科 SchemeScore 语义不通用，独立平行模型：
/// - 数值分数用 `DYBFZCJ`（对应百分成绩），`CJ` 是分制内的编码原文
///   （如免修通过制下是 "008"），**不能**当数字解析；
/// - 及格与否看 `SFJG`，成绩对外显示值看 `CJXSZ`（如「免修通过」「85」）。
library;

/// 一门课的一条成绩记录。
class GraduateGradeRow {
  const GraduateGradeRow({
    required this.courseCode,
    required this.courseName,
    required this.termCode,
    required this.credit,
    required this.passed,
    required this.valid,
    this.courseNameEn,
    this.termName,
    this.category,
    this.gradeText,
    this.gradeDisplay,
    this.gradingSystem,
    this.percentile,
    this.gradePoint,
    this.attemptType,
    this.remark,
  });

  /// 课程代码（KCDM）。
  final String courseCode;

  /// 课程名（KCMC）。
  final String courseName;

  /// 课程英文名（KCMCYW），缺省 null。
  final String? courseNameEn;

  /// 学期 5 位码（XNXQDM，如 20261）。
  final String termCode;

  /// 学期显示名（XNXQDM_DISPLAY，如「2026年 秋季学期」）。
  final String? termName;

  /// 课程类别（KCLBMC，如「必修课」）。
  final String? category;

  /// 成绩原文（CJ）：分制内的编码字符串，不保证可当数字。
  final String? gradeText;

  /// 成绩显示值（CJXSZ，如「免修通过」）。
  final String? gradeDisplay;

  /// 成绩分制（CJFZDM_DISPLAY，如「免修通过制」「百分制」）。
  final String? gradingSystem;

  /// 对应百分成绩（DYBFZCJ）：加权均分的数值来源；非百分制或缺省为 null。
  final double? percentile;

  /// 学分（XF）。
  final double credit;

  /// 绩点值（JDZ），缺省 null。
  final double? gradePoint;

  /// 是否及格（SFJG == 1）。
  final bool passed;

  /// 是否有效（SFYX == 1）。
  final bool valid;

  /// 考试性质显示名（KSXZDM_DISPLAY，如「首修」）。
  final String? attemptType;

  /// 备注说明（BZSM，如「免修合格」）。
  final String? remark;

  factory GraduateGradeRow.fromJson(Map<String, dynamic> json) {
    return GraduateGradeRow(
      courseCode: json['KCDM']?.toString() ?? '',
      courseName: json['KCMC']?.toString() ?? '',
      courseNameEn: json['KCMCYW']?.toString(),
      termCode: json['XNXQDM']?.toString() ?? '',
      termName: json['XNXQDM_DISPLAY']?.toString(),
      category: json['KCLBMC']?.toString(),
      gradeText: json['CJ']?.toString(),
      gradeDisplay: json['CJXSZ']?.toString(),
      gradingSystem: json['CJFZDM_DISPLAY']?.toString(),
      percentile: _asDouble(json['DYBFZCJ']),
      credit: _asDouble(json['XF']) ?? 0.0,
      gradePoint: _asDouble(json['JDZ']),
      passed: _asFlag(json['SFJG']),
      valid: _asFlag(json['SFYX']),
      attemptType: json['KSXZDM_DISPLAY']?.toString(),
      remark: json['BZSM']?.toString(),
    );
  }

  /// 整数不带小数、小数保留 1 位，null 为 null。
  String? get percentileLabel {
    final value = percentile;
    if (value == null) return null;
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  /// 卡片副显示（成绩大字下方的小字）：优先百分成绩，仅当它与成绩显示值
  /// 不同（如「免修通过」对应 80）才有信息量；其次分制标签，但显示值已
  /// 含其语义核心（如「免修通过」vs「免修通过制」）或纯数字成绩配「百分制」
  /// 时视为冗余不显示。
  String? get gradeSubLabel {
    final display = gradeDisplay ?? gradeText;
    final percentText = percentileLabel;
    if (percentText != null &&
        (display == null ||
            (display != percentText && !display.contains(percentText)))) {
      return percentText;
    }
    final system = gradingSystem;
    if (system == null || system.isEmpty) return null;
    if (system.contains('百分')) return null;
    final core = system.endsWith('制')
        ? system.substring(0, system.length - 1)
        : system;
    if (display == null) return system;
    return display.contains(core) || core.contains(display) ? null : system;
  }

  /// 备注是否与成绩显示值语义重复（如「免修合格」vs「免修通过」——
  /// 去掉「合格/通过」后同为「免修」），冗余时卡片不再重复展示。
  bool get remarkIsRedundant {
    final remark = this.remark;
    if (remark == null || remark.trim().isEmpty) return false;
    final display = gradeDisplay ?? gradeText;
    if (display == null) return false;
    String core(String s) => s.replaceAll('合格', '').replaceAll('通过', '').trim();
    return core(remark) == core(display);
  }
}

/// 成绩统计四指标（页面文案：课程数 / 总学分 / 加权均分 / 通过率）。
///
/// 口径：
/// - 课程数 / 总学分：按全部有效行（[GraduateGradeRow.valid]）计数、求和；
/// - 加权均分：只对有 [GraduateGradeRow.percentile] 的行按学分加权平均；
/// - 通过率：`passed` 门数占比（百分数 0-100）。
///
/// TODO(gs-api) 口径待校准：免修课（DYBFZCJ 有值）目前**计入**加权均分，
/// 成绩一多均分会虚高；等真实多类型成绩数据到位后校准是否剔除/降权，
/// 别让人拿这个数字去算奖学金。
class GraduateGradesStats {
  const GraduateGradesStats({
    required this.courseCount,
    required this.totalCredit,
    required this.passedCount,
    this.weightedAverage,
  });

  /// 课程数（有效行数）。
  final int courseCount;

  /// 总学分。
  final double totalCredit;

  /// 及格课程门数（SFJG == 1 的有效行数）。
  final int passedCount;

  /// 加权均分；没有任何行给出百分成绩时为 null（页面显示占位）。
  final double? weightedAverage;

  /// 通过率（百分数 0-100）；courseCount 为 0 时为 null。
  double? get passRate =>
      courseCount == 0 ? null : passedCount * 100.0 / courseCount;
}

/// 宽松数值解析：num 直转；字符串 tryParse；其余 null。
double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// 0/1 标志归一化：布尔透传；数字/数字字符串**严格等于 1** 才算 true——
/// 实测信封只给 0/1，将来若冒出 `2`（不适用/未评之类的编码）不能被
/// 「非零即真」静默算进通过率；'true' 字符串同样认账。
bool _asFlag(Object? value) => switch (value) {
  null => false,
  bool b => b,
  num n => n == 1,
  String s => s.trim() == 'true' || (double.tryParse(s.trim()) ?? -1) == 1,
  _ => false,
};
