import 'package:bugaoshan/pages/campus/reservation/models/reservation_models.dart';
import 'package:bugaoshan/providers/reservation_provider.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_api_service.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReservationProvider', () {
    test('refresh：拉资源并默认选中第一个，再查日历', () async {
      final api = _FakeReservationApi(
        resources: [_resource('493', '党建活动室'), _resource('490', '学术交流室')],
      );
      final provider = ReservationProvider(api);

      await provider.refresh();

      expect(provider.state, ReservationLoadState.loaded);
      expect(provider.resources, hasLength(2));
      expect(provider.selectedResourceId, '493');
      expect(provider.selectedResource?.name, '党建活动室');
      expect(provider.calendar, isNotNull);
      expect(api.calendarCalls, 1);
      expect(api.lastResourceId, '493');
      // 默认区间为今天起 7 天。
      expect(api.lastStart, isNotNull);
      expect(api.lastEnd!.difference(api.lastStart!).inDays, 6);
    });

    test('selectResource：切换资源并重新查日历', () async {
      final api = _FakeReservationApi(
        resources: [_resource('493', '党建活动室'), _resource('490', '学术交流室')],
      );
      final provider = ReservationProvider(api);
      await provider.refresh();

      await provider.selectResource('490');

      expect(provider.selectedResourceId, '490');
      expect(provider.selectedResource?.name, '学术交流室');
      expect(api.calendarCalls, 2);
      expect(api.lastResourceId, '490');
    });

    test('重复选中同一资源不重复请求', () async {
      final api = _FakeReservationApi(resources: [_resource('493', '党建活动室')]);
      final provider = ReservationProvider(api);
      await provider.refresh();

      await provider.selectResource('493');

      expect(api.calendarCalls, 1);
    });

    test('shiftRange：区间整体前后平移 7 天', () async {
      final api = _FakeReservationApi(resources: [_resource('493', '党建活动室')]);
      final provider = ReservationProvider(api);
      await provider.refresh();
      final originalStart = provider.rangeStart;

      await provider.shiftRange(7);
      expect(provider.rangeStart.difference(originalStart).inDays, 7);
      expect(api.calendarCalls, 2);

      await provider.shiftRange(-7);
      expect(provider.rangeStart, originalStart);
      expect(api.calendarCalls, 3);
    });

    test('shiftRange：不允许翻到今天之前', () async {
      final api = _FakeReservationApi(resources: [_resource('493', '党建活动室')]);
      final provider = ReservationProvider(api);
      await provider.refresh();
      final today = provider.rangeStart;

      await provider.shiftRange(-7);

      expect(provider.rangeStart, today);
      // 已经在今天这一屏，无需重复请求。
      expect(api.calendarCalls, 1);
      expect(provider.isAtTodayRange, isTrue);
    });

    test('shiftRange：从下一屏往回翻会夹到今天而不是更早', () async {
      final api = _FakeReservationApi(resources: [_resource('493', '党建活动室')]);
      final provider = ReservationProvider(api);
      await provider.refresh();
      final today = provider.rangeStart;

      await provider.shiftRange(7);
      expect(provider.isAtTodayRange, isFalse);

      await provider.shiftRange(-7);
      expect(provider.rangeStart, today);
      expect(provider.isAtTodayRange, isTrue);
    });

    test('resetRange：翻走后可回到今天，已在今天时不重复请求', () async {
      final api = _FakeReservationApi(resources: [_resource('493', '党建活动室')]);
      final provider = ReservationProvider(api);
      await provider.refresh();
      final today = provider.rangeStart;

      await provider.resetRange();
      expect(provider.rangeStart, today);
      expect(api.calendarCalls, 1);

      await provider.shiftRange(14);
      expect(provider.isAtTodayRange, isFalse);

      await provider.resetRange();
      expect(provider.rangeStart, today);
      expect(provider.isAtTodayRange, isTrue);
      expect(api.calendarCalls, 3);
    });

    test('ensureRangeNotPast：区间已在今天或之后时不动', () async {
      final api = _FakeReservationApi(resources: [_resource('493', '党建活动室')]);
      final provider = ReservationProvider(api);
      await provider.refresh();
      final today = provider.rangeStart;

      await provider.ensureRangeNotPast();
      expect(provider.rangeStart, today);
      expect(api.calendarCalls, 1);

      await provider.shiftRange(7);
      final shifted = provider.rangeStart;
      await provider.ensureRangeNotPast();
      expect(provider.rangeStart, shifted);
      expect(api.calendarCalls, 2);
    });

    test('资源列表为空：loaded 且不查日历', () async {
      final api = _FakeReservationApi(resources: const []);
      final provider = ReservationProvider(api);

      await provider.refresh();

      expect(provider.state, ReservationLoadState.loaded);
      expect(provider.resources, isEmpty);
      expect(provider.selectedResourceId, isNull);
      expect(provider.calendar, isNull);
      expect(api.calendarCalls, 0);
    });

    test('会话失效：unauthenticated，不抛未捕获异常', () async {
      final api = _FakeReservationApi(
        resources: const [],
        error: const UnauthenticatedException('预约系统会话未建立或已过期'),
      );
      final provider = ReservationProvider(api);

      await provider.refresh();

      expect(provider.state, ReservationLoadState.error);
      expect(provider.errorKind, ReservationErrorKind.unauthenticated);
      expect(provider.errorMessage, isNull);
    });

    test('接口异常：failed 且带服务端原文', () async {
      final api = _FakeReservationApi(
        resources: const [],
        error: const ServiceException('资源不存在'),
      );
      final provider = ReservationProvider(api);

      await provider.refresh();

      expect(provider.state, ReservationLoadState.error);
      expect(provider.errorKind, ReservationErrorKind.failed);
      expect(provider.errorMessage, '资源不存在');
    });

    test('日历失败：failed 且保留已加载的资源列表', () async {
      final api = _FakeReservationApi(
        resources: [_resource('493', '党建活动室')],
        calendarError: const ServiceException('系统错误'),
      );
      final provider = ReservationProvider(api);

      await provider.refresh();

      expect(provider.resources, hasLength(1));
      expect(provider.state, ReservationLoadState.error);
      expect(provider.errorKind, ReservationErrorKind.failed);
      expect(provider.errorMessage, '系统错误');
    });

    test('clear 复位全部状态', () async {
      final api = _FakeReservationApi(resources: [_resource('493', '党建活动室')]);
      final provider = ReservationProvider(api);
      await provider.refresh();

      provider.clear();

      expect(provider.state, ReservationLoadState.idle);
      expect(provider.resources, isEmpty);
      expect(provider.selectedResourceId, isNull);
      expect(provider.calendar, isNull);
    });

    group('launchReservation', () {
      test('成功：参数透传给 API，结果返回且日历刷新', () async {
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
        );
        final provider = ReservationProvider(api);
        await provider.refresh();
        final calendarCallsBefore = api.calendarCalls;

        final result = await provider.launchReservation(
          slots: const [
            ReservationLaunchSlot(date: '2026-10-24', periodId: '5103'),
          ],
          number: 2,
        );

        expect(result.needsProcess, isFalse);
        expect(api.launchCalls, 1);
        expect(api.lastLaunchResourceId, '493');
        expect(api.lastLaunchSlots, hasLength(1));
        expect(api.lastLaunchSlots!.single.date, '2026-10-24');
        expect(api.lastLaunchSlots!.single.periodId, '5103');
        expect(api.lastLaunchNumber, 2);
        // 提交后日历刷新了一次。
        expect(api.calendarCalls, calendarCallsBefore + 1);
      });

      test('成功（需审批）：is_relate 与流程地址透传', () async {
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          launchResult: const ReservationLaunchResult(
            needsProcess: true,
            processUrl: 'https://service.scu.edu.cn/reservation/fe/process/1',
          ),
        );
        final provider = ReservationProvider(api);
        await provider.refresh();

        final result = await provider.launchReservation(
          slots: const [
            ReservationLaunchSlot(date: '2026-10-24', periodId: '5103'),
          ],
          number: 1,
        );

        expect(result.needsProcess, isTrue);
        expect(
          result.processUrl,
          'https://service.scu.edu.cn/reservation/fe/process/1',
        );
      });

      test('已有未提交预约单：原样抛出 APPLY 异常', () async {
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          launchError: const ReservationApplyPendingException(),
        );
        final provider = ReservationProvider(api);
        await provider.refresh();

        await expectLater(
          provider.launchReservation(
            slots: const [
              ReservationLaunchSlot(date: '2026-10-24', periodId: '5103'),
            ],
            number: 1,
          ),
          throwsA(isA<ReservationApplyPendingException>()),
        );
      });

      test('服务端拒绝：原样抛 ServiceException', () async {
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          launchError: const ServiceException('请填写预约事由'),
        );
        final provider = ReservationProvider(api);
        await provider.refresh();

        await expectLater(
          provider.launchReservation(
            slots: const [
              ReservationLaunchSlot(date: '2026-10-24', periodId: '5103'),
            ],
            number: 1,
          ),
          throwsA(
            isA<ServiceException>().having(
              (e) => e.message,
              'message',
              '请填写预约事由',
            ),
          ),
        );
      });
    });

    group('我的预约', () {
      test('loadAppointments：透传 API 结果', () async {
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          appointments: [
            ReservationAppointment(
              id: '9001',
              resourceName: '党建活动室',
              createdAt: '2026-10-24 21:00',
              status: 1,
              canCancel: true,
              details: const [
                ReservationAppointmentDetail(
                  id: 'd1',
                  date: '2026-10-27',
                  timeLabel: '08:00-12:00',
                ),
              ],
            ),
          ],
        );
        final provider = ReservationProvider(api);
        await provider.refresh();

        await provider.loadAppointments();

        expect(api.listCalls, 1);
        expect(provider.appointments, hasLength(1));
        expect(provider.appointments.single.resourceName, '党建活动室');
        expect(provider.appointmentsLoading, isFalse);
      });

      test('loadAppointments：失败不抛出，错误入状态（不再静默成空列表）', () async {
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          listError: const ServiceException('预约系统请求失败'),
        );
        final provider = ReservationProvider(api);
        await provider.refresh();

        await provider.loadAppointments();

        expect(provider.appointmentsError, '预约系统请求失败');
        expect(provider.appointments, isEmpty);
        expect(provider.appointmentsLoading, isFalse);
      });

      test('loadAppointments：超过一页时自动翻页合并', () async {
        ReservationAppointment row(int i) => ReservationAppointment(
          id: '$i',
          resourceName: '活动室$i',
          createdAt: '',
          status: 3,
          canCancel: false,
          details: const [],
        );
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          pagesOf: {
            1: [for (var i = 0; i < 20; i++) row(i)],
            2: [row(20), row(21), row(22)],
          },
        );
        final provider = ReservationProvider(api);
        await provider.refresh();

        await provider.loadAppointments();

        expect(api.listPages, [1, 2]);
        expect(provider.appointments, hasLength(23));
      });

      test('cancelAppointment：传整单全部明细 id，成功后刷新列表与日历', () async {
        final appointment = ReservationAppointment(
          id: '9001',
          resourceName: '党建活动室',
          createdAt: '2026-10-24 21:00',
          status: 1,
          canCancel: true,
          details: const [
            ReservationAppointmentDetail(
              id: 'd1',
              date: '2026-10-27',
              timeLabel: '08:00-12:00',
            ),
            ReservationAppointmentDetail(
              id: 'd2',
              date: '2026-10-27',
              timeLabel: '12:00-18:00',
            ),
          ],
        );
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          appointments: [appointment],
        );
        final provider = ReservationProvider(api);
        await provider.refresh();
        await provider.loadAppointments();
        final calendarCallsBefore = api.calendarCalls;

        await provider.cancelAppointment(appointment);

        expect(api.cancelCalls, 1);
        expect(api.lastCancelAppointmentId, '9001');
        expect(api.lastCancelDetailIds, ['d1', 'd2']);
        expect(api.calendarCalls, calendarCallsBefore + 1);
        expect(api.listCalls, 2);
      });

      test('cancelAppointment：服务端拒绝时原样抛出', () async {
        final appointment = ReservationAppointment(
          id: '9001',
          resourceName: '党建活动室',
          createdAt: '2026-10-24 21:00',
          status: 3,
          canCancel: true,
          details: const [
            ReservationAppointmentDetail(
              id: 'd1',
              date: '2026-10-27',
              timeLabel: '08:00-12:00',
            ),
          ],
        );
        final api = _FakeReservationApi(
          resources: [_resource('493', '党建活动室')],
          appointments: [appointment],
          cancelError: const ServiceException('该预约不可取消'),
        );
        final provider = ReservationProvider(api);
        await provider.refresh();

        await expectLater(
          provider.cancelAppointment(appointment),
          throwsA(
            isA<ServiceException>().having((e) => e.message, 'message', '该预约不可取消'),
          ),
        );
      });
    });
  });
}

