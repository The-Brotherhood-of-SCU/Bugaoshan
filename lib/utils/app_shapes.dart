import 'package:flutter/material.dart';

/// MD3 Expressive 形状令牌
/// 对齐 Material 3 Expressive Corner Radius Scale
class AppShapes {
  AppShapes._();

  /// 8dp - 小标签、chip、状态标记
  static const double small = 8;

  /// 12dp - 图标容器、中等元素
  static const double medium = 12;

  /// 16dp - 次级卡片、输入框
  static const double large = 16;

  /// 20dp - 主卡片容器（MD3 Expressive: Large increased）
  static const double largeIncreased = 20;

  /// 28dp - 底部弹窗、超大容器（MD3 Expressive: Extra Large）
  static const double extraLarge = 28;

  /// 完全圆角 - 药丸形/圆形
  static const double full = 999;
}

/// 集中化动效曲线（为后续 MD3 Expressive 动效适配预留）
class AppCurves {
  AppCurves._();

  /// 标准缓动
  static const Curve standard = Curves.easeInOutCubic;

  /// 强调缓动
  static const Curve emphasized = Curves.easeInOutCubic;
}
