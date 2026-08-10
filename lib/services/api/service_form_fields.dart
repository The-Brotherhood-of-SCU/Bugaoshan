/// 请假表单字段元数据（基于 app_id=350 "离校请假" 真实表单）
///
/// 字段 key 来自 `/site/form/start-data` 返回的 auth/data 结构；
/// 中文标签和选项来自用户实测。未确认的字段标 `confirmed: false`，
/// 等补齐后移除占位。
library;

import 'package:flutter/material.dart';

/// 日期字段常量（Calendar_25/26，用户确认：离校时间 / 返校时间）。
const String kFieldLeaveDate = 'Calendar_25';
const String kFieldReturnDate = 'Calendar_26';
/// 事由说明多行文本（MultiInput_40）。
const String kFieldDetail = 'MultiInput_40';
/// 地区（Region_80，省-市-区县三级联动 + 详细地址）。
const String kFieldRegion = 'Region_80';

/// 单个字段定义。
class ServiceFieldMeta {
  final String key;
  final String label;
  final IconData icon;
  final bool confirmed;
  final List<ServiceFieldOption>? options;
  final String? hint;

  const ServiceFieldMeta({
    required this.key,
    required this.label,
    required this.icon,
    this.confirmed = true,
    this.options,
    this.hint,
  });
}

/// 单选/下拉选项。
class ServiceFieldOption {
  final String value;
  final String label;
  const ServiceFieldOption(this.value, this.label);
}

/// 请假表单字段映射。
///
/// 已确认（用户实测）：
/// - Radio_30 离开校区：望江校区(1)/华西校区(2)/江安校区(3)
/// - Radio_67 请假事由：实习(1)/求职(2)/探亲访友(3)/就医(4)/出差(5)/回家(6)/其它(7)
/// - Calendar_25 / Calendar_26：离校时间 / 返校时间
/// - Region_80：省-市-区县三级联动 + 详细地址（value 为行政区划代码）
/// - MultiInput_40：多行文本（writable）
///
/// 待确认：
/// - File_71 附件（writable）
/// - Input_84（front_readonly）
class ServiceFormFields {
  ServiceFormFields._();

  static const radioCampus = ServiceFieldMeta(
    key: 'Radio_30',
    label: '离开校区',
    icon: Icons.school_outlined,
    options: [
      ServiceFieldOption('1', '望江校区'),
      ServiceFieldOption('2', '华西校区'),
      ServiceFieldOption('3', '江安校区'),
    ],
  );

  static const radioReason = ServiceFieldMeta(
    key: 'Radio_67',
    label: '请假事由',
    icon: Icons.edit_note_outlined,
    options: [
      ServiceFieldOption('1', '实习'),
      ServiceFieldOption('2', '求职'),
      ServiceFieldOption('3', '探亲访友'),
      ServiceFieldOption('4', '就医'),
      ServiceFieldOption('5', '出差'),
      ServiceFieldOption('6', '回家'),
      ServiceFieldOption('7', '其它'),
    ],
  );

  /// 地区（Region_80，省-市-区县三级 + 详细地址，必填）。
  static const region = ServiceFieldMeta(
    key: kFieldRegion,
    label: '去往地址',
    icon: Icons.place_outlined,
    hint: '选择省份、城市、区县并填写详细地址',
  );

  /// 已由服务端带出、只读展示的信息字段（User_21~24）。
  static const List<ServiceFieldMeta> readonlyInfo = [
    ServiceFieldMeta(key: 'User_21', label: '学号', icon: Icons.tag),
    ServiceFieldMeta(key: 'User_22', label: '姓名', icon: Icons.person_outline),
    ServiceFieldMeta(
      key: 'User_23',
      label: '学院',
      icon: Icons.account_balance_outlined,
    ),
    ServiceFieldMeta(
      key: 'User_24',
      label: '手机号',
      icon: Icons.phone_outlined,
    ),
  ];
}
