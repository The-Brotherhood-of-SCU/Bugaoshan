import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/utils/log_persistence.dart';

void main() {
  late Directory directory;
  late AppLogger logger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    directory = await Directory.systemTemp.createTemp('bugaoshan_bootstrap');
    logger = AppLogger();
  });

  tearDown(() async {
    await logger.disableFileSink();
    logger.dispose();
    await getIt.reset();
    await directory.delete(recursive: true);
  });

  test('未挂载应用界面时启动警告与后续启动失败仍可在重启后导出', () async {
    logger.i('Main', 'early-info');
    logger.w('Main', 'early-warning');
    final preferences = await SharedPreferences.getInstance();
    await initializeLogPersistence(
      preferences: preferences,
      logger: logger,
      overridePath: directory.path,
    );
    // DI 沿用已初始化的启动日志器；启动失败无需 MyApp 的设置监听器。
    getIt.registerSingleton<AppLogger>(logger);
    AppLog.e('Main', 'startup-failure', error: StateError('boot failed'));
    await logger.flushFileSink();
    expect(logger.fileSinkEnabled, isTrue);
    expect(logger.fileSinkUnavailable, isFalse);

    // 重复应用当前设置不能再次补写已写入的启动缓冲。
    await initializeLogPersistence(
      preferences: preferences,
      logger: logger,
      overridePath: directory.path,
    );
    await logger.disableFileSink();
    final restarted = AppLogger();
    addTearDown(restarted.dispose);
    final snapshot = File(await restarted.exportToFile(directory));
    final content = await snapshot.readAsString();
    expect('early-warning'.allMatches(content), hasLength(1));
    expect(content, contains('startup-failure'));
    expect(content, contains('boot failed'));
    expect(content, isNot(contains('early-info')));
  });

  test('用户已关闭落盘时启动失败只保留在内存并清除旧自动日志', () async {
    SharedPreferences.setMockInitialValues({'log_persistence_enabled': false});
    final current = File('${directory.path}/bugaoshan.log');
    await current.writeAsString('old automatic log');
    final snapshot = File('${directory.path}/bugaoshan-export-old.log');
    await snapshot.writeAsString('manual snapshot');
    logger.w('Main', 'early-warning');
    await initializeLogPersistence(
      preferences: await SharedPreferences.getInstance(),
      logger: logger,
      overridePath: directory.path,
    );
    logger.e('Main', 'startup-failure');
    await logger.flushFileSink();
    expect(logger.fileSinkEnabled, isFalse);
    expect(await current.exists(), isFalse);
    expect(await snapshot.readAsString(), 'manual snapshot');
    expect(logger.entries.last.message, 'startup-failure');
  });

  test('无法读取开关时不猜测用户意图或写入启动缓冲', () async {
    SharedPreferences.setMockInitialValues({'log_persistence_enabled': 'bad'});
    await initializeLogPersistence(
      preferences: await SharedPreferences.getInstance(),
      logger: logger,
      overridePath: directory.path,
    );
    expect(logger.fileSinkEnabled, isFalse);
    expect(await directory.list().isEmpty, isTrue);
    expect(logger.entries.single.message, '初始化日志落盘失败');
    expect(logger.entries.single.stackTrace, isNotEmpty);
  });

  test('正常重新开启不会补写用户关闭期间的日志', () async {
    logger.e('Main', 'while-disabled');
    await logger.enableFileSink(overridePath: directory.path);
    logger.e('Main', 'after-enabling');
    await logger.flushFileSink();
    final content = await File(
      '${directory.path}/bugaoshan.log',
    ).readAsString();
    expect(content, isNot(contains('while-disabled')));
    expect(content, contains('after-enabling'));
  });
}
