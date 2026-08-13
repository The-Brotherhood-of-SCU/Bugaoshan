import 'package:bugaoshan/utils/constants.dart';
import 'package:flutter/material.dart';

/// 校园页功能入口的强调色。
///
/// 每个入口按 dock id 绑定一个固定的强调色，让页面告别清一色的
/// primaryContainer，视觉上更有层次、更易辨识。颜色取自一组兼顾
/// 明暗主题的调和色板。
Color campusItemAccent(String id) => switch (id) {
  dockIdGrades => const Color(0xFF5B8DEF), // 蓝
  dockIdCcyl => const Color(0xFF8B7CF6), // 紫
  dockIdPlanCompletion => const Color(0xFF3FA796), // 青绿
  dockIdFitnessTest => const Color(0xFFF27059), // 橙红
  dockIdExamPlan => const Color(0xFFE86A92), // 品红
  dockIdTrainProgram => const Color(0xFF7C9A4E), // 橄榄绿
  dockIdClassScheduleInquiry => const Color(0xFF4FA3C4), // 天青
  dockIdClassroom => const Color(0xFF6C8CD5), // 靛蓝
  dockIdNetworkDevice => const Color(0xFF5AB8A8), // 湖绿
  dockIdBalanceQuery => const Color(0xFFE8A33D), // 琥珀
  dockIdAcademicCalendar => const Color(0xFFD97757), // 赭橙
  dockIdZysc => const Color(0xFF9A7FD1), // 淡紫
  dockIdLeave => const Color(0xFF6488C4), // 灰蓝
  dockIdNotice => const Color(0xFFE05D5D), // 朱红
  dockIdDownloadedAttachments => const Color(0xFF8F9BA8), // 蓝灰
  _ => const Color(0xFF5B8DEF),
};

/// 强调色对应的图标容器底色：按主题明暗调整透明度，
/// 保证在 surfaceContainerLow 卡片上柔和不刺眼。
Color campusItemAccentContainer(Color accent, Brightness brightness) {
  return accent.withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.14);
}
