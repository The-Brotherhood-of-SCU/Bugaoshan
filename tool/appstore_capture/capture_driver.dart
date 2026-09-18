import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final simulator = Platform.environment['SCREENSHOT_SIMULATOR_ID'];
  final output = Platform.environment['SCREENSHOT_OUTPUT'];
  if (simulator == null || output == null) {
    throw StateError('SCREENSHOT_SIMULATOR_ID and SCREENSHOT_OUTPUT required');
  }
  final directory = Directory(output)..createSync(recursive: true);
  final driver = await FlutterDriver.connect(
    timeout: const Duration(minutes: 2),
  );

  Future<void> capture(String name) async {
    // Allow real layout, animation and rasterization to settle before capture.
    await Future<void>.delayed(const Duration(seconds: 2));
    final path = '${directory.path}/$name.png';
    final result = await Process.run('xcrun', [
      'simctl',
      'io',
      simulator,
      'screenshot',
      '--type=png',
      path,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Native screenshot failed: ${result.stderr}');
    }
    stdout.writeln('Captured $path');
  }

  try {
    // The driver connects before async database seeding and production startup
    // finish. This command explicitly permits running before runApp().
    await driver.waitForCondition(
      const FirstFrameRasterized(),
      timeout: const Duration(minutes: 2),
    );
    await driver.runUnsynchronized(() async {
      await driver.waitFor(
        find.byType('CoursePageTopBar'),
        timeout: const Duration(minutes: 2),
      );
      await capture('01-course-schedule');

      // Tap existing navigation labels; never substitute or render mock pages.
      await driver.tap(find.text('校园'));
      await driver.waitFor(find.byType('CampusPage'));
      await capture('02-campus-tools');

      await driver.tap(find.text('我的'));
      await driver.waitFor(find.byType('ProfileMenuCard'));
      await driver.tap(find.text('课表设置'));
      await driver.waitFor(find.byType('CourseScheduleSetting'));
      await driver.waitFor(find.text('学期配置'));
      await capture('03-schedule-settings');
    });
  } catch (_) {
    await capture('failure-current-screen');
    rethrow;
  } finally {
    await driver.close();
  }
}
