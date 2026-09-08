/// 日历导出/导入相关工具的汇总出口（barrel）。
///
/// 为避免破坏既有 import/export，此文件保留原 `calendar_event_utils.dart`
/// 的公共符号面；实际实现按职责拆分到：
/// - `calendar_event_models.dart` — 数据模型
/// - `calendar_location_mapper.dart` — 地点解析 + 静态地理数据
/// - `calendar_event_identity.dart` — 稳定 UID 生成
library;

export 'calendar_event_models.dart'
    show
        CalendarStructuredLocation,
        CalendarResolvedLocation,
        CalendarExportPayload,
        CalendarEventPayload;
export 'calendar_location_mapper.dart' show CalendarLocationMapper;
export 'calendar_event_identity.dart' show CalendarEventIdentity;
