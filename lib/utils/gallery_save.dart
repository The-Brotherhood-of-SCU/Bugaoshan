import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 原样保存图片到相册；鸿蒙用户取消保存时返回 false。
Future<bool> saveImageBytesToGallery(Uint8List bytes) async {
  if (kIsWeb || Platform.operatingSystem != 'ohos') {
    final granted = await Gal.requestAccess();
    if (!granted) throw StateError('Gallery access denied');
    await Gal.putImageBytes(bytes);
    return true;
  }

  // OH saveFile 按扩展名识别格式，不能把所有图片都命名为 jpg。
  final extension = switch (bytes) {
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...] => 'png',
    [0xff, 0xd8, 0xff, ...] => 'jpg',
    [0x47, 0x49, 0x46, 0x38, 0x37 || 0x39, 0x61, ...] => 'gif',
    [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ...] => 'webp',
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
    if (result is Map && result['errorMessage'] == 'user refuses permission') {
      return false;
    }
    throw StateError(
      result is Map
          ? result['errorMessage']?.toString() ?? 'Gallery save failed'
          : 'Gallery save failed',
    );
  } finally {
    await directory.delete(recursive: true);
  }
}
