import 'package:bugaoshan/utils/json_utils.dart';

/// 预约系统（service.scu.edu.cn/reservation）数据模型。
///
/// 响应信封 `{e, m, d}`；`e == "OK"` 为成功。资源定义在
/// `topic/resource-list` 的 `d.data[].base` 与 `site/resource/detail` 的 `d`
/// 里是同一套字段（2026-10-23 抓包确认）。

/// 一次提交预约里的单个选中时段（日期 + 时段 id）。
class ReservationLaunchSlot {
  const ReservationLaunchSlot({required this.date, required this.periodId});

  /// `YYYY-MM-DD`。
  final String date;

  /// 时段 id（calendar `time[].id`，如 `5103`）。
  final String periodId;
}

/// 提交预约（`site/resource/launch`）的结果。
///
/// `needsProcess == true` 表示该资源走审批/流程（`is_relate`），预约单已创建，
/// 但还需到 `processUrl` 完成后续申请（如上传申请表），未完成前不算预约成功。
class ReservationLaunchResult {
  const ReservationLaunchResult({
    required this.needsProcess,
    required this.processUrl,
  });

  final bool needsProcess;
  final String processUrl;

  static ReservationLaunchResult fromJson(Object? json) {
    if (json is! Map) {
      return const ReservationLaunchResult(needsProcess: false, processUrl: '');
    }
    final map = Map<String, dynamic>.from(json);
    return ReservationLaunchResult(
      // 只看 is_relate：url 缺失不代表无需审批，展示层会降级到官方页。
      needsProcess: safeBool(map['is_relate']),
      processUrl: safeString(map['process_url']),
    );
  }
}

/// 我的预约单里单个时段明细（某日某时段，可被部分取消）。
class ReservationAppointmentDetail {
  const ReservationAppointmentDetail({
    required this.id,
    required this.date,
    required this.timeLabel,
  });

  final String id;

  /// 所属日期 `YYYY-MM-DD`（来自 `detail` 的键）。
  final String date;

  /// `str_time` 原文，如 `08:00-12:00`。
  final String timeLabel;

  String get label => '$date $timeLabel';
}

/// 我的预约单（`site/appointment/appointment-list` 的行）。
class ReservationAppointment {
  const ReservationAppointment({
    required this.id,
    required this.resourceName,
    required this.createdAt,
    required this.status,
    required this.canCancel,
    required this.details,
  });

  final String id;
  final String resourceName;

  /// `created` 原文（申请时间）。
  final String createdAt;

  /// 服务端状态码，与官方 tab 对应：0 待申请 / 1、2 审核中 / 3 已预约 /
  /// 4 待签到；其它视为已结束。
  final int status;

  /// `is_cancel == 1`：当前可取消。
  final bool canCancel;

  /// 时段明细（拍平自 `detail` 对象）。
  final List<ReservationAppointmentDetail> details;

  static ReservationAppointment? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = safeString(map['id']);
    if (id.isEmpty) return null;

    final details = <ReservationAppointmentDetail>[];
    final rawDetail = map['detail'];
    if (rawDetail is Map) {
      for (final entry in rawDetail.entries) {
        final date = entry.key.toString();
        final rows = entry.value;
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is! Map) continue;
          final detailId = safeString(row['id']);
          if (detailId.isEmpty) continue;
          details.add(
            ReservationAppointmentDetail(
              id: detailId,
              date: date,
              timeLabel: safeString(row['str_time']),
            ),
          );
        }
      }
    }

    return ReservationAppointment(
      id: id,
      resourceName: safeString(map['resource_name']),
      createdAt: safeString(map['created']),
      status: safeInt(map['status']),
      canCancel: safeInt(map['is_cancel']) == 1,
      details: details,
    );
  }
}

