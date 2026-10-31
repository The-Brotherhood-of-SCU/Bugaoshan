import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  final loggers = <AppLogger>[];

  AppLogger logger({int maxBytesPerFile = 2 * 1024 * 1024}) {
    final instance = AppLogger(maxBytesPerFile: maxBytesPerFile);
    loggers.add(instance);
    return instance;
  }

  File current() => File('${directory.path}/bugaoshan.log');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    directory = await Directory.systemTemp.createTemp(
      'bugaoshan_sink_regression',
    );
  });

  tearDown(() async {
    for (final instance in loggers) {
      await instance.disableFileSink();
      instance.dispose();
    }
    loggers.clear();
    await getIt.reset();
    await directory.delete(recursive: true);
  });

  test('开启尚未完成时关闭，最终保持关闭且不再落盘', () async {
    final instance = logger();
    final enabling = instance.enableFileSink(overridePath: directory.path);
    final disabling = instance.disableFileSink();
    await Future.wait([enabling, disabling]);

    expect(instance.fileSinkEnabled, isFalse);
    expect(instance.fileSinkPath, isNull);
    instance.e('Test', 'after-off');
    expect(await current().readAsString(), isNot(contains('after-off')));
  });

  test('监听者在开启通知中立即关闭，也按调用顺序收尾', () async {
    final instance = logger();
    Future<void>? disabling;
    var reacted = false;
    instance.addListener(() {
      if (!reacted && instance.fileSinkEnabled) {
        reacted = true;
        disabling = instance.disableFileSink();
      }
    });
    final enabling = instance.enableFileSink(overridePath: directory.path);
    await Future.wait([enabling, disabling!]);

    expect(instance.fileSinkEnabled, isFalse);
    expect(instance.fileSinkPath, isNull);
  });

  test('关闭尚未完成时开启，最终可写并保留前后记录', () async {
    final instance = logger();
    await instance.enableFileSink(overridePath: directory.path);
    instance.e('Test', 'before-off');
    final disabling = instance.disableFileSink();
    final enabling = instance.enableFileSink(overridePath: directory.path);
    instance.e('Test', 'after-on');
    await Future.wait([disabling, enabling]);

    expect(instance.fileSinkEnabled, isTrue);
    expect(instance.fileSinkUnavailable, isFalse);
    await instance.disableFileSink();
    final content = await current().readAsString();
    expect(content, contains('before-off'));
    expect(content, contains('after-on'));
  });

  test('关闭并清理后立即开启，旧清理不会删除新记录或关闭新句柄', () async {
    final instance = logger();
    await instance.enableFileSink(overridePath: directory.path);
    instance.e('Test', 'old-record');
    final deleting = instance.deletePersistedFiles();
    final enabling = instance.enableFileSink(overridePath: directory.path);
    instance.e('Test', 'new-record');
    await Future.wait([deleting, enabling]);

    expect(instance.fileSinkEnabled, isTrue);
    expect(instance.fileSinkUnavailable, isFalse);
    await instance.disableFileSink();
    final content = await current().readAsString();
    expect(content, isNot(contains('old-record')));
    expect(content, contains('new-record'));
  });

  test('开关已为默认开启时清除数据，无通知也恢复落盘', () async {
    final prefs = await SharedPreferences.getInstance();
    final instance = logger();
    await instance.enableFileSink(overridePath: directory.path);
    instance.e('Test', 'before-clear');

    await prefs.clear();
    await instance.deletePersistedFiles(preserveEnabled: true);

    expect(instance.fileSinkEnabled, isTrue);
    expect(instance.fileSinkUnavailable, isFalse);
    instance.e('Test', 'after-clear');
    await instance.disableFileSink();
    final content = await current().readAsString();
    expect(content, isNot(contains('before-clear')));
    expect(content, contains('after-clear'));
  });

  test('保留开关状态的清理不会打开原本关闭的落盘', () async {
    final instance = logger();
    await instance.enableFileSink(overridePath: directory.path);
    await instance.disableFileSink();
    await instance.deletePersistedFiles(preserveEnabled: true);

    expect(instance.fileSinkEnabled, isFalse);
    expect(await current().exists(), isFalse);
  });

  test('异步打开失败如实报告且持续失败不会生成递归写入', () async {
    // openWrite 返回句柄后异步失败，与同步 mkdir 失败覆盖不同的路径。
    final blocker = Directory(current().path);
    await blocker.create();
    final instance = logger();
    await instance.enableFileSink(overridePath: directory.path);
    expect(instance.fileSinkEnabled, isTrue);
    expect(instance.fileSinkUnavailable, isTrue);
    expect(instance.fileSinkError, isNotNull);

    instance.e('Test', 'original-crash');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final failures = instance.entries.where(
      (entry) => entry.tag == 'AppLogger',
    );
    expect(failures.length, lessThanOrEqualTo(4));
    final count = instance.entries.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(instance.entries.length, count, reason: '故障不能自触发新日志和无限重试');
    expect(instance.droppedWriteLines, 0);

    // 重试上限耗尽后，存储恢复也不会自行空转；手动开启可补写原始记录。
    await blocker.delete();
    instance.e('Test', 'after-storage-repair');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await current().exists(), isFalse);
    await instance.enableFileSink(overridePath: directory.path);
    expect(instance.fileSinkUnavailable, isFalse);
    await instance.disableFileSink();
    final content = await current().readAsString();
    expect(content, contains('original-crash'));
    expect(content, contains('after-storage-repair'));
    expect(content, isNot(contains('[AppLogger]')));
  });

  test('轮转失败有界重试，不能在反复成功重开空句柄时无限循环', () async {
    final instance = logger(maxBytesPerFile: 100);
    await instance.enableFileSink(overridePath: directory.path);
    await Directory('${directory.path}/bugaoshan.1.log').create();
    instance.e('Test', 'first ${'x' * 100}');
    instance.e('Test', 'rotation-blocked');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(instance.fileSinkUnavailable, isTrue);
    expect(instance.fileSinkError, isNotNull);
    final count = instance.entries.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(instance.entries.length, count);
    expect(count, lessThanOrEqualTo(10));
  });

  test('冷启动导出按历史顺序包含轮转、当前文件和内存上下文并脱敏', () async {
    final first = logger(maxBytesPerFile: 100);
    await first.enableFileSink(overridePath: directory.path);
    for (var i = 0; i < 3; i++) {
      first.e('Test', 'previous-crash-$i ${'x' * 100}');
    }
    await first.disableFileSink();
    // 历史文件也重新脱敏，兼容早期版本写出的内容。
    await current().writeAsString(
      '\ntoken=old-secret\n',
      mode: FileMode.append,
    );
    await File(
      '${directory.path}/bugaoshan-export-old.log',
    ).writeAsString('excluded-old-snapshot');
    final second = logger();
    await second.enableFileSink(overridePath: directory.path);
    second.i('Test', 'current-debug-context');
    second.e('Test', 'current-crash');
    final exported = File(await second.exportToFile(directory));
    final content = await exported.readAsString();

    for (var i = 0; i < 3; i++) {
      expect(content, contains('previous-crash-$i'));
    }
    expect(
      content.indexOf('previous-crash-0'),
      lessThan(content.indexOf('previous-crash-1')),
    );
    expect(
      content.indexOf('previous-crash-1'),
      lessThan(content.indexOf('previous-crash-2')),
    );
    expect(content, contains('current-crash'));
    expect(content, contains('current-debug-context'));
    expect(content, contains('token=<redacted>'));
    expect(content, isNot(contains('old-secret')));
    expect(content, isNot(contains('excluded-old-snapshot')));
  });

  test('中文与 emoji 日志按 UTF-8 实际字节轮转', () async {
    final instance = logger(maxBytesPerFile: 512);
    await instance.enableFileSink(overridePath: directory.path);
    for (var i = 0; i < 100; i++) {
      instance.e('Test', '日志$i ${'中文🙂' * 30}');
    }
    await instance.disableFileSink();

    final maxRecordBytes = instance.entries
        .map(
          (entry) => utf8.encode('${entry.format(includeDate: true)}\n').length,
        )
        .reduce((a, b) => a > b ? a : b);
    final files = await directory
        .list()
        .where((entity) => entity is File)
        .toList();
    expect(files.length, lessThanOrEqualTo(3));
    for (final file in files.cast<File>()) {
      expect(await file.length(), lessThanOrEqualTo(512 + maxRecordBytes));
    }
    expect(await current().readAsString(), contains('日志99'));
    expect(instance.droppedWriteLines, 0);
  });

  for (final duringFlush in [false, true]) {
    test('活动文件在${duringFlush ? '刷新期间' : '两批写入之间'}被清理后重开并补写', () async {
      final original = current();
      final replacement = File('${directory.path}/recreated.log');
      final redirected = _RedirectedLogFile(original);
      final parentZone = Zone.current;
      final instance = logger();
      // Windows 不允许删除打开的文件；切换路径解析目标模拟 POSIX unlink：
      // 原 IOSink 继续成功写旧文件，但当前路径已不存在。
      await IOOverrides.runZoned(
        () async {
          await instance.enableFileSink(overridePath: directory.path);
          instance.e('Test', 'before-cleanup');
          await instance.flushFileSink();
          if (duringFlush) {
            redirected.replacementAfterFlush = replacement;
          } else {
            redirected.delegate = replacement;
          }
          instance.e('Test', 'after-cleanup');
          await instance.flushFileSink();
          expect(instance.fileSinkUnavailable, isFalse);
          expect(await replacement.readAsString(), contains('after-cleanup'));
          expect(redirected.openCount, 2);
          await instance.disableFileSink();
        },
        createFile: (path) => p.normalize(path) == p.normalize(original.path)
            ? redirected
            : parentZone.run(() => File(path)),
      );
    });
  }

  test('导出只保留最近五份快照且开关清理保留这些快照', () async {
    for (var i = 1; i <= 6; i++) {
      await File(
        '${directory.path}/bugaoshan-export-$i.log',
      ).writeAsString('old snapshot $i');
    }
    final unrelated = File('${directory.path}/bugaoshan-export-manual.log');
    await unrelated.writeAsString('user named snapshot');
    final instance = logger();
    instance.e('Test', 'current failure');
    final latest = File(await instance.exportToFile(directory));
    expect(await latest.readAsString(), contains('current failure'));
    expect(
      await File('${directory.path}/bugaoshan-export-1.log').exists(),
      isFalse,
    );
    expect(
      await File('${directory.path}/bugaoshan-export-2.log').exists(),
      isFalse,
    );
    final retained = await directory
        .list()
        .where(
          (file) => RegExp(r'bugaoshan-export-\d+\.log$').hasMatch(file.path),
        )
        .toList();
    expect(retained, hasLength(5));
    await instance.deletePersistedFiles(overridePath: directory.path);
    expect(await latest.exists(), isTrue);
    expect(await unrelated.readAsString(), 'user named snapshot');
  });

  test('已有未来时间戳快照也不能使本次导出被清理', () async {
    final future = DateTime.now().microsecondsSinceEpoch + 1000000000;
    for (var i = 0; i < 6; i++) {
      await File(
        '${directory.path}/bugaoshan-export-${future + i}.log',
      ).writeAsString('future');
    }
    final instance = logger();
    instance.e('Test', 'new snapshot');
    final currentExport = File(await instance.exportToFile(directory));
    expect(await currentExport.readAsString(), contains('new snapshot'));
    final snapshots = await directory
        .list()
        .where((file) => file.path.contains('bugaoshan-export-'))
        .toList();
    expect(snapshots, hasLength(5));
  });
}

class _RedirectedLogFile implements File {
  _RedirectedLogFile(File file) : delegate = file, path = file.path;

  File delegate;
  File? replacementAfterFlush;
  int openCount = 0;

  @override
  final String path;

  @override
  Future<bool> exists() => delegate.exists();

  @override
  Future<int> length() => delegate.length();

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    openCount++;
    return _FlushHookSink(
      delegate.openWrite(mode: mode, encoding: encoding),
      () {
        if (replacementAfterFlush case final replacement?) {
          delegate = replacement;
          replacementAfterFlush = null;
        }
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FlushHookSink implements IOSink {
  _FlushHookSink(this._sink, this._afterFlush);

  final IOSink _sink;
  final void Function() _afterFlush;

  @override
  Future<void> get done => _sink.done;

  @override
  void add(List<int> data) => _sink.add(data);

  @override
  void writeln([Object? object = '']) => _sink.writeln(object);

  @override
  Future<void> flush() async {
    await _sink.flush();
    _afterFlush();
  }

  @override
  Future<void> close() => _sink.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
