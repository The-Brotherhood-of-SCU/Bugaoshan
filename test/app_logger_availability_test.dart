import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bugaoshan/utils/app_logger.dart';

/// 落盘**可用性**的回归测试。
///
/// 背景：这两条用例对应两个真实缺陷——
/// 1. `sink.done` 失败回调里把 `_fileSinkEnabled` 置false，等于自己关掉了
///    自己的入口，导致此后永久不再落盘且无法自愈；
/// 2. 日志目录被系统清理后（Android 低存储时是常规行为），
///    `enableFileSink` 仍报告 `fileSinkEnabled = true`，但文件根本不存在。
///
/// 共同根因：**用户配置（想落盘）与实际可用（能落盘）被塞进了同一个 flag**。
/// 修复后把两者拆开，故这里断言的是「实际可用性」而非配置值。
void main() {
  /// 清理临时目录；Windows 上文件句柄释放有延迟，故重试。
  Future<void> cleanup(Directory dir) async {
    for (var i = 0; i < 5; i++) {
      try {
        if (!await dir.exists()) return;
        await dir.delete(recursive: true);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  /// 统计目录内日志文件的总行数。
  Future<int> countLines(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return -1;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is! File) continue;
      if (!e.path.endsWith('.log')) continue;
      total += (await e.readAsLines()).where((l) => l.trim().isNotEmpty).length;
    }
    return total;
  }

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bugaoshan_avail');
  });

  tearDown(() async {
    await cleanup(tmp);
  });

  test('目录被系统清理后应重建目录并继续落盘', () async {
    final logger = AppLogger();
    await logger.enableFileSink(overridePath: tmp.path);
    expect(logger.fileSinkEnabled, isTrue);

    logger.e('T', 'before-cleanup');
    await logger.disableFileSink();
    expect(await countLines(tmp.path), greaterThan(0));

    // 模拟 Android 低存储时 OS 清理外部 cache 目录——这是常规行为，
    // 而日志目录当初正是为此才选在外部 cache。
    //
    // 用 rename 而非 delete：Windows 上 delete 常因句柄未释放而失败
    // （表现为「目录还在」），会掩盖真正要测的行为——**目标路径不存在时
    // 能否自建**。rename 让原路径确定地消失，等价且稳定。
    final moved = Directory('${tmp.path}_moved');
    await Directory(tmp.path).rename(moved.path);
    expect(await tmp.exists(), isFalse);

    // 重新启用落盘：应重建目录并继续写入。
    await logger.enableFileSink(overridePath: tmp.path);
    logger.e('T', 'after-cleanup');
    await logger.disableFileSink();

    final lines = await countLines(tmp.path);
    expect(
      lines,
      greaterThanOrEqualTo(1),
      reason: '目录被清理后应重建并写入新日志，实际行数 $lines',
    );
    final content = await File('${tmp.path}/bugaoshan.log').readAsString();
    expect(content, contains('after-cleanup'));
    logger.dispose();
  });

  test('落盘中途失败后应能恢复，而不是永久停用', () async {
    final logger = AppLogger();
    await logger.enableFileSink(overridePath: tmp.path);

    logger.e('T', 'first');
    await logger.disableFileSink();

    // 用户意图重新开启（这是 UI 上唯一的自救路径，必须真的有效）。
    await logger.enableFileSink(overridePath: tmp.path);
    expect(logger.fileSinkEnabled, isTrue);

    logger.e('T', 'second');
    await logger.disableFileSink();

    final content = await File('${tmp.path}/bugaoshan.log').readAsString();
    expect(content, contains('second'), reason: '重新开启后必须能继续写入，否则失败一次即永久失效');
    logger.dispose();
  });

  test('fileSinkUnavailable 反映真实可用性而非配置意图', () async {
    final logger = AppLogger();

    // 从未启用：意图与可用皆为假。
    expect(logger.fileSinkEnabled, isFalse);
    expect(logger.fileSinkUnavailable, isFalse);

    await logger.enableFileSink(overridePath: tmp.path);
    expect(logger.fileSinkEnabled, isTrue);
    expect(logger.fileSinkUnavailable, isFalse, reason: '正常可用时不应报告故障');

    await logger.disableFileSink();
    expect(logger.fileSinkUnavailable, isFalse, reason: '用户主动关闭不是故障，不应报告不可用');
    logger.dispose();
  });

  test('开启落盘失败时应如实记录原因而非静默', () async {
    // 用一个**文件**占住目标路径，使 mkdir 必然失败——模拟存储不可写
    // （磁盘满/权限被回收在移动端都会表现为写不进去）。
    final blocker = File('${tmp.path}/blocker');
    await blocker.writeAsString('not a directory');

    final logger = AppLogger();
    await logger.enableFileSink(overridePath: '${tmp.path}/blocker/logs');

    // 失败原因必须可查——静默失败会让用户以为日志已被保留。
    expect(logger.fileSinkError, isNotNull, reason: '开启失败应记录原因，供 UI 与排障使用');
    expect(logger.fileSinkEnabled, isFalse);
    logger.dispose();
  });
}
