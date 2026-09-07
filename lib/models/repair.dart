/// 智慧后勤（zhhq）在线报修相关的强类型模型。
///
/// 对应 `repair/*` 与 `oneNetPublish/*` 接口的返回结构
/// （已通过真实抓包确认字段）。
library;

import 'dart:convert';

/// 常用地址（`oneNetPublish/getCommonAddress` 返回）。
class RepairAddress {
  final String id;
  final String areaName;
  final String addressDetail;
  final String phone;
  final String areaId;

  /// 是否默认地址（"1"=默认）。
  final bool isCommon;

  /// 用户 id（`createUser`，用于「我的动态」列表筛选）。
  final String userId;

  const RepairAddress({
    required this.id,
    required this.areaName,
    required this.addressDetail,
    required this.phone,
    required this.areaId,
    required this.isCommon,
    this.userId = '',
  });

  String get displayName => isCommon
      ? '$areaName / $addressDetail（默认）'
      : '$areaName / $addressDetail';

  factory RepairAddress.fromJson(Map<String, dynamic> json) {
    return RepairAddress(
      id: json['id']?.toString() ?? '',
      areaName: json['areaName']?.toString() ?? '',
      addressDetail: json['addressDetail']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      areaId: json['areaId']?.toString() ?? '',
      isCommon: json['ifCommon']?.toString() == '1',
      userId:
          json['userId']?.toString() ?? json['createUser']?.toString() ?? '',
    );
  }
}

/// 维修项目（`publish/getProjectByAreaId` 返回的**两级树**节点）。
///
/// 顶层节点是大类（如「水」「木」「泥」），其 `children` 是具体维修项目
/// （如「水龙头类」「门锁窗扣类」）。提交工单时 `projectId` 需为**叶子**
/// 项目的 `value`（如 `101`），`projectName` 用「大类/项目」完整名。
class RepairProject {
  final String label;
  final String value;
  final List<RepairProject> children;

  const RepairProject({
    required this.label,
    required this.value,
    this.children = const [],
  });

  bool get isCategory => children.isNotEmpty;

  factory RepairProject.fromJson(Map<String, dynamic> json) {
    final children = json['children'] is List
        ? (json['children'] as List)
              .whereType<Map>()
              .map((e) => RepairProject.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <RepairProject>[];
    return RepairProject(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? json['id']?.toString() ?? '',
      children: children,
    );
  }
}

/// 报修负责部门（`getAcceptUserByAreaIdAndProjectId` 返回）。
///
/// 提交工单的前提：用该接口按区域+项目预取维修负责部门，
/// 其 `deptId`/`deptName`/`payName` 直接作为 `publish` 请求体的
/// `acceptDeptId`/`acceptDeptName`/`payName`。
class RepairAcceptDept {
  final String deptId;
  final String deptName;
  final String payName;

  const RepairAcceptDept({
    required this.deptId,
    required this.deptName,
    required this.payName,
  });

  factory RepairAcceptDept.fromJson(Map<String, dynamic> json) {
    return RepairAcceptDept(
      deptId: json['deptId']?.toString() ?? '',
      deptName: json['deptName']?.toString() ?? '',
      payName: json['payName']?.toString() ?? '',
    );
  }
}

/// 报修区域树节点（`publish/getAreaTree` 返回）。
class RepairAreaNode {
  final String id;
  final String name;

  /// 父级节点名（递归解析时携带），根节点为空串。
  final String parentName;
  final List<RepairAreaNode> children;

  const RepairAreaNode({
    required this.id,
    required this.name,
    this.parentName = '',
    this.children = const [],
  });

  /// 从根到该节点的完整区域名（如 `望江学生区/东苑五栋`）。
  ///
  /// 递归携带父级路径，避免深树丢层级（旧实现只拼第一层子节点）。
  String get fullName => parentName.isEmpty ? name : '$parentName/$name';

  factory RepairAreaNode.fromJson(
    Map<String, dynamic> json, {
    String parentName = '',
  }) {
    final children = json['children'] is List
        ? (json['children'] as List)
              .whereType<Map>()
              .map(
                (e) => RepairAreaNode.fromJson(
                  Map<String, dynamic>.from(e),
                  parentName: json['name']?.toString() ?? '',
                ),
              )
              .toList(growable: false)
        : const <RepairAreaNode>[];
    return RepairAreaNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentName: parentName,
      children: children,
    );
  }
}

/// 报修工单（`activeTemplateData/list`「我的动态」的行）。
class RepairTicket {
  /// 详情接口（`repairInfo/get`）使用的工单 id（= 列表行的 `activeId`）。
  final String id;

  /// 列表行自己的 id（`activeId`，跳详情用）。
  final String activeId;

