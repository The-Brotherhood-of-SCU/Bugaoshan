/// 日历导出相关的数据模型（与 iCalendar 事件结构一一对应）。
///
/// 从 `calendar_event_utils.dart` 拆分而来，便于按职责独立维护与测试。
library;

/// 结构化地理位置（写入 iCalendar GEO / X-APPLE-STRUCTURED-LOCATION）。
class CalendarStructuredLocation {
  final String title;
  final double? latitude;
  final double? longitude;
  final double? radius;

  const CalendarStructuredLocation({
    required this.title,
    this.latitude,
    this.longitude,
    this.radius,
  });

  Map<String, Object> toPlatformJson() {
    return {
      'title': title,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'radius': ?radius,
    };
  }
}

/// 位置解析结果：展示标题 + 可选的结构化坐标。
class CalendarResolvedLocation {
  final String title;
  final CalendarStructuredLocation? structuredLocation;

  const CalendarResolvedLocation({
    required this.title,
    this.structuredLocation,
  });
}

/// 导出动作的通用载荷：文件名 + .ics 内容 + 平台事件列表。
class CalendarExportPayload {
  final String fileName;
  final String icsContent;
  final List<Map<String, Object>> events;

  const CalendarExportPayload({
    required this.fileName,
    required this.icsContent,
    required this.events,
  });
}

/// 单条日历事件载荷（供 .ics 生成与系统日历导入共用）。
class CalendarEventPayload {
  final DateTime start;
  final DateTime end;
  final String title;
  final String location;
  final String description;
  final String uid;
  final String timeZone;
  final CalendarStructuredLocation? structuredLocation;

  const CalendarEventPayload({
    required this.start,
    required this.end,
    required this.title,
    required this.location,
    required this.description,
    required this.uid,
    this.timeZone = 'Asia/Shanghai',
    this.structuredLocation,
  });

  Map<String, Object> toPlatformJson() {
    final payload = <String, Object>{
      'title': title,
      'location': location,
      'notes': description,
      'uid': uid,
      'timeZone': timeZone,
      'start': _dateComponents(start),
      'end': _dateComponents(end),
    };
    final structuredLocation = this.structuredLocation;
    if (structuredLocation != null) {
      payload['structuredLocation'] = structuredLocation.toPlatformJson();
    }
    return payload;
  }

  static Map<String, int> _dateComponents(DateTime dateTime) {
    return {
      'year': dateTime.year,
      'month': dateTime.month,
      'day': dateTime.day,
      'hour': dateTime.hour,
      'minute': dateTime.minute,
    };
  }
}
