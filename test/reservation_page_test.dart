import 'package:bugaoshan/app.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/scu_backend/reservation/models/reservation_models.dart';
import 'package:bugaoshan/pages/campus/reservation/reservation_page.dart';
import 'package:bugaoshan/providers/reservation_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_api_service.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('已登录：渲染活动室、时段与可预约状态', (tester) async {
    getIt.registerSingleton<ReservationProvider>(
      ReservationProvider(_FakeReservationApi()),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReservationPage)),
    )!;

    expect(find.text(l10n.reservationTitle), findsOneWidget);
    expect(find.text('党建活动室'), findsWidgets);
    expect(find.text('08:00-12:00'), findsOneWidget);
    expect(find.text(l10n.reservationRemaining(1)), findsOneWidget);
    expect(find.text(l10n.reservationStatusFull), findsWidgets);
    expect(find.text(l10n.reservationGoOfficial), findsOneWidget);
  });

  testWidgets('未登录：显示登录引导，不请求数据', (tester) async {
    final api = _FakeReservationApi();
    getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
    getIt.registerSingleton<ScuAuthProvider>(_LoggedOutAuth());

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReservationPage)),
    )!;
    expect(find.text(l10n.loginRequired), findsOneWidget);
    expect(api.calendarCalls, 0);
  });

  testWidgets('会话失效：显示预约系统会话提示与重试', (tester) async {
    getIt.registerSingleton<ReservationProvider>(
      ReservationProvider(
        _FakeReservationApi(
          error: const UnauthenticatedException('预约系统会话未建立或已过期'),
        ),
      ),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReservationPage)),
    )!;

    expect(find.text(l10n.reservationSessionExpired), findsOneWidget);
    expect(find.text(l10n.goToLogin), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets('无活动室：显示空态文案', (tester) async {
    getIt.registerSingleton<ReservationProvider>(
      ReservationProvider(_FakeReservationApi(resources: const [])),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReservationPage)),
    )!;

    expect(find.text(l10n.reservationNoResources), findsOneWidget);
  });

  testWidgets('切换活动室会重新查询日历', (tester) async {
    final api = _FakeReservationApi();
    getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(api.calendarCalls, 1);

    await tester.tap(find.text('学术交流室'));
    await tester.pumpAndSettle();

    expect(api.calendarCalls, 2);
    expect(api.lastResourceId, '490');
  });

  testWidgets('活动室标签条：右箭头可翻页，左箭头初始禁用', (tester) async {
    getIt.registerSingleton<ReservationProvider>(
      ReservationProvider(_FakeReservationApi(resources: _manyResources())),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());
    _useNarrowScreen(tester);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReservationPage)),
    )!;

    expect(_arrow(tester, l10n.reservationScrollLeft).onPressed, isNull);
    expect(_arrow(tester, l10n.reservationScrollRight).onPressed, isNotNull);

    await tester.tap(_arrowFinder(l10n.reservationScrollRight));
    await tester.pumpAndSettle();

    expect(_arrow(tester, l10n.reservationScrollLeft).onPressed, isNotNull);
  });

  testWidgets('桌面端鼠标拖动可滚动活动室标签条', (tester) async {
    getIt.registerSingleton<ReservationProvider>(
      ReservationProvider(_FakeReservationApi(resources: _manyResources())),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());
    _useNarrowScreen(tester);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ReservationPage)),
    )!;
    expect(_arrow(tester, l10n.reservationScrollLeft).onPressed, isNull);

    // 默认 ScrollBehavior 不含 mouse，这一拖会毫无反应；带上 AppScrollBehavior
    // 之后应能把标签条拖出偏移。
    final strip = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(
      strip,
      const Offset(-220, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(_arrow(tester, l10n.reservationScrollLeft).onPressed, isNotNull);
  });

  group('应用内提交预约', () {
    testWidgets('点选可约时段：出现提交条，再点取消选中', (tester) async {
      final api = _FakeReservationApi();
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      // 初始只有「去官方页面」按钮。
      expect(find.text(l10n.reservationLaunchButton), findsNothing);

      await tester.tap(find.text(l10n.reservationRemaining(1)));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reservationLaunchButton), findsOneWidget);
      expect(find.byTooltip(l10n.reservationClearSelection), findsOneWidget);

      // 再点一次取消选中，回到默认底栏。
      await tester.tap(find.text(l10n.reservationRemaining(1)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reservationGoOfficial), findsOneWidget);
      expect(api.launchCalls, 0);
    });

    testWidgets('超出每日上限：提示且不再加选', (tester) async {
      final api = _FakeReservationApi(allSlotsAvailable: true);
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      // 党建活动室 maxPeriodsPerDay = 2：点满两格后再点第三格被拒。
      await tester.tap(find.text(l10n.reservationRemaining(1)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationRemaining(1)).at(1));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reservationLaunchButton), findsOneWidget);

      await tester.tap(find.text(l10n.reservationRemaining(1)).at(2));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reservationDailyLimitReached(2)), findsOneWidget);

      // 打开确认弹窗核对：仍只有两个时段被选中（5103 与 5104）。
      await tester.tap(find.text(l10n.reservationLaunchButton));
      await tester.pumpAndSettle();
      expect(find.text('10/23 08:00-12:00'), findsOneWidget);
      expect(find.text('10/23 12:00-18:00'), findsOneWidget);
      expect(find.text('10/23 18:00-22:00'), findsNothing);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
    });

    testWidgets('确认弹窗：人数步进后提交成功，清空选择并刷新日历', (tester) async {
      final api = _FakeReservationApi();
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;
      final calendarCallsBefore = api.calendarCalls;

      await tester.tap(find.text(l10n.reservationRemaining(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchButton));
      await tester.pumpAndSettle();

      // 弹窗：默认 1 人，加到 2 人后提交。
      expect(find.text(l10n.reservationLaunchConfirmTitle), findsOneWidget);
      expect(find.text(l10n.reservationPeopleNumber), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchSubmit));
      await tester.pumpAndSettle();

      expect(api.launchCalls, 1);
      expect(api.lastLaunchResourceId, '493');
      expect(api.lastLaunchSlots, hasLength(1));
      expect(api.lastLaunchSlots!.single.periodId, '5104');
      expect(api.lastLaunchNumber, 2);
      expect(find.text(l10n.reservationLaunchSuccess), findsOneWidget);
      // 选择清空、日历刷新。
      expect(find.text(l10n.reservationGoOfficial), findsOneWidget);
      expect(api.calendarCalls, calendarCallsBefore + 1);
    });

    testWidgets('服务端拒绝：SnackBar 显示服务端原文', (tester) async {
      final api = _FakeReservationApi(
        launchError: const ServiceException('请填写预约事由'),
      );
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.text(l10n.reservationRemaining(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchSubmit));
      await tester.pumpAndSettle();

      expect(api.launchCalls, 1);
      expect(find.text('请填写预约事由'), findsOneWidget);
      // 提交失败不清空选择，方便改完直接重试。
      expect(find.text(l10n.reservationLaunchButton), findsOneWidget);
    });

    testWidgets('已有未提交预约单：弹窗引导去官方页面', (tester) async {
      final api = _FakeReservationApi(
        launchError: const ReservationApplyPendingException(),
      );
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.text(l10n.reservationRemaining(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reservationApplyPendingTitle), findsOneWidget);
      expect(find.text(l10n.reservationApplyPendingBody), findsOneWidget);
      // 弹窗里的主按钮（底栏还有一个同名 OutlinedButton）。
      expect(
        find.widgetWithText(FilledButton, l10n.reservationGoOfficial),
        findsOneWidget,
      );
    });

    testWidgets('需审批的资源：提交成功后引导完成申请流程', (tester) async {
      final api = _FakeReservationApi(
        launchResult: const ReservationLaunchResult(
          needsProcess: true,
          processUrl: 'https://service.scu.edu.cn/reservation/fe/process/1',
        ),
      );
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.text(l10n.reservationRemaining(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reservationLaunchProcessTitle), findsOneWidget);
      expect(find.text(l10n.reservationOpenProcess), findsOneWidget);
      // 不真的打开链接：点取消收尾。
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
    });
  });

  group('我的预约', () {
    ReservationAppointment makeAppointment({
      String id = '9001',
      int status = 1,
      bool canCancel = true,
    }) => ReservationAppointment(
      id: id,
      resourceName: '党建活动室',
      createdAt: '2026-10-24 21:00:00',
      status: status,
      canCancel: canCancel,
      details: const [
        ReservationAppointmentDetail(
          id: 'd1',
          date: '2026-10-27',
          timeLabel: '08:00-12:00',
        ),
      ],
    );

    testWidgets('打开弹窗：列出预约单与状态、时段明细', (tester) async {
      final api = _FakeReservationApi(appointments: [makeAppointment()]);
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.byTooltip(l10n.reservationMyAppointments));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reservationMyAppointments), findsOneWidget);
      expect(find.text('党建活动室'), findsWidgets);
      expect(find.text(l10n.reservationStatusReviewing), findsOneWidget);
      expect(find.text('2026-10-27 08:00-12:00'), findsOneWidget);
      // 申请时间（createdAt）也展示。
      expect(find.text('2026-10-24 21:00:00'), findsOneWidget);
      expect(find.text(l10n.reservationCancel), findsOneWidget);
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();
    });

    testWidgets('列表拉取失败：显示错误文案而不是「暂无预约记录」', (tester) async {
      final api = _FakeReservationApi(
        appointmentsError: const ServiceException('预约系统请求失败'),
      );
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.byTooltip(l10n.reservationMyAppointments));
      await tester.pumpAndSettle();

      expect(find.text('预约系统请求失败'), findsOneWidget);
      expect(find.text(l10n.reservationMyAppointmentsEmpty), findsNothing);
    });

    testWidgets('取消预约：确认后调用接口并提示成功', (tester) async {
      final api = _FakeReservationApi(appointments: [makeAppointment()]);
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.byTooltip(l10n.reservationMyAppointments));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationCancel).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.reservationCancelConfirm), findsOneWidget);

      // 确认弹窗里点主按钮（与列表行的取消按钮同名，取 FilledButton）。
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.reservationCancel),
      );
      await tester.pumpAndSettle();

      expect(api.cancelCalls, 1);
      expect(api.lastCancelAppointmentId, '9001');
      expect(find.text(l10n.reservationCancelSuccess), findsOneWidget);
    });

    testWidgets('不可取消的单不显示取消按钮', (tester) async {
      final api = _FakeReservationApi(
        appointments: [makeAppointment(status: 3, canCancel: false)],
      );
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.byTooltip(l10n.reservationMyAppointments));
      await tester.pumpAndSettle();

      expect(find.text(l10n.reservationStatusBooked), findsOneWidget);
      expect(find.text(l10n.reservationCancel), findsNothing);
    });

    testWidgets('人数步进受资源容量限制', (tester) async {
      final api = _FakeReservationApi(
        resources: const [
          ReservationResource(
            id: '493',
            name: '党建活动室',
            attributes: [ReservationAttribute(name: '容量/人数', value: '2')],
            needsApproval: true,
            maxPeriodsPerDay: 2,
            capacity: 2,
          ),
        ],
      );
      getIt.registerSingleton<ReservationProvider>(ReservationProvider(api));
      getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReservationPage)),
      )!;

      await tester.tap(find.text(l10n.reservationRemaining(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.reservationLaunchButton));
      await tester.pumpAndSettle();

      // 容量 2：加到 2 后加号禁用。
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      final plus = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.add_circle_outline,
        ),
      );
      expect(
        plus.onPressed,
        isNull,
        reason: 'plus button must disable at capacity',
      );
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
    });
  });
}

