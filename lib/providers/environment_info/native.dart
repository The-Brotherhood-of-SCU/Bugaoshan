import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> getEnvironmentInfo() async {
  var dartVersion = Platform.version;
  var system = Platform.operatingSystem;
  var env = Platform.executableArguments;
  var exe = Platform.executable;
  var systemVersion = Platform.operatingSystemVersion;
  var documentsDir = await getApplicationDocumentsDirectory();
  var environmentText =
      "Dart: $dartVersion\n"
      "System: $system\n"
      "System Ver: $systemVersion\n"
      "exe: $exe\n"
      "Args: $env\n"
      "Documents Dir: ${documentsDir.path}\n";
  return environmentText;
}