ReservationResource _resource(String id, String name) => ReservationResource(
  id: id,
  name: name,
  attributes: const [],
  needsApproval: true,
  maxPeriodsPerDay: 2,
);

/// 可编排的假 API：记录调用参数，按需抛错。
class _FakeReservationApi implements ReservationApi {
  _FakeReservationApi({
    required this.resources,
    this.error,
    this.calendarError,
    this.launchError,
    this.launchResult,
    this.appointments = const [],
    this.cancelError,
    this.listError,
    this.pagesOf = const {},
  });

  final List<ReservationResource> resources;
  final Object? error;
  final Object? calendarError;
  final Object? launchError;
  final ReservationLaunchResult? launchResult;
  final List<ReservationAppointment> appointments;
  final Object? cancelError;
  final Object? listError;

  /// 按页码编排的多页数据（page -> 行）；配置后优先于 [appointments]。
  final Map<int, List<ReservationAppointment>> pagesOf;

  int calendarCalls = 0;
  String? lastResourceId;
  DateTime? lastStart;
  DateTime? lastEnd;

  int launchCalls = 0;
  String? lastLaunchResourceId;
  List<ReservationLaunchSlot>? lastLaunchSlots;
  int? lastLaunchNumber;

  @override
  Future<List<ReservationResource>> fetchResources() async {
    final error = this.error;
    if (error != null) throw error;
    return resources;
  }