/// 解析 `topic/resource-list` 的 `d`（不是整个信封）。
///
/// 抓包结构：
/// ```json
/// {"data": [{"base": {...}, "time": [], "appointmen_list_info": []}],
///  "resources": [], "total": 17, "page": 1, "perpage": 100}
/// ```
/// `data` **直接就是数组**，每项的 `base` 才是资源定义。
List<ReservationResource> reservationResourcesFromJson(Object? json) {
  if (json is! Map) return const [];
  final rows = json['data'];
  if (rows is! List) return const [];

  return [
    for (final row in rows)
      if (row is Map) ?ReservationResource.fromJson(row['base']),
  ];
}

/// 资源的某个属性（容量 / 校区 / 分区 / 楼栋）。
///
/// `type == 0` 时 [value] 是纯文本（如「28」）；`type == 1` 时是
/// `[{id, value}]` 选项列表，取首项的 [value] 展示。
class ReservationAttribute {
  const ReservationAttribute({required this.name, required this.value});

  /// 属性名，如「容量/人数」「校区」。
  final String name;

  /// 展示值，如「28」「望江校区」。
  final String value;

  static ReservationAttribute? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    if (safeInt(map['enable'], fallback: 1) == 0) return null;

    final name = safeString(map['name']);
    if (name.isEmpty) return null;

    final data = map['data'];
    String value;
    if (data is List) {
      // 选项型：取已选项（attribute_config.value.id）对应的 label，
      // 缺失时退回第一项的 label。
      final selectedId = _selectedOptionId(map['attribute_config']);
      value = '';
      for (final item in data) {
        if (item is! Map) continue;
        final id = safeString(item['id']);
        final label = safeString(item['value']);
        if (selectedId != null && id == selectedId) {
          value = label;
          break;
        }
        if (value.isEmpty) value = label;
      }
    } else {
      value = safeString(data);
    }
    if (value.isEmpty) return null;
    return ReservationAttribute(name: name, value: value);
  }

  static String? _selectedOptionId(Object? attributeConfig) {
    if (attributeConfig is! Map) return null;
    final value = attributeConfig['value'];
    if (value is! Map) return null;
    final id = safeString(value['id']);
    return id.isEmpty ? null : id;
  }
}

/// 预约时段状态。
///
/// 取值与语义来自预约系统前端（`calendar` 的 `status` 字段）：
/// - 0 可预约
/// - 1 未开放
/// - 2 已过期
/// - 3 约满
/// - 4 已禁用
enum ReservationSlotStatus {
  available,
  notOpen,
  expired,
  full,
  disabled;

  static ReservationSlotStatus fromCode(int code) => switch (code) {
    0 => ReservationSlotStatus.available,
    1 => ReservationSlotStatus.notOpen,
    2 => ReservationSlotStatus.expired,
    3 => ReservationSlotStatus.full,
    _ => ReservationSlotStatus.disabled,
  };

  bool get bookable => this == ReservationSlotStatus.available;
}

/// 一个时段定义（如 08:00-12:00）。
class ReservationTimeSlot {
  const ReservationTimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
  });

  final String id;

  /// `HH:mm:ss` 原文，展示时取前 5 位。
  final String startTime;
  final String endTime;

  String get label {
    final start = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
    final end = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
    return '$start-$end';
  }

  static ReservationTimeSlot? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = safeString(map['id']);
    if (id.isEmpty) return null;
    final start = safeString(map['start_time']);
    final end = safeString(map['end_time']);
    if (start.isEmpty || end.isEmpty) return null;
    return ReservationTimeSlot(id: id, startTime: start, endTime: end);
  }
}

/// 某天某时段的占用情况。
class ReservationSlotState {
  const ReservationSlotState({
    required this.status,
    required this.total,
    required this.remaining,
  });

  final ReservationSlotStatus status;

  /// 总名额（抓包样本均为 1）。
  final int total;

  /// 剩余名额。
  final int remaining;

  bool get bookable => status.bookable && remaining > 0;

  static ReservationSlotState fromJson(Object? json) {
    if (json is! Map) {
      return const ReservationSlotState(
        status: ReservationSlotStatus.notOpen,
        total: 0,
        remaining: 0,
      );
    }
    final map = Map<String, dynamic>.from(json);
    return ReservationSlotState(
      status: ReservationSlotStatus.fromCode(safeInt(map['status'])),
      total: safeInt(map['total']),
      remaining: safeInt(map['num']),
    );
  }
}

