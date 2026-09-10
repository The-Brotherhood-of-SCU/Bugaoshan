import 'package:flutter/material.dart';

/// 校园查询页（课程课表 / 班级课表等）筛选栏里，
/// 下拉框与文本框共用的输入装饰配置。
/// 不加 isDense，让 InputDecorator 取 M3 标准交互高度
/// （kMinInteractiveDimension = 48），与培养方案、成绩等页面的
/// 筛选控件高度一致，避免比应用内其他输入框矮一截。
const InputDecoration kFilterInputDecoration = InputDecoration(
  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  border: OutlineInputBorder(),
);
