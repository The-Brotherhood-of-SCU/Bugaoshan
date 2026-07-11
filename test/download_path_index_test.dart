import 'dart:io';

import 'package:bugaoshan/pages/campus/downloads/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download-path-index-');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('persists a distinct local path for each URL', () async {
    final first = File('${tempDir.path}/attachment.pdf');
    final second = File('${tempDir.path}/attachment (1).pdf');
    await first.writeAsString('first');
    await second.writeAsString('second');
    final index = DownloadPathIndex(tempDir);

    await index.record('https://example.com/first', first.path);
    await index.record('https://example.com/second', second.path);

    final reloaded = DownloadPathIndex(tempDir);
    expect(
      await reloaded.resolve(
        'https://example.com/first',
        legacyFileName: 'attachment.pdf',
      ),
      first.path,
    );
    expect(
      await reloaded.resolve(
        'https://example.com/second',
        legacyFileName: 'attachment.pdf',
      ),
      second.path,
    );
  });

  test('adopts each legacy file for at most one URL', () async {
    final legacy = File('${tempDir.path}/attachment.pdf');
    await legacy.writeAsString('legacy');
    final index = DownloadPathIndex(tempDir);

    expect(
      await index.resolve(
        'https://example.com/first',
        legacyFileName: 'attachment.pdf',
      ),
      legacy.path,
    );
    expect(
      await index.resolve(
        'https://example.com/second',
        legacyFileName: 'attachment.pdf',
      ),
      isNull,
    );

    final legacyVariant = File('${tempDir.path}/attachment (1).pdf');
    await legacyVariant.writeAsString('second legacy');
    expect(
      await index.resolve(
        'https://example.com/second',
        legacyFileName: 'attachment.pdf',
      ),
      legacyVariant.path,
    );
  });

  test('serializes concurrent legacy adoption', () async {
    final legacy = File('${tempDir.path}/attachment.pdf');
    await legacy.writeAsString('legacy');

    final resolved = await Future.wait([
      DownloadPathIndex(
        tempDir,
      ).resolve('https://example.com/first', legacyFileName: 'attachment.pdf'),
      DownloadPathIndex(
        tempDir,
      ).resolve('https://example.com/second', legacyFileName: 'attachment.pdf'),
    ]);

    expect(resolved.where((path) => path == legacy.path), hasLength(1));
    expect(resolved.where((path) => path == null), hasLength(1));
  });

  test('removes mappings that point at a deleted file', () async {
    final file = File('${tempDir.path}/attachment.pdf');
    await file.writeAsString('content');
    final index = DownloadPathIndex(tempDir);
    await index.record('https://example.com/attachment', file.path);

    await index.removePath(file.path);

    expect(
      await index.resolve(
        'https://example.com/attachment',
        legacyFileName: 'missing.pdf',
      ),
      isNull,
    );
  });
}
