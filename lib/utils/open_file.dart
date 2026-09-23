import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_file_ohos/open_file_ohos.dart' as ohos;
import 'package:open_filex/open_filex.dart';

/// 所有平台共用的文件打开入口，统一插件返回的状态和消息。
Future<OpenResult> openFile(String path) async {
  if (!kIsWeb && Platform.operatingSystem == 'ohos') {
    final result = await ohos.OpenFile.open(path);
    return OpenResult(
      type: switch (result.type) {
        ohos.ResultType.done => ResultType.done,
        ohos.ResultType.fileNotFound => ResultType.fileNotFound,
        ohos.ResultType.noAppToOpen => ResultType.noAppToOpen,
        ohos.ResultType.permissionDenied => ResultType.permissionDenied,
        ohos.ResultType.error => ResultType.error,
      },
      message: result.message,
    );
  }
  return OpenFilex.open(path);
}
