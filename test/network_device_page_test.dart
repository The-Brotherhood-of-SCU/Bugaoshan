import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/network_device/network_device_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/network_device_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/user_info_provider.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 校园网设备查询页的隐私信息开关。
///
/// 历史实现给每个隐私字段都挂了一个眼睛图标，但它们共享同一个
/// `_privacyHidden` 状态，点哪个都是全量切换，属于误导性入口。
/// 现在整张卡片只保留一个开关，位置在姓名行行尾（卡片右上角），
/// 本测试守住这三件事：唯一性、位置、以及一次切换对所有字段同时生效。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const name = '张三';
  const studentId = '202012345678';
  const email = 'zhang@example.com';
  const phone = '13812345678';

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    getIt.registerSingleton<AppConfigProvider>(appConfig);
    getIt.registerSingleton<UserInfoProvider>(_FakeUserInfoProvider());
    getIt.registerSingleton<NetworkDeviceProvider>(
      _FakeNetworkDeviceProvider(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// 登录态属于各用例的前置条件，必须在挂载页面前注册。
  Future<void> pumpPage(WidgetTester tester, {bool loggedIn = true}) async {
    getIt.registerSingleton<ScuAuthProvider>(
      _FakeScuAuthProvider(loggedIn: loggedIn),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const NetworkDevicePage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('隐私开关只有一处，且位于姓名行行尾', (tester) async {
    await pumpPage(tester);

    // 默认隐藏态：整页只有姓名行那一个开关。
    final toggle = find.byIcon(Icons.visibility_off_outlined);
    expect(toggle, findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    // 这一处开关必须挂在「姓名」那一行的 trailing 上，
    // 而不是标题栏或学号/邮箱/手机号行。
    final hostRow = find.ancestor(of: toggle, matching: find.byType(InfoRow));
    expect(hostRow, findsOneWidget);
    expect(tester.widget<InfoRow>(hostRow).label, '姓名');

    // 标题栏只留刷新按钮，隐私开关不在 AppBar 里。
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
    );

    // 四个隐私字段都已掩码，非隐私字段（性别/身份/学院）保持原样。
    expect(find.text('张*'), findsOneWidget);
    expect(find.text('20********78'), findsOneWidget);
    expect(find.text('z${'*' * (email.length - 1)}'), findsOneWidget);
    expect(find.text('138******78'), findsOneWidget);
    expect(find.text(name), findsNothing);
    expect(find.text(email), findsNothing);
  });

  testWidgets('姓名行行尾的开关一次切换即对所有隐私字段生效', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(find.text(name), findsOneWidget);
    expect(find.text(studentId), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    expect(find.text(phone), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // 再点一次回到隐藏态，仍只有一个开关存在。
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.text(name), findsNothing);
    expect(find.text('张*'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('未登录时不渲染隐私开关', (tester) async {
    await pumpPage(tester, loggedIn: false);

    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}

class _FakeScuAuthProvider extends ChangeNotifier implements ScuAuthProvider {
  _FakeScuAuthProvider({this.loggedIn = true});

  final bool loggedIn;

  @override
  bool get isLoggedIn => loggedIn;

  @override
  bool get isAutoLoggingIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserInfoProvider extends ChangeNotifier implements UserInfoProvider {
  @override
  Map<String, dynamic>? get profile => {
    'realname': '张三',
    'sex': '男',
    'email': 'zhang@example.com',
    'mobile': '13812345678',
    'role': {'number': '202012345678', 'identity': '本科生'},
    'departs': {'depart': '计算机学院'},
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNetworkDeviceProvider extends ChangeNotifier
    implements NetworkDeviceProvider {
  @override
  List<Map<String, dynamic>> get devices => const [];

  @override
  NetworkDeviceLoadState get state => NetworkDeviceLoadState.loaded;

  @override
  bool get isOfflining => false;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> ensureDevices() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
