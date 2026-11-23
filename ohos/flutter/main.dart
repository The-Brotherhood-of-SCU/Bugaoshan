import 'package:bugaoshan/platform/platform_adapter.dart';
import 'package:bugaoshan/upstream_main.dart' as upstream;

import 'ohos_platform_adapter.dart';

/// flutterw 为本入口建立工作目录链接；业务启动流程仍使用根 main.dart。
Future<void> main() async {
  PlatformAdapter.instance = OhosPlatformAdapter();
  await upstream.main();
}