  /// 故障地点（content 解析自 `故障地点`）。
  final String areaName;

  /// 维修项目（content 解析自 `维修项目`）。
  final String projectName;

  /// 服务单位（content 解析自 `服务单位`，部分工单才有）。
  final String serviceUnit;

  /// 故障描述（content 解析自 `故障描述`）。
  ///
  /// 解析失败时回退为各字段拼接，**不会**展示原始 JSON 字符串。
  final String content;

  /// 中文状态（后端直接返回：已关闭/待完工/待评价/已撤回）。
  final String status;

  final int createTime;

  /// 动态列表的展示时间（`activeTime`，`YYYY-MM-DD HH:mm:ss`），
  /// 用于排序；缺失时为空（按 createTime 回退）。
  final String activeTime;

  const RepairTicket({
    required this.id,
    this.activeId = '',
    this.areaName = '',
    this.projectName = '',
    this.serviceUnit = '',
    this.content = '',
    this.status = '',
    this.createTime = 0,
    this.activeTime = '',
  });

  /// 工单状态文案（后端直接返回中文：已关闭/待完工/待评价/已撤回）。
  String get statusLabel => status;

  /// 从「我的动态」接口（`activeTemplateData/list`）的行构造工单。
  ///
  /// 该接口的 `status` 直接是中文文案（已关闭/待完工/待评价/已撤回）。
  /// `content` 是 JSON 字符串（含维修项目/故障地点/服务单位/故障描述），
  /// 但个别模板/异常数据可能是双层转义、或已是对象，这里统一兼容。
  factory RepairTicket.fromDynamicJson(Map<String, dynamic> json) {
    final activeId =
        json['activeId']?.toString() ?? json['id']?.toString() ?? '';
    final parsed = _decodeContent(json['content']);
    return RepairTicket(
      // 详情接口用 activeId 作为 id；列表行自身有独立 id
      id: activeId,
      activeId: activeId,
      areaName: parsed['故障地点']?.toString() ?? '',
      projectName: parsed['维修项目']?.toString() ?? '',
      serviceUnit: parsed['服务单位']?.toString() ?? '',
      content: _displayContent(parsed, json['content']),
      // 后端直接返回中文状态
      status: json['status']?.toString() ?? '',
      createTime: int.tryParse(json['createTime']?.toString() ?? '0') ?? 0,
      activeTime: json['activeTime']?.toString() ?? '',
    );
  }

  /// 把 `content` 统一解析为 Map。
  ///
  /// 兼容三种形态：
  /// - Map（后端已解析为对象）
  /// - JSON 字符串（`{"维修项目":...}`）
  /// - 双层转义 JSON 字符串（字符串内嵌 JSON 字符串，如 `"{\"维修项目\":...}"`）
  static Map<String, dynamic> _decodeContent(dynamic content) {
    var current = content;
    // 最多解两层（字符串内再套字符串）
    for (var i = 0; i < 2; i++) {
      if (current is Map) {
        return Map<String, dynamic>.from(current);
      }
      if (current is! String || current.trim().isEmpty) {
        return const {};
      }
      final trimmed = current.trim();
      // 快速判断是否 JSON：以 { 或 [ 开头
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
        return const {};
      }
      try {
        final decoded = jsonDecode(trimmed);
        current = decoded;
      } catch (_) {
        return const {};
      }
    }
    return current is Map ? Map<String, dynamic>.from(current) : const {};
  }

  /// 展示内容：优先「故障描述」字段；缺失时回退为字段拼接
  /// （维修项目/故障地点/服务单位），**绝不**回退为原始 JSON 文本。
  static String _displayContent(
    Map<String, dynamic> parsed,
    dynamic rawContent,
  ) {
    final desc = parsed['故障描述']?.toString();
    if (desc != null && desc.trim().isNotEmpty) {
      return desc;
    }
    final project = parsed['维修项目']?.toString() ?? '';
    final location = parsed['故障地点']?.toString() ?? '';
    final unit = parsed['服务单位']?.toString() ?? '';
    final parts = [project, location, unit].where((s) => s.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' · ');
    // 完全无字段：content 本就不是 JSON 时原样展示（如纯文本描述）
    if (rawContent is String && rawContent.isNotEmpty) {
      final trimmed = rawContent.trim();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
        return trimmed;
      }
    }
    return '';
  }
}

/// 报修工单详情（`repairInfo/get` 返回）。
///
/// 字段与列表行（[RepairTicket]）完全不同：
/// - `status` 是**数字**（如 `"3"`），需要映射为中文文案
/// - `projectName`/`content` 已是纯文本（非 JSON）
/// - `finishedInfo` 含完成信息（`repairId` 供评价请求使用）
/// - `logVOS` 为工单进度时间线
class RepairTicketDetail {
  /// 工单 id（撤回报文用它）。
  final String id;

  /// 报修编号（如 `202609030009`）。
  final String serialNumber;

  /// 维修项目（已解析的纯文本）。
  final String projectName;

  /// 故障描述（纯文本）。
  final String content;

  /// 故障地点（`areaName` 可能为 `区域/楼栋`，`address` 为详细地址）。
  final String areaName;
  final String address;

  /// 服务单位（负责人部门）。
  final String acceptDeptName;

  /// 收费类型（如「无偿」）。
  final String payName;

  /// 期望时间（`bookTimeString`，如 `2026-09-03 10:00-12:00`）。
  final String bookTimeString;

  /// 是否允许无人时维修。
  final bool ifOnduty;

  /// 状态数字（如 `"3"`）；映射文案见 [statusLabel]。
  final String status;

  /// 是否已评价（`"0"`=否）。
  final String ifCommont;

  /// 是否已办结（`"0"`=否）。
  final String ifComplete;

  /// 工单进度时间线（倒序，最新在前）。
  final List<RepairLogItem> logs;

  /// 完成信息（待评价工单用 `finishedInfo.repairId` 发评价）。
  final RepairFinishedInfo? finishedInfo;

  const RepairTicketDetail({
    required this.id,
    this.serialNumber = '',
    this.projectName = '',
    this.content = '',
    this.areaName = '',
    this.address = '',
    this.acceptDeptName = '',
    this.payName = '',
    this.bookTimeString = '',
    this.ifOnduty = false,
    this.status = '',
    this.ifCommont = '0',
    this.ifComplete = '0',
    this.logs = const [],
    this.finishedInfo,
  });

  /// 状态中文文案（数字状态映射，与「我的动态」列表页文案一致）。
  String get statusLabel => switch (status) {
    '0' => '已关闭',
    '1' => '待完工',
    '2' => '已撤回',
    _ => '待评价', // 3=待评价? / 4=待评价（可评价）
  };

  factory RepairTicketDetail.fromJson(Map<String, dynamic> json) {
    final logRaw = json['logVOS'];
    final logs = logRaw is List
        ? logRaw
              .whereType<Map>()
              .map((e) => RepairLogItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <RepairLogItem>[];
    final finishedRaw = json['finishedInfo'];
    final finishedInfo = finishedRaw is Map
        ? RepairFinishedInfo.fromJson(Map<String, dynamic>.from(finishedRaw))
        : null;
    return RepairTicketDetail(
      id: json['id']?.toString() ?? '',
      serialNumber: json['serialNumber']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      areaName: json['areaName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      acceptDeptName: json['acceptDeptName']?.toString() ?? '',
      payName: json['payName']?.toString() ?? '',
      bookTimeString: json['bookTimeString']?.toString() ?? '',
      ifOnduty: json['ifOnduty']?.toString() == '1',
      status: json['status']?.toString() ?? '',
      ifCommont: json['ifCommont']?.toString() ?? '0',
      ifComplete: json['ifComplete']?.toString() ?? '0',
      logs: logs,
      finishedInfo: finishedInfo,
    );
  }
}

/// 工单进度时间线单条（`logVOS` 元素）。
class RepairLogItem {
  /// 状态名（如「派工」「审核」「报修」）。
  final String statusName;

  /// 描述内容（如「被【曾伟地】指派维修工…」）。
  final String content;

  /// 时间（`createTime`，`YYYY-MM-DD HH:mm:ss`）。
  final String createTime;

  const RepairLogItem({
    this.statusName = '',
    this.content = '',
    this.createTime = '',
  });

  factory RepairLogItem.fromJson(Map<String, dynamic> json) {
    return RepairLogItem(
      statusName: json['statusName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createTime: json['createTime']?.toString() ?? '',
    );
  }
}

/// 工单完成信息（`finishedInfo`）。
class RepairFinishedInfo {
  /// 评价请求（`visitEvaluateUser/save`）使用的 `repairId`。
  final String repairId;

  /// 维修完成时间（`completeTime`）。
  final String completeTime;

  /// 实际收费金额。
  final String totalAmount;

  const RepairFinishedInfo({
    this.repairId = '',
    this.completeTime = '',
    this.totalAmount = '',
  });

  factory RepairFinishedInfo.fromJson(Map<String, dynamic> json) {
    return RepairFinishedInfo(
      repairId: json['repairId']?.toString() ?? '',
      completeTime: json['completeTime']?.toString() ?? '',
      totalAmount: json['totalAmount']?.toString() ?? '',
    );
  }
}
