import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:bugaoshan/utils/platform_utils.dart';

/// 保存文件到用户选择的位置；取消时返回 null。
Future<Uri?> saveFile({
  required String fileName,
  required Uint8List bytes,
  String? dialogTitle,
}) async {
  if (isOhos) {
    const channel = MethodChannel('bugaoshan/file_save');
    final path = await channel.invokeMethod<String>('save', {
      'fileName': fileName,
      'bytes': bytes,
    });
    return path == null ? null : Uri.parse(path);
  }
  return FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    dialogTitle: dialogTitle,
  );
}