/// 足够多的活动室，保证窄屏下标签条横向溢出。
List<ReservationResource> _manyResources() => [
  for (var i = 0; i < 8; i++)
    ReservationResource(
      id: '$i',
      name: '活动室$i',
      attributes: const [],
      needsApproval: false,
      maxPeriodsPerDay: 0,
    ),
];

void _useNarrowScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _arrowFinder(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == tooltip,
);

IconButton _arrow(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(_arrowFinder(tooltip));

Widget _wrap() => MaterialApp(
  scrollBehavior: const AppScrollBehavior(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const ReservationPage(),
);

class _LoggedInAuth extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => true;

  @override
  bool get isAutoLoggingIn => false;

  @override
  String? get accessToken => 'test-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoggedOutAuth extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => false;

  @override
  bool get isAutoLoggingIn => false;

  @override
  String? get accessToken => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 两间活动室、一天三个时段（含约满与可约）。
class _FakeReservationApi implements ReservationApi {
  _FakeReservationApi({
    this.resources,
    this.error,
    this.launchError,
    this.launchResult,
    this.allSlotsAvailable = false,
    this.appointments = const [],
    this.appointmentsError,
  });

  final List<ReservationResource>? resources;
  final Object? error;
  final Object? launchError;
  final ReservationLaunchResult? launchResult;

  /// true 时三个时段全部「余 1」可约（用于每日上限用例）。
  final bool allSlotsAvailable;

  /// 我的预约列表数据。
  final List<ReservationAppointment> appointments;

  /// 我的预约列表拉取失败时抛出的异常。
  final Object? appointmentsError;

  int calendarCalls = 0;
  String? lastResourceId;

  int launchCalls = 0;
  String? lastLaunchResourceId;
  List<ReservationLaunchSlot>? lastLaunchSlots;
  int? lastLaunchNumber;

  @override
  Future<ReservationLaunchResult> launchReservation({
    required String resourceId,
    required List<ReservationLaunchSlot> slots,
    required int number,
  }) async {
    launchCalls++;
    lastLaunchResourceId = resourceId;
    lastLaunchSlots = List<ReservationLaunchSlot>.of(slots);
    lastLaunchNumber = number;
    final error = launchError;
    if (error != null) throw error;
    return launchResult ??
        const ReservationLaunchResult(needsProcess: false, processUrl: '');
  }

  List<ReservationAppointment> get appointmentRows => appointments;

  @override
  Future<List<ReservationAppointment>> fetchAppointments({
    int type = 0,
    int page = 1,
    int pageSize = 20,
  }) async {
    final error = appointmentsError;
    if (error != null) throw error;
    return appointmentRows;
  }

  int cancelCalls = 0;
  String? lastCancelAppointmentId;

  @override
  Future<void> cancelAppointment({
    required String appointmentId,
    required List<String> detailIds,
  }) async {
    cancelCalls++;
    lastCancelAppointmentId = appointmentId;
  }

  @override
  Future<List<ReservationResource>> fetchResources() async {
    final error = this.error;
    if (error != null) throw error;
    return resources ??
        [
          ReservationResource(
            id: '493',
            name: '党建活动室',
            attributes: const [
              ReservationAttribute(name: '容量/人数', value: '28'),
              ReservationAttribute(name: '校区', value: '望江校区'),
            ],
            needsApproval: true,
            maxPeriodsPerDay: 2,
          ),
          const ReservationResource(
            id: '490',
            name: '学术交流室',
            attributes: [],
            needsApproval: true,
            maxPeriodsPerDay: 2,
          ),
        ];
  }

  @override
  Future<ReservationCalendar> fetchCalendar({
    required String resourceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    calendarCalls++;
    lastResourceId = resourceId;
    if (allSlotsAvailable) {
      return const ReservationCalendar(
        slots: [
          ReservationTimeSlot(
            id: '5103',
            startTime: '08:00:00',
            endTime: '12:00:00',
          ),
          ReservationTimeSlot(
            id: '5104',
            startTime: '12:00:00',
            endTime: '18:00:00',
          ),
          ReservationTimeSlot(
            id: '5105',
            startTime: '18:00:00',
            endTime: '22:00:00',
          ),
        ],
        days: ['2026-10-23'],
        states: {
          '2026-10-23': {
            '5103': ReservationSlotState(
              status: ReservationSlotStatus.available,
              total: 1,
              remaining: 1,
            ),
            '5104': ReservationSlotState(
              status: ReservationSlotStatus.available,
              total: 1,
              remaining: 1,
            ),
            '5105': ReservationSlotState(
              status: ReservationSlotStatus.available,
              total: 1,
              remaining: 1,
            ),
          },
        },
      );
    }
    return ReservationCalendar(
      slots: const [
        ReservationTimeSlot(
          id: '5103',
          startTime: '08:00:00',
          endTime: '12:00:00',
        ),
        ReservationTimeSlot(
          id: '5104',
          startTime: '12:00:00',
          endTime: '18:00:00',
        ),
        ReservationTimeSlot(
          id: '5105',
          startTime: '18:00:00',
          endTime: '22:00:00',
        ),
      ],
      days: const ['2026-10-23'],
      states: {
        '2026-10-23': {
          '5103': const ReservationSlotState(
            status: ReservationSlotStatus.full,
            total: 1,
            remaining: 0,
          ),
          '5104': const ReservationSlotState(
            status: ReservationSlotStatus.available,
            total: 1,
            remaining: 1,
          ),
          '5105': const ReservationSlotState(
            status: ReservationSlotStatus.notOpen,
            total: 0,
            remaining: 0,
          ),
        },
      },
    );
  }
}
