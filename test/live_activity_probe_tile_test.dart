import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/live_activity_probe_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [LiveActivityProbeTile] 的启动参数与异常文案映射测试。
///
/// 探针跳过「当前必须有课」这一业务前提，直接验证原生投递与系统渲染。
/// 对应地，测试只覆盖两点：下发给原生通道的参数是否正确，以及平台异常是否被
/// 转换为可操作的提示文案，而非透出 PlatformException 原文。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'bugaoshan/live_activity';
  late List<MethodCall> log;

  /// 安装通道桩。[isSupported] 决定 `isSupported` 的返回值，
  /// [startError] 非空时 `start` 抛出该平台异常。
  void installChannel({
    bool isSupported = true,
    PlatformException? startError,
  }) {
    log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), (
          MethodCall call,
        ) async {
          log.add(call);
          switch (call.method) {
            case 'isSupported':
              return isSupported;
            case 'start':
              if (startError != null) throw startError;
              return 'probe-activity-id';
            case 'end':
              return null;
            default:
              return null;
          }
        });
  }

  /// 以 iOS 平台标识运行 [body]。
  ///
  /// 覆盖值必须在测试体内部复位：`testWidgets` 在测试体结束后、tearDown 之前
  /// 校验 foundation 调试变量，留到 tearDown 复位会直接判失败。
  Future<void> asIos(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // 固定中文断言文案：默认 locale 会随宿主环境变化，断言不能依赖它。
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: LiveActivityProbeTile()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 取与断言相关的通道调用序列。
  ///
  /// `isSupported` 会在启动/结束后各刷新一次（用于同步状态行），与调用顺序无关，
  /// 从序列中剔除以免断言被这些刷新噪声干扰。
  List<String> relevantCalls() =>
      log.map((c) => c.method).where((m) => m != 'isSupported').toList();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), null);
  });

  testWidgets('点「立即触发示例」会先结束既有会话再启动示例', (tester) async {
    installChannel();

    await asIos(() async {
      await pumpTile(tester);
      await tester.tap(find.text('立即触发示例'));
      await tester.pumpAndSettle();
    });

    // 顺序约束：原生 update 是增量合并语义，不先结束会让新会话继承上一次的课程内容。
    expect(relevantCalls(), ['end', 'start']);

    // 不能取 log.last：启动后的状态行刷新会再补一次 isSupported。
    final startArgs =
        log.firstWhere((c) => c.method == 'start').arguments
            as Map<Object?, Object?>;
    expect(startArgs['courseName'], '示例课程');
    expect(startArgs['location'], '综C407');
    expect(startArgs['nextCourseName'], '线性代数');
    expect(startArgs['startAtMillis'], isA<int>());
    expect(startArgs['endAtMillis'], isA<int>());

    // 示例会话时长固定 30 分钟，倒计时有可预期的终点。
    final span =
        (startArgs['endAtMillis']! as int) -
        (startArgs['startAtMillis']! as int);
    expect(span, const Duration(minutes: 30).inMilliseconds);
  });

  testWidgets('「立即结束」会调用 end 通道', (tester) async {
    installChannel();

    await asIos(() async {
      await pumpTile(tester);
      await tester.tap(find.text('立即结束'));
      await tester.pumpAndSettle();
    });

    expect(relevantCalls(), ['end']);
  });

  testWidgets('非前台时把 NOT_IN_FOREGROUND 翻译成可操作提示', (tester) async {
    installChannel(startError: PlatformException(code: 'NOT_IN_FOREGROUND'));

    await asIos(() async {
      await pumpTile(tester);
      await tester.tap(find.text('立即触发示例'));
      await tester.pumpAndSettle();
    });

    expect(find.text('实时活动只能在应用处于前台时启动。'), findsOneWidget);
  });

  testWidgets('权限被关时提示去系统设置，而不是抛 PlatformException 原文', (tester) async {
    installChannel(startError: PlatformException(code: 'NOT_AUTHORIZED'));

    await asIos(() async {
      await pumpTile(tester);
      await tester.tap(find.text('立即触发示例'));
      await tester.pumpAndSettle();
    });

    expect(find.text('系统设置中未开启实时活动。'), findsOneWidget);
  });

  testWidgets('不支持时禁用启动按钮并说明原因', (tester) async {
    installChannel(isSupported: false);

    await asIos(() async {
      await pumpTile(tester);

      expect(find.text('不支持 / 未开启'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      // 未支持时不应下发任何启动调用。
      expect(relevantCalls(), isEmpty);
    });
  });
}
