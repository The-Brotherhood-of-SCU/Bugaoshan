/// 研究生培养进度模型（数据链 2026-09-21 抓包定案：wdpyjhapp 的
/// wdxx/wdkclbtj/wdfakcxx 三个 GET 零信封，字段名全大写系）。
library;

/// 方案基本信息（`wdxx.do` → `reMapData.XSXX`）。
class GraduateTrainPlanInfo {
  const GraduateTrainPlanInfo({
    required this.xh,
    required this.famc,
    required this.fadm,
    this.zydmDisplay,
    this.yxdmDisplay,
    this.njdmDisplay,
    this.pyccdmDisplay,
    this.shztDisplay,
  });

  /// 学号（XH）。
  final String xh;

  /// 培养方案名称（FAMC，如「2026级学术学位0817 化学工程与技术2026级研究生培养方案」）。
  final String famc;

  /// 方案代码（FADM）。
  final String fadm;

  /// 专业（ZYDM_DISPLAY）。
  final String? zydmDisplay;

  /// 学院（YXDM_DISPLAY）。
  final String? yxdmDisplay;

  /// 年级（NJDM_DISPLAY）。
  final String? njdmDisplay;

  /// 培养层次（PYCCDM_DISPLAY：硕士/博士）。
  final String? pyccdmDisplay;

  /// 培养计划审核状态（SHZT_DISPLAY，如「待院系审核」）。
  final String? shztDisplay;

  factory GraduateTrainPlanInfo.fromJson(Map<String, dynamic> json) =>
      GraduateTrainPlanInfo(
        xh: asString(json['XH']),
        famc: asString(json['FAMC']),
        fadm: asString(json['FADM']),
        zydmDisplay: asStringOrNull(json['ZYDM_DISPLAY']),
        yxdmDisplay: asStringOrNull(json['YXDM_DISPLAY']),
        njdmDisplay: asStringOrNull(json['NJDM_DISPLAY']),
        pyccdmDisplay: asStringOrNull(json['PYCCDM_DISPLAY']),
        shztDisplay: asStringOrNull(json['SHZT_DISPLAY']),
      );
}

/// 分类学分进度（`wdkclbtj.do` → `reListData[]`，一行一个课程类别）。
class GraduateTrainPlanCategoryProgress {
  const GraduateTrainPlanCategoryProgress({
    required this.dm,
    required this.mc,
    required this.selectedCredits,
    required this.requiredCredits,
    this.selectedCount,
  });

  /// 类别代码（DM）。
  final String dm;

  /// 类别名（MC，如「必修课」「选修课」「必修环节」）。
  final String mc;

  /// 当前已选学分（YXXF）。
  final double selectedCredits;

  /// 该类要求学分（ZDXF）。
  final double requiredCredits;

  /// 已选门数（YXMS）。
  final int? selectedCount;

  factory GraduateTrainPlanCategoryProgress.fromJson(
    Map<String, dynamic> json,
  ) => GraduateTrainPlanCategoryProgress(
    dm: asString(json['DM']),
    mc: asString(json['MC'] ?? json['KCLBDM_DISPLAY']),
    selectedCredits: asDouble(json['YXXF']) ?? 0.0,
    requiredCredits: asDouble(json['ZDXF']) ?? 0.0,
    selectedCount: asIntOrNull(json['YXMS']),
  );
}

/// 学分总计（`wdkclbtj.do` → `reMapData`）。
class GraduateTrainPlanCreditStats {
  const GraduateTrainPlanCreditStats({
    required this.selectedCredits,
    required this.requiredCredits,
    required this.inPlanCredits,
    required this.outPlanCredits,
  });

  /// 总计已选学分（YXXF）。
  final double selectedCredits;

  /// 学分要求（ZDXF）。
  final double requiredCredits;

  /// 方案内选课学分（FANYXXF）。
  final double inPlanCredits;

  /// 方案外选课学分（FAWYXXF）。
  final double outPlanCredits;

  factory GraduateTrainPlanCreditStats.fromJson(Map<String, dynamic> json) =>
      GraduateTrainPlanCreditStats(
        selectedCredits: asDouble(json['YXXF']) ?? 0.0,
        requiredCredits: asDouble(json['ZDXF']) ?? 0.0,
        inPlanCredits: asDouble(json['FANYXXF']) ?? 0.0,
        outPlanCredits: asDouble(json['FAWYXXF']) ?? 0.0,
      );
}

/// 方案课程明细（`wdfakcxx.do` → `fakcxx[]`）。
class GraduateTrainPlanCourse {
  const GraduateTrainPlanCourse({
    required this.kcdm,
    required this.kcmc,
    required this.kclbdm,
    this.kclbdmDisplay,
    required this.credits,
    this.outOfPlan = false,
    this.remark,
    this.stage,
  });

  /// 课程代码（KCDM）。
  final String kcdm;

  /// 课程名称（KCMC）。
  final String kcmc;

  /// 课程类别代码（KCLBDM，与分类进度行的 DM 对应）。
  final String kclbdm;

  /// 课程类别名（KCLBDM_DISPLAY）。
  final String? kclbdmDisplay;

  /// 学分（XF）。
  final double credits;

  /// 是否方案外课程（SFKZY_DISPLAY == 「方案外」）。
  final bool outOfPlan;

  /// 备注（BZ，如「必选」「化学工艺研究生必选」）。
  final String? remark;

  /// 适用培养阶段（KCSYCC_DISPLAY：硕士阶段/博士阶段）。
  final String? stage;

  factory GraduateTrainPlanCourse.fromJson(Map<String, dynamic> json) =>
      GraduateTrainPlanCourse(
        kcdm: asString(json['KCDM']),
        kcmc: asString(json['KCMC']),
        kclbdm: asString(json['KCLBDM']),
        kclbdmDisplay: asStringOrNull(json['KCLBDM_DISPLAY']),
        credits: asDouble(json['XF']) ?? 0.0,
        outOfPlan: asString(json['SFKZY_DISPLAY']) == '方案外',
        remark: asStringOrNull(json['BZ']),
        stage: asStringOrNull(json['KCSYCC_DISPLAY']),
      );
}

/// 宽松字符串：非空串透传，null/非字符串回空串。
String asString(Object? value) {
  final s = value;
  if (s is String && s.isNotEmpty) return s;
  if (s is num) return '$s';
  return '';
}

/// 宽松可空字符串。
String? asStringOrNull(Object? value) {
  final s = value;
  if (s is String && s.isNotEmpty) return s;
  return null;
}

/// 宽松数值：num 直转；字符串 tryParse；其余 null。
double? asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// 宽松可空整数。
int? asIntOrNull(Object? value) {
  final d = asDouble(value);
  return d?.toInt();
}
