import 'package:web/web.dart' as html;

String getEnvironmentInfo(){
  var navigator=html.window.navigator;
  var platform=navigator.platform;
  var isOnline=navigator.onLine;
  var vendor=navigator.vendor;
  var ua=navigator.userAgent;
  var deviceMemory=navigator.deviceMemory;
  var hardwareConcurrency=navigator.hardwareConcurrency;


  return "Platform: $platform\n"
      "Vendor: $vendor\n"
      "UA: $ua\n"
      "Memory: $deviceMemory\n"
      "Online: $isOnline\n"
      "Hardware Concurrency: $hardwareConcurrency\n"
  ;
}