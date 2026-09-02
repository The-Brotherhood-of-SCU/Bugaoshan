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

/// 维修项目（`publish/getProjectByAreaId` 返回的树节点）。
class RepairProject {
  final String label;
  final String value;
  final String? parentId;

  const RepairProject({
    required this.label,
    required this.value,
    this.parentId,
  });

  factory RepairProject.fromJson(Map<String, dynamic> json) {
    return RepairProject(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? json['id']?.toString() ?? '',
      parentId: json['pId']?.toString(),
    );
  }
}

/// 报修区域树节点（`publish/getAreaTree` 返回）。
class RepairAreaNode {
  final String id;
  final String name;
  final List<RepairAreaNode> children;

  const RepairAreaNode({
    required this.id,
    required this.name,
    required this.children,
  });

  /// 从根到该节点的完整区域名（如 `望江学生区/东苑五栋`）。
  String get fullName =>
      children.isEmpty ? name : '$name/${children.map((c) => c.name).first}';

  factory RepairAreaNode.fromJson(Map<String, dynamic> json) {
    final children = json['children'] is List
        ? (json['children'] as List)
              .whereType<Map>()
              .map((e) => RepairAreaNode.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <RepairAreaNode>[];
    return RepairAreaNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      children: children,
    );
  }
}

/// 报修工单（`activeTemplateData/list`「我的动态」的行）。
class RepairTicket {
  final String id;
  final String areaName;
  final String projectName;
  final String content;
  final String status;
  final int createTime;

  /// 动态列表的展示时间（`activeTime`，`YYYY-MM-DD HH:mm:ss`），
  /// 用于排序；缺失时为空（按 createTime 回退）。
  final String activeTime;

  const RepairTicket({
    required this.id,
    required this.areaName,
    required this.projectName,
    required this.content,
    required this.status,
    required this.createTime,
    this.activeTime = '',
  });

  /// 工单状态文案（后端直接返回中文：已关闭/待完工/待评价/已撤回）。
  String get statusLabel => status;

  /// 从「我的动态」接口（`activeTemplateData/list`）的行构造工单。
  ///
  /// 该接口的 `status` 直接是中文文案（已关闭/待完工/待评价/已撤回），
  /// `content` 是 JSON 字符串（含维修项目/故障地点/故障描述）。
  factory RepairTicket.fromDynamicJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsed = const {};
    final rawContent = json['content']?.toString() ?? '';
    if (rawContent.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawContent);
        if (decoded is Map<String, dynamic>) parsed = decoded;
      } catch (_) {
        // content 非 JSON 时原样作为故障描述
      }
    }
    return RepairTicket(
      id: json['id']?.toString() ?? json['activeId']?.toString() ?? '',
      areaName: parsed['故障地点']?.toString() ?? '',
      projectName: parsed['维修项目']?.toString() ?? '',
      content: parsed['故障描述']?.toString() ?? rawContent,
      // 后端直接返回中文状态
      status: json['status']?.toString() ?? '',
      createTime: int.tryParse(json['createTime']?.toString() ?? '0') ?? 0,
      activeTime: json['activeTime']?.toString() ?? '',
    );
  }
}