  @override
  Future<ReservationCalendar> fetchCalendar({
    required String resourceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    calendarCalls++;
    lastResourceId = resourceId;
    lastStart = startDate;
    lastEnd = endDate;
    final error = calendarError;
    if (error != null) throw error;
    return ReservationCalendar(
      slots: const [
        ReservationTimeSlot(
          id: '5103',
          startTime: '08:00:00',
          endTime: '12:00:00',
        ),
      ],
      days: const ['2026-10-23'],
      states: {
        '2026-10-23': {
          '5103': const ReservationSlotState(
            status: ReservationSlotStatus.available,
            total: 1,
            remaining: 1,
          ),
        },
      },
    );
  }

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

  int listCalls = 0;
  List<int> listPages = [];

  @override
  Future<List<ReservationAppointment>> fetchAppointments({
    int type = 0,
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls++;
    listPages.add(page);
    final error = listError;
    if (error != null) throw error;
    // 未配置分页数据时单页返回（不足一页即终止翻页）。
    return pagesOf[page] ?? appointments;
  }

  int cancelCalls = 0;
  String? lastCancelAppointmentId;
  List<String>? lastCancelDetailIds;

  @override
  Future<void> cancelAppointment({
    required String appointmentId,
    required List<String> detailIds,
  }) async {
    cancelCalls++;
    lastCancelAppointmentId = appointmentId;
    lastCancelDetailIds = List<String>.of(detailIds);
    final error = cancelError;
    if (error != null) throw error;
  }
}
