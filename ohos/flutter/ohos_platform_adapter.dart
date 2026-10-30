import 'dart:io';

import 'package:bugaoshan/platform/platform_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:open_file_ohos/open_file_ohos.dart' as ohos;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// CPF 与 OHOS 专有依赖只能出现在 ohos/，不进入标准 Flutter 编译图。
class OhosPlatformAdapter extends PlatformAdapter {
  @override
  bool get isOhos => !kIsWeb && Platform.operatingSystem == 'ohos';

  @override
  bool get supportsNativeControls => isOhos;

  @override
  Future<List<SelectedFile>> pickFiles({
    required List<String> allowedExtensions,
  }) async {
    if (!isOhos) return super.pickFiles(allowedExtensions: allowedExtensions);
    const channel = MethodChannel('bugaoshan/file_picker');
    final files =
        await channel.invokeListMethod<Object?>('pickFiles', {
          'allowedExtensions': allowedExtensions,
        }) ??
        const [];
    return files.map((value) {
      final file = Map<String, Object?>.from(value! as Map);
      return SelectedFile(
        name: file['name']! as String,
        path: file['path']! as String,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (!isOhos) return super.getDeviceInfo();
    const channel = MethodChannel('bugaoshan/environment_info');
    return await channel.invokeMapMethod<String, dynamic>('getDeviceInfo') ??
        {};
  }

  @override
  Future<OpenResult> openFile(String path) async {
    if (!isOhos) return super.openFile(path);
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

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
  }) async {
    if (!isOhos) {
      return super.saveFile(
        fileName: fileName,
        bytes: bytes,
        dialogTitle: dialogTitle,
      );
    }
    const channel = MethodChannel('bugaoshan/file_save');
    final uri = await channel.invokeMethod<String>('save', {
      'fileName': fileName,
      'bytes': bytes,
    });
    return uri == null ? null : Uri.parse(uri);
  }

  @override
  Future<bool> saveImage(Uint8List bytes, {String? name}) async {
    if (!isOhos) return super.saveImage(bytes, name: name);
    // 原样写入图片，扩展名必须与内容匹配；插件据此识别媒体格式。
    final extension = switch (bytes) {
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...] => 'png',
      [0xff, 0xd8, 0xff, ...] => 'jpg',
      [0x47, 0x49, 0x46, 0x38, 0x37 || 0x39, 0x61, ...] => 'gif',
      [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ...] =>
        'webp',
      [0x42, 0x4d, ...] => 'bmp',
      _ => throw const FormatException('Unsupported image format'),
    };
    final temporaryRoot = await getTemporaryDirectory();
    final directory = await temporaryRoot.createTemp('gallery-');
    try {
      final file = File('${directory.path}/image.$extension');
      await file.writeAsBytes(bytes, flush: true);
      final result = await ImageGallerySaverPlus.saveFile(file.path);
      if (result is Map && result['isSuccess'] == true) return true;
      if (result is Map &&
          result['errorMessage'] == 'user refuses permission') {
        return false;
      }
      throw StateError('HarmonyOS gallery save failed');
    } finally {
      await directory.delete(recursive: true);
    }
  }

  @override
  Widget createNativeControl({
    required String viewType,
    required TextDirection layoutDirection,
    required Map<String, Object> creationParams,
    required ValueChanged<int> onPlatformViewCreated,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) => OhosView(
    viewType: viewType,
    layoutDirection: layoutDirection,
    creationParams: creationParams,
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: onPlatformViewCreated,
    gestureRecognizers: gestureRecognizers,
    clipBehavior: Clip.none,
  );
}
