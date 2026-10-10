import 'dart:convert';

import 'package:bugaoshan/utils/json_utils.dart';
import 'package:flutter/material.dart';

/// 提醒业务类型。新增类型时须在 [ReminderKind.fromWire] 注册映射，原生宿主仅负责透传。
enum ReminderKind {
  /// 课前提醒：基于课程周次、星期与节次换算的时间展开生成。
  courseStart('course_start');

  const ReminderKind(this.wire);

  /// 跨 MethodChannel 传输的持久化标识。原生宿主根据此字段进行通知渠道路由。
  final String wire;

  static ReminderKind? fromWire(String? value) {
    for (final kind in ReminderKind.values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// 单条提醒实体，包含原生端完成本地投递所需的全部上下文数据。原生层不执行业务推断。
@immutable
class ReminderItem {
  /// 确定性唯一标识。由课程标识、日期、节次与提前量组合生成。
  ///
  /// 原生层采用全量替换策略同步排期，旧计划中存在但新计划中缺失的 ID 会被直接撤销。
  /// ID 的幂等性保证课表变更或重复排期时不会产生残留通知。
  final String id;

  final ReminderKind kind;

  /// 触发时间（设备本地墙上时钟语义）。由 Dart 层预先计算，原生端不参与时区换算。
  final DateTime fireAt;

  final String title;
  final String body;

  /// 通知聚合折叠标识。用于将同日同课程的不同提前量通知聚拢展示。
  final String collapseKey;

  const ReminderItem({
    required this.id,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.collapseKey,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.wire,
    'fireAt': _iso8601Local(fireAt),
    // epoch 毫秒用于原生平台实际排期触发；ISO 8601 字符串仅供日志追踪与调试排查。
    'fireAtMillis': fireAt.millisecondsSinceEpoch,
    'title': title,
    'body': body,
    'collapseKey': collapseKey,
  };

  /// 从序列化数据反序列化单条提醒。非法数据（缺失 ID、触发时刻无法解析或类型未定义）返回 null，
  /// 允许调用方单条忽略，避免导致批量解析整体中断。
  static ReminderItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, Object?>();
    final id = safeString(json['id']);
    final kind = ReminderKind.fromWire(safeString(json['kind']));
    final fireAt = _parseFireAt(json);
    if (id.isEmpty || kind == null || fireAt == null) return null;
    return ReminderItem(
      id: id,
      kind: kind,
      fireAt: fireAt,
      title: safeString(json['title']),
      body: safeString(json['body']),
      collapseKey: safeString(json['collapseKey']),
    );
  }
}

/// 提醒排期计划数据集。原生端接收后执行全量覆盖替换。
@immutable
class ReminderPlan {
  /// 协议版本号。原生端据此校验兼容性；遇到未知版本将拒绝执行。
  static const int schema = 1;

  /// 计划内容特征哈希（排除 [generatedAt]）。哈希一致时直接短路跳过原生层重复重排。
  final String planId;

  final DateTime generatedAt;

  /// 当前计划覆盖的有效时间窗口。原生端超出此窗口范围后将等待新计划下发。
  final DateTime windowStart;
  final DateTime windowEnd;

  /// 原生平台对应的通知渠道（Notification Channel / Category）标识符。
  final String channel;

  final List<ReminderItem> reminders;

  /// 因系统待投递通知上限而截断的提醒数量。非零时在设置界面与日志中显式暴露，
  /// 用于排查通知因容量限制丢失的问题。
  final int droppedCount;

  const ReminderPlan({
    required this.planId,
    required this.generatedAt,
    required this.windowStart,
    required this.windowEnd,
    required this.channel,
    required this.reminders,
    this.droppedCount = 0,
  });

  bool get isEmpty => reminders.isEmpty;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'planId': planId,
    'generatedAt': _iso8601Local(generatedAt),
    'window': {
      'start': _iso8601Local(windowStart),
      'end': _iso8601Local(windowEnd),
    },
    'channel': channel,
    'reminders': reminders.map((e) => e.toJson()).toList(),
    'droppedCount': droppedCount,
  };

  /// 生成通过 MethodChannel 传输的原生载荷。
  ///
  /// 相比 [toJson]，此处移除 ISO 8601 字符串并仅保留 epoch 毫秒时间戳，
  /// 规避跨平台序列化与反序列化时的时区歧义。调试界面展示可读时间时使用 [toJson]。
  Map<String, Object?> toChannelPayload() => {
    'schema': schema,
    'planId': planId,
    'generatedAtMillis': generatedAt.millisecondsSinceEpoch,
    'windowStartMillis': windowStart.millisecondsSinceEpoch,
    'windowEndMillis': windowEnd.millisecondsSinceEpoch,
    'channel': channel,
    'droppedCount': droppedCount,
    'reminders': reminders
        .map(
          (e) => {
            'id': e.id,
            'kind': e.kind.wire,
            'fireAtMillis': e.fireAt.millisecondsSinceEpoch,
            'title': e.title,
            'body': e.body,
            'collapseKey': e.collapseKey,
          },
        )
        .toList(),
  };

  static ReminderPlan? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, Object?>();
    if (safeInt(json['schema'], fallback: -1) != schema) return null;
    final window = json['window'];
    final windowMap = window is Map ? window.cast<String, Object?>() : const {};
    final reminders = <ReminderItem>[];
    final rawList = json['reminders'];
    if (rawList is List) {
      for (final entry in rawList) {
        final item = ReminderItem.fromJson(entry);
        if (item != null) reminders.add(item);
      }
    }
    return ReminderPlan(
      planId: safeString(json['planId']),
      generatedAt:
          _parseDate(json['generatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      windowStart:
          _parseDate(windowMap['start']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      windowEnd:
          _parseDate(windowMap['end']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      channel: safeString(json['channel']),
      reminders: reminders,
      droppedCount: safeInt(json['droppedCount']),
    );
  }
}

/// 提醒配置参数。由调用方从 AppConfigProvider 获取并传入，保证计划构建器维持纯函数设计。
@immutable
class ReminderSettings {
  /// 课前提醒主开关。
  final bool courseReminderEnabled;

  /// 提前提醒时间列表（单位：分钟）。生效时将去重并按升序排列。
  final List<int> leadMinutes;

  /// 免打扰时间段（闭区间）。为 null 表示未启用。
  ///
  /// 触发时间落入该区间的提醒将被直接丢弃而非延迟投递，避免在静音时段外产生失效的过期提醒。
  final TimeOfDay? quietStart;
  final TimeOfDay? quietEnd;

  /// 排期计算向前覆盖的时间窗口天数。增加天数可延长单次排期的覆盖时长，但会提高触及平台待投递上限的概率。
  final int windowDays;

  /// 提醒文案是否包含教室地点与授课教师。与全局隐私设置关联，用于锁屏等外部界面的敏感信息控制。
  final bool includeLocation;
  final bool includeTeacher;

  const ReminderSettings({
    this.courseReminderEnabled = false,
    this.leadMinutes = const [15],
    this.quietStart,
    this.quietEnd,
    this.windowDays = defaultWindowDays,
    this.includeLocation = true,
    this.includeTeacher = true,
  });

  /// 默认排期覆盖天数。
  ///
  /// iOS 系统单个应用待投递本地通知上限为 64 条。按常规日课程量（4~6 节）与单提醒量估算，
  /// 7 天周期约占用 28~42 条配额；配置多个提前量时将成倍增加配额消耗并接近系统上限。
  static const int defaultWindowDays = 7;

  /// iOS 系统待投递通知上限配额，ReminderPlanBuilder 据此执行截断。
  static const int iosPendingNotificationLimit = 64;

  /// 归一化后的提前时间列表：过滤非正数、去重并升序排列。
  List<int> get normalizedLeadMinutes {
    final set = <int>{};
    for (final lead in leadMinutes) {
      if (lead > 0) set.add(lead);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 判定指定时间 [time] 是否处于免打扰区间内，支持跨午夜时段判定（例如 22:00 至次日 07:00）。
  bool isQuiet(TimeOfDay time) {
    final start = quietStart;
    final end = quietEnd;
    if (start == null || end == null) return false;
    final t = time.hour * 60 + time.minute;
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;
    if (s == e) return false;
    if (s < e) return t >= s && t <= e;
    return t >= s || t <= e;
  }
}

/// 格式化为携带时区偏移的 ISO 8601 时间字符串（`yyyy-MM-ddTHH:mm:ss±HH:MM`）。
///
/// 不使用 [DateTime.toIso8601String] 是由于其对本地时间省略时区偏移，
/// 原生端解析时可能因时区推断不一致产生偏差。此处显式序列化时区偏移量。
String _iso8601Local(DateTime time) {
  final local = time.isUtc ? time.toLocal() : time;
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final oh = abs.inHours.toString().padLeft(2, '0');
  final om = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}T'
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}'
      '$sign$oh:$om';
}

DateTime? _parseDate(Object? value) {
  final text = safeString(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// 从通道载荷解析触发时间戳：优先读取 epoch 毫秒，缺失时回退解析 ISO 8601 字符串。
DateTime? _parseFireAt(Map<String, Object?> json) {
  final millis = json['fireAtMillis'];
  if (millis is num) {
    return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  }
  return _parseDate(json['fireAt']);
}

/// 计算计划内容的确定性哈希（32 位 FNV-1a）。
///
/// 不使用 [Object.hashCode] 是因为其不具备跨进程与跨运行时的持久一致性。
/// 原生端依赖此哈希对比计划是否变更以执行短路逻辑，需保证一致的哈希输出。
String planContentHash(List<ReminderItem> reminders) {
  const int offsetBasis = 0x811c9dc5;
  const int prime = 0x01000193;
  var hash = offsetBasis;
  void mix(String text) {
    for (final unit in utf8.encode(text)) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    // 字段间插入定界符，避免相邻字段边界重叠产生哈希碰撞（如 id='ab'+title='c' 与 id='a'+title='bc'）。
    hash ^= 0x1f;
    hash = (hash * prime) & 0xFFFFFFFF;
  }

  for (final item in reminders) {
    mix(item.id);
    mix(item.kind.wire);
    mix(item.fireAt.millisecondsSinceEpoch.toString());
    mix(item.title);
    mix(item.body);
    mix(item.collapseKey);
    // 条目间插入终止符，避免条目边界混淆（如空字段引起的边界歧义）。
    mix('\u0000');
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
