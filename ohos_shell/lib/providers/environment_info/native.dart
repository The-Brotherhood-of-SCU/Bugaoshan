import 'dart:io';

import 'package:os_type/os_type.dart';
import 'package:path_provider/path_provider.dart';

Future<String> getEnvironmentInfo() async {
  var dartVersion = Platform.version;
  var system = Platform.operatingSystem;
  var env = Platform.executableArguments;
  var exe = Platform.executable;
  var systemVersion = Platform.operatingSystemVersion;
  var documentsDir = await getApplicationDocumentsDirectory();
  var supportDir = await getApplicationSupportDirectory();

  var environmentText =
      "Dart: $dartVersion\n"
      "System: $system\n"
      "System Ver: $systemVersion\n"
      "exe: $exe\n"
      "Args: $env\n"
      "Documents Dir: ${documentsDir.path}\n"
      "Support Dir: ${supportDir.path}\n";

  if (OS.isHarmony) await OS.initHarmonyDeviceType();
  environmentText +=
      "Harmony Device: ${OS.isHarmony}\n"
      "Is PC: ${OS.isPCOS}\n"
      "Is Mobile: ${OS.isMobileOS}\n";

  return environmentText;
}