/// 资源日历：时段定义 + 日期列表 + 每日每时段的占用。
class ReservationCalendar {
  const ReservationCalendar({
    required this.slots,
    required this.days,
    required this.states,
  });

  final List<ReservationTimeSlot> slots;

  /// `YYYY-MM-DD`，升序。
  final List<String> days;

  /// `日期 -> 时段 id -> 占用`；缺失的组合按「未开放」处理。
  final Map<String, Map<String, ReservationSlotState>> states;

  ReservationSlotState stateOf(String day, String slotId) =>
      states[day]?[slotId] ??
      const ReservationSlotState(
        status: ReservationSlotStatus.notOpen,
        total: 0,
        remaining: 0,
      );

  bool get isEmpty => slots.isEmpty || days.isEmpty;

  static ReservationCalendar fromJson(Object? json) {
    if (json is! Map) {
      return const ReservationCalendar(slots: [], days: [], states: {});
    }
    final map = Map<String, dynamic>.from(json);

    final slots = <ReservationTimeSlot>[
      for (final item in (map['time'] as List? ?? const []))
        ?ReservationTimeSlot.fromJson(item),
    ];

    final days = <String>[
      for (final item in (map['day'] as List? ?? const []))
        if (safeString(item) case final day when day.isNotEmpty) day,
    ];

    final states = <String, Map<String, ReservationSlotState>>{};
    final rawData = map['data'];
    if (rawData is Map) {
      for (final entry in rawData.entries) {
        final day = entry.key.toString();
        final perSlot = entry.value;
        if (perSlot is! Map) continue;
        states[day] = {
          for (final slotEntry in perSlot.entries)
            slotEntry.key.toString(): ReservationSlotState.fromJson(
              slotEntry.value,
            ),
        };
      }
    }

    return ReservationCalendar(slots: slots, days: days, states: states);
  }
}

/// 资源（活动室）定义。
class ReservationResource {
  const ReservationResource({
    required this.id,
    required this.name,
    required this.attributes,
    required this.needsApproval,
    required this.maxPeriodsPerDay,
    this.capacity,
  });

  final String id;
  final String name;

  /// 容量 / 校区 / 分区 / 楼栋等展示用属性。
  final List<ReservationAttribute> attributes;

  /// `config.approval` 存在即需要审批（提交后上传申请表，审核通过才算完成）。
  final bool needsApproval;

  /// 每天最多可预约时段数（`ResourceUseDayTimesRule.times`）；0 表示未限制。
  final int maxPeriodsPerDay;

  /// 容量（属性名含「容量」的数值，如 28）；未提供时为 null（不限人数）。
  final int? capacity;

  static ReservationResource? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = safeString(map['id']);
    if (id.isEmpty) return null;

    final attributes = <ReservationAttribute>[
      for (final item in (map['attribute'] as List? ?? const []))
        ?ReservationAttribute.fromJson(item),
    ];

    final config = map['config'];
    final configMap = config is Map
        ? Map<String, dynamic>.from(config)
        : const <String, dynamic>{};

    var maxPeriods = 0;
    final rules = configMap['rule'];
    if (rules is List) {
      for (final rule in rules) {
        if (rule is! Map) continue;
        if (safeString(rule['class']) != 'ResourceUseDayTimesRule') continue;
        maxPeriods = safeInt(rule['times']);
        break;
      }
    }

    return ReservationResource(
      id: id,
      name: safeString(map['name']),
      attributes: attributes,
      needsApproval: configMap['approval'] is Map,
      maxPeriodsPerDay: maxPeriods,
      capacity: _capacityOf(attributes),
    );
  }

  /// 从展示属性里提容量：属性名含「容量」且值为整数（如「容量/人数: 28」）。
  static int? _capacityOf(List<ReservationAttribute> attributes) {
    for (final attribute in attributes) {
      if (!attribute.name.contains('容量')) continue;
      final value = int.tryParse(attribute.value);
      if (value != null && value > 0) return value;
    }
    return null;
  }
}
