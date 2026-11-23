import 'package:bugaoshan/utils/json_utils.dart';

/// 一份培养方案的修读数据。
///
/// 教务系统对有多份培养方案(如主修+辅修、多学位)的用户,`/planCompletion/index`
/// 返回的是方案选择页(不含 zNodes 数据),真正的树数据在
/// `/getPyfaIndex/<方案ID>` 详情页;单方案用户则直接由 index 页返回数据。
/// [id] 为空串表示数据直接来自 index 页(单方案场景)。
class PlanCompletionPlan {
  final String id;
  final String name;
  final List<PlanCompletionNode> nodes;

  const PlanCompletionPlan({
    required this.id,
    required this.name,
    required this.nodes,
  });
}

class PlanCompletionNode {
  final String id;
  final String pId;
  final String flagId;
  final String
  flagType; // "001" = category, "002" = subcategory, "kch" = course
  final String name; // plain text name (HTML stripped)
  final String rawName; // original HTML name
  final bool completed; // sfwc == "是"
  final String earnedCredits; // yxxf
  final String requiredCredits; // zsxf
  // Course-specific fields (only for flagType == "kch")
  final String courseCode;
  final String courseName;
  final String courseCredits;
  final String academicTerm;
  final String gradeInfo;

  const PlanCompletionNode({
    required this.id,
    required this.pId,
    required this.flagId,
    required this.flagType,
    required this.name,
    required this.rawName,
    required this.completed,
    required this.earnedCredits,
    required this.requiredCredits,
    required this.courseCode,
    required this.courseName,
    required this.courseCredits,
    required this.academicTerm,
    required this.gradeInfo,
  });

  static final _htmlTagRegExp = RegExp(r'<[^>]+>');
  static final _whitespaceRegExp = RegExp(r'\s+');
  static final _coursePattern = RegExp(r'\[([^\]]+)\](.*?)\[([^\]]+)\](.*)');
  static final _creditsTermPattern = RegExp(r'([\d.]+)学分(?:[,，\s/]+(.+))?');
  static final _gradeScoreRegExp = RegExp(r',\s*([^(),\s]+)');
  static final _bracketPattern = RegExp(r'[(（]');

  bool get isCategory => flagType == '001';
  bool get isSubCategory => flagType == '002';
  bool get isCourse => flagType == 'kch';

  /// 从 gradeInfo 提取展示成绩（如 '(必修,96.0(20240107))' -> '96.0'，'(必修,86.0)' -> '86.0'）。
  String get scoreDisplay =>
      _gradeScoreRegExp.firstMatch(gradeInfo)?.group(1) ?? '';

  double get earnedCreditsValue => double.tryParse(earnedCredits) ?? 0.0;
  double get requiredCreditsValue => double.tryParse(requiredCredits) ?? 0.0;
  double get progress => requiredCreditsValue > 0
      ? (earnedCreditsValue / requiredCreditsValue).clamp(0.0, 1.0)
      : 0.0;

  /// 分类展示名称（剥除括号说明信息：如 '公共基础课(最低修读学分:25)' -> '公共基础课'）
  String get categoryDisplayName {
    final cut = name.indexOf(_bracketPattern);
    return cut > 0 ? name.substring(0, cut).trim() : name;
  }

  factory PlanCompletionNode.fromJson(Map<String, dynamic> json) {
    final rawName = safeString(json['name']);
    final plainName = rawName
        .replaceAll(_htmlTagRegExp, '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(_whitespaceRegExp, ' ')
        .trim();
    final flagType = safeString(json['flagType']);

    String courseCode = '';
    String courseName = '';
    String courseCredits = '';
    String academicTerm = '';
    String gradeInfo = '';

    if (flagType == 'kch') {
      // Parse: [304112010]新生研讨课[1学分,2023-2024学年秋](必修,96.0(20240107))
      // Or:    [107120000]形势与政策-6[0学分,2025-2026学年春]
      final courseMatch = _coursePattern.firstMatch(plainName);
      if (courseMatch != null) {
        courseCode = courseMatch[1]!.trim();
        courseName = courseMatch[2]!.trim();
        final creditsTerm = courseMatch[3]!.trim();
        gradeInfo = courseMatch[4]!.trim();

        final ctMatch = _creditsTermPattern.firstMatch(creditsTerm);
        if (ctMatch != null) {
          courseCredits = ctMatch[1]!;
          academicTerm = ctMatch[2]?.trim() ?? '';
        }
      }
    }

    return PlanCompletionNode(
      id: safeString(json['id']),
      pId: safeString(json['pId']),
      flagId: safeString(json['flagId']),
      flagType: flagType,
      name: plainName,
      rawName: rawName,
      completed: safeString(json['sfwc']) == '是',
      earnedCredits: safeString(json['yxxf']),
      requiredCredits: safeString(json['zsxf']),
      courseCode: courseCode,
      courseName: courseName,
      courseCredits: courseCredits,
      academicTerm: academicTerm,
      gradeInfo: gradeInfo,
    );
  }
}
