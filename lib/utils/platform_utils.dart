import 'package:bugaoshan/platform/platform_adapter.dart';

/// 由鸿蒙启动入口选择；不引用标准 Flutter 中不存在的枚举或 API。
bool get isOhos => PlatformAdapter.instance.isOhos;
