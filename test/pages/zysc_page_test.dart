import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/zysc/zysc_page.dart';
import 'package:bugaoshan/widgets/webview/webview_notice_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _officialUrl = 'https://zysc.scyol.com/fzysc/#/pages/tabbar/index';
const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

Widget _app({Widget home = const ZyscPage()}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, null);
    await getIt.reset();
  });

  testWidgets('iOS opens the official site outside the app on request', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcherChannel, (call) async {
          calls.add(call);
          return true;
        });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(WebViewNoticePage), findsNothing);
    expect(find.text('志愿四川'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    expect(calls.single.arguments['url'], _officialUrl);
    expect(calls.single.arguments['useSafariVC'], isFalse);
    expect(calls.single.arguments['useWebView'], isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final throwsException in [false, true]) {
    testWidgets('iOS launch failure can be retried (throws: $throwsException)', (
      tester,
    ) async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_launcherChannel, (call) async {
            attempts++;
            if (attempts > 1) return true;
            if (throwsException) throw PlatformException(code: 'launch_failed');
            return false;
          });

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('操作失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('Android keeps the existing embedded volunteer page', (
    tester,
  ) async {
    Widget? page;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            page = const ZyscPage().build(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(page, isA<WebViewNoticePage>());
    final webView = page! as WebViewNoticePage;
    expect(webView.url, _officialUrl);
    expect(webView.beautifyAsset, 'assets/js/volunteer_sichuan.js');
    expect(webView.enableLoadingMask, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
