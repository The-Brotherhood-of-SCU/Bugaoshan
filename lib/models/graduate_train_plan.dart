/// 研究生培养进度模型（数据链 2026-09-21 抓包定案：wdpyjhapp 的
/// wdxx/wdkclbtj/wdfakcxx 三个 GET 零信封，字段名全大写系）。
///
/// 注意：wdkclbtj 还给「当前选课学分」（YXXF/FAWYXXF/FANYXXF 等），那是
/// **选课侧**口径（含在修未出成绩的课），与「已修（通过）」口径不同，
/// 这里只解析培养要求侧字段，不要混用。
library;

import 'package:bugaoshan/utils/json_utils.dart';

/// 方案基本信息（`wdxx.do` → `reMapData.XSXX`）。
class GraduateTrainPlanInfo {
  const GraduateTrainPlanInfo({
    required this.xh,
    required this.famc,
    required this.fadm,
    this.zydmDisplay = '',
    this.yxdmDisplay = '',
    this.njdmDisplay = '',
    this.pyccdmDisplay = '',
    this.shztDisplay = '',
  });

  /// 学号（XH）。
  final String xh;

  /// 培养方案名称（FAMC，如「2026级学术学位0817 化学工程与技术2026级研究生培养方案」）。
  final String famc;

  /// 方案代码（FADM）。
  final String fadm;

  /// 专业（ZYDM_DISPLAY）。
  final String zydmDisplay;

  /// 学院（YXDM_DISPLAY）。
  final String yxdmDisplay;

  /// 年级（NJDM_DISPLAY）。
  final String njdmDisplay;

  /// 培养层次（PYCCDM_DISPLAY：硕士/博士）。
  final String pyccdmDisplay;

  /// 培养计划审核状态（SHZT_DISPLAY，如「待院系审核」）。
  final String shztDisplay;

  factory GraduateTrainPlanInfo.fromJson(Map<String, dynamic> json) =>
      GraduateTrainPlanInfo(
        xh: safeString(json['XH']),
        famc: safeString(json['FAMC']),
        fadm: safeString(json['FADM']),
        zydmDisplay: safeString(json['ZYDM_DISPLAY']),
        yxdmDisplay: safeString(json['YXDM_DISPLAY']),
        njdmDisplay: safeString(json['NJDM_DISPLAY']),
        pyccdmDisplay: safeString(json['PYCCDM_DISPLAY']),
        shztDisplay: safeString(json['SHZT_DISPLAY']),
      );
}

/// 分类要求（`wdkclbtj.do` → `reListData[]`，一行一个课程类别）。
///
/// 只解析要求侧：该类**要求学分**（ZDXF）；响应里的 YXXF/YXMS 是选课侧
/// 口径，故意不解析（见文件头注释）。
class GraduateTrainPlanCategoryProgress {
  const GraduateTrainPlanCategoryProgress({
    required this.dm,
    required this.mc,
    required this.requiredCredits,
  });

  /// 类别代码（DM）。
  final String dm;

  /// 类别名（MC，如「必修课」「选修课」「必修环节」）。
  final String mc;

  /// 该类要求学分（ZDXF）。
  final double requiredCredits;

  factory GraduateTrainPlanCategoryProgress.fromJson(
    Map<String, dynamic> json,
  ) => GraduateTrainPlanCategoryProgress(
    dm: safeString(json['DM']),
    mc: safeString(json['MC'] ?? json['KCLBDM_DISPLAY']),
    requiredCredits: safeDouble(json['ZDXF']),
  );
}

/// 学分要求总计（`wdkclbtj.do` → `reMapData`）。
///
/// 只取 ZDXF（方案内要求总学分）；响应里的 YXXF/FANYXXF/FAWYXXF 是选课
/// 侧口径，故意不解析（见文件头注释）。
class GraduateTrainPlanCreditStats {
  const GraduateTrainPlanCreditStats({required this.requiredCredits});

  /// 学分要求（ZDXF，方案内要求总学分）。
  final double requiredCredits;

  factory GraduateTrainPlanCreditStats.fromJson(Map<String, dynamic> json) =>
      GraduateTrainPlanCreditStats(requiredCredits: safeDouble(json['ZDXF']));
}

/// 方案课程明细（`wdfakcxx.do` → `fakcxx[]`）。
///
/// 主要用途：提供 KCDM → 课程类别（KCLBDM）的归属关系，把成绩行归并到
/// 方案类别上。
class GraduateTrainPlanCourse {
  const GraduateTrainPlanCourse({
    required this.kcdm,
    required this.kcmc,
    required this.kclbdm,
    this.kclbdmDisplay = '',
    required this.credits,
    this.outOfPlan = false,
    this.remark = '',
    this.stage = '',
  });

  /// 课程代码（KCDM）。
  final String kcdm;

  /// 课程名称（KCMC）。
  final String kcmc;

  /// 课程类别代码（KCLBDM，与分类要求的 DM 对应）。
  final String kclbdm;

  /// 课程类别名（KCLBDM_DISPLAY）。
  final String kclbdmDisplay;

  /// 学分（XF）。
  final double credits;

  /// 是否方案外课程（SFKZY_DISPLAY == 「方案外」）。
  final bool outOfPlan;

  /// 备注（BZ，如「必选」「化学工艺研究生必选」）。
  final String remark;

  /// 适用培养阶段（KCSYCC_DISPLAY：硕士阶段/博士阶段）。
  final String stage;

  factory GraduateTrainPlanCourse.fromJson(Map<String, dynamic> json) =>
      GraduateTrainPlanCourse(
        kcdm: safeString(json['KCDM']),
        kcmc: safeString(json['KCMC']),
        kclbdm: safeString(json['KCLBDM']),
        kclbdmDisplay: safeString(json['KCLBDM_DISPLAY']),
        credits: safeDouble(json['XF']),
        outOfPlan: safeString(json['SFKZY_DISPLAY']) == '方案外',
        remark: safeString(json['BZ']),
        stage: safeString(json['KCSYCC_DISPLAY']),
      );
}
