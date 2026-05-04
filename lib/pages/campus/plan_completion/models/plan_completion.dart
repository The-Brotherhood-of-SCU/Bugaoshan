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

  bool get isCategory => flagType == '001';
  bool get isSubCategory => flagType == '002';
  bool get isCourse => flagType == 'kch';

  factory PlanCompletionNode.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? '';
    final plainName = rawName
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final flagType = json['flagType'] as String? ?? '';

    String courseCode = '';
    String courseName = '';
    String courseCredits = '';
    String academicTerm = '';
    String gradeInfo = '';

    if (flagType == 'kch') {
      // Parse: [304112010]新生研讨课[1学分,2023-2024学年秋](必修,96.0(20240107))
      // Or:    [107120000]形势与政策-6[0学分,2025-2026学年春]
      final courseMatch = RegExp(
        r'\[([^\]]+)\](.*?)\[([^\]]+)\](.*)',
      ).firstMatch(plainName);
      if (courseMatch != null) {
        courseCode = courseMatch.group(1)!;
        courseName = courseMatch.group(2)!;
        final creditsTerm = courseMatch.group(3)!;
        gradeInfo = courseMatch.group(4)!.trim();

        final creditsMatch = RegExp(r'([\d.]+)学分').firstMatch(creditsTerm);
        if (creditsMatch != null) {
          courseCredits = creditsMatch.group(1)!;
        }

        final termMatch = RegExp(r'学分,(.+)').firstMatch(creditsTerm);
        if (termMatch != null) {
          academicTerm = termMatch.group(1)!;
        }
      }
    }

    return PlanCompletionNode(
      id: json['id'] as String? ?? '',
      pId: json['pId'] as String? ?? '',
      flagId: json['flagId'] as String? ?? '',
      flagType: flagType,
      name: plainName,
      rawName: rawName,
      completed: json['sfwc'] == '是',
      earnedCredits: json['yxxf'] as String? ?? '',
      requiredCredits: json['zsxf'] as String? ?? '',
      courseCode: courseCode,
      courseName: courseName,
      courseCredits: courseCredits,
      academicTerm: academicTerm,
      gradeInfo: gradeInfo,
    );
  }
}
