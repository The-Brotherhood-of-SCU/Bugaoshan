// run with: dart run tool/generate_icons.dart
// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Android mipmap sizes
  final androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  // Old icon filenames - only need ic_launcher_old.png for the old icon
  final icons = {'old': 'assets/icon_old.png'};

  for (final entry in icons.entries) {
    final name = entry.key;
    final sourcePath = entry.value;

    if (!File(sourcePath).existsSync()) {
      print('WARNING: $sourcePath not found, skipping.');
      continue;
    }

    final src = img.decodeImage(File(sourcePath).readAsBytesSync())!;
    print('Generated from $sourcePath (${src.width}x${src.height})');

    for (final sizeEntry in androidSizes.entries) {
      final dir = sizeEntry.key;
      final size = sizeEntry.value;
      final resized = img.copyResize(src, width: size, height: size);
      final outPath = 'android/app/src/main/res/$dir/ic_launcher_$name.png';
      File(outPath).createSync(recursive: true);
      File(outPath).writeAsBytesSync(img.encodePng(resized));
      print('  -> $outPath (${size}x$size)');
    }
  }

  // iOS old icon files (2x and 3x)
  final iosSizes = {'old@2x.png': 120, 'old@3x.png': 180};

  final oldSrc = img.decodeImage(
    File('assets/icon_old.png').readAsBytesSync(),
  )!;
  for (final sizeEntry in iosSizes.entries) {
    final filename = sizeEntry.key;
    final size = sizeEntry.value;
    final resized = img.copyResize(oldSrc, width: size, height: size);
    final outPath = 'ios/Runner/$filename';
    File(outPath).createSync(recursive: true);
    File(outPath).writeAsBytesSync(img.encodePng(resized));
    print('  -> $outPath (${size}x$size)');
  }

  print('\nDone!');
}
