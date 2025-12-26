
import 'dart:io';

String getEnvironmentInfo(){
  var dartVersion=Platform.version;
  var system=Platform.operatingSystem;
  var env=Platform.executableArguments;
  var exe=Platform.executable;
  var systemVersion=Platform.operatingSystemVersion;
  var environmentText=
      "Dart: $dartVersion\n"
      "System: $system\n"
      "System Ver: $systemVersion\n"
      "exe: $exe\n"
      "Args: $env\n";
  return environmentText;
}