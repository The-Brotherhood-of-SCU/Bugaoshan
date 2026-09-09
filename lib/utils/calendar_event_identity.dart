import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 日历事件的稳定 UID 生成器。
///
/// 从 `calendar_event_utils.dart` 拆分而来。UID 的稳定性对日历去重至关重要：
/// - 课表：按 courseId + 周次生成，用户跨版本升级后仍可匹配已导入事件；
/// - 考试：按规范化的考试名生成，避免「已结束」标记等 UI 状态影响去重。
class CalendarEventIdentity {
  const CalendarEventIdentity._();

  static const _domain = 'bugaoshan';

  static String courseUid({required String courseId, required int week}) {
    // Keep the legacy course UID shape so existing imported course events can
    // still be matched by calendar apps and the iOS local UID map.
    return '${courseId}_$week@$_domain';
  }

  static String examUid({required String name}) {
    // Exam de-duplication follows the authoritative course name only; UI state
    // such as "past" and the display-only finished marker must not affect it.
    final key = ['exam', normalizeName(name)].join('|');
    final digest = sha1.convert(utf8.encode(key)).toString().substring(0, 24);
    return 'exam-$digest@$_domain';
  }

  static String normalizeName(String name) {
    return name
        .replaceAll(RegExp(r'\s*[（(]\s*已结束\s*[）)]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
