import 'package:bugaoshan/pages/campus/reservation/models/reservation_models.dart';
import 'package:bugaoshan/scu_backend/reservation/reservation_api_service.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:flutter/foundation.dart';

/// 预约页加载状态。
enum ReservationLoadState { idle, loading, loaded, error }

/// 预约页失败原因，决定错误态文案与动作。
enum ReservationErrorKind {
  /// 统一认证未登录，或预约系统会话未建立（自愈重试后仍失败）。
  unauthenticated,

  /// 网络 / 接口 / 解析等其它错误。
  failed,
}

/// 预约系统页面状态（资源列表 + 选中资源的日历）。
///
/// 数据链：`ReservationApiService.fetchResources`（专题资源）→
/// 选中资源后 `fetchCalendar`（未来 7 天 × 时段）。只读，不提交预约。
class ReservationProvider extends ChangeNotifier {
  static const String _tag = 'ReservationProvider';

  /// 一次展示的天数（服务端接受任意区间，7 天刚好一屏）。
  static const int visibleDays = 7;

  ReservationProvider(this._api);

  final ReservationApi _api;

  ReservationLoadState _state = ReservationLoadState.idle;
  ReservationErrorKind? _errorKind;
  String? _errorMessage;

  List<ReservationResource> _resources = const [];
  String? _selectedResourceId;
  ReservationCalendar? _calendar;

  /// 日历查询区间的第一天（默认今天）。
  DateTime _rangeStart = _dateOnly(DateTime.now());

  ReservationLoadState get state => _state;
  ReservationErrorKind? get errorKind => _errorKind;
  String? get errorMessage => _errorMessage;

  List<ReservationResource> get resources => List.unmodifiable(_resources);
  String? get selectedResourceId => _selectedResourceId;
  ReservationCalendar? get calendar => _calendar;
  DateTime get rangeStart => _rangeStart;

  ReservationResource? get selectedResource {
    final id = _selectedResourceId;
    if (id == null) return null;
    for (final resource in _resources) {
      if (resource.id == id) return resource;
    }
    return null;
  }

  /// 首次进入：拉资源列表，并默认选中第一个资源查日历。
  Future<void> ensureLoaded() async {
    if (_state == ReservationLoadState.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_state == ReservationLoadState.loading) return;
    _state = ReservationLoadState.loading;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final resources = await _api.fetchResources();
      if (_state != ReservationLoadState.loading) return;
      _resources = resources;
      final selected = _selectedResourceId ?? resources.firstOrNull?.id;
      _selectedResourceId = selected;
      _state = ReservationLoadState.loaded;
      notifyListeners();

      if (selected != null) {
        await _loadCalendar(selected);
      }
    } on UnauthenticatedException {
      if (_state != ReservationLoadState.loading) return;
      _state = ReservationLoadState.error;
      _errorKind = ReservationErrorKind.unauthenticated;
      notifyListeners();
    } catch (e, logStackTrace) {
      if (_state != ReservationLoadState.loading) return;
      AppLog.e(_tag, 'refresh 失败', error: e, stackTrace: logStackTrace);
      _state = ReservationLoadState.error;
      _errorKind = ReservationErrorKind.failed;
      _errorMessage = e is ServiceException ? e.message : null;
      notifyListeners();
    }
  }

  /// 切换选中资源并重新查日历。
  Future<void> selectResource(String resourceId) async {
    if (_selectedResourceId == resourceId && _calendar != null) return;
    _selectedResourceId = resourceId;
    _calendar = null;
    notifyListeners();
    await _loadCalendar(resourceId);
  }

  /// 日历区间前移 / 后移 [visibleDays] 天。
  ///
  /// 不允许翻到「今天」之前：服务端对过去日期只会返回「已过期」，
  /// 翻过去是纯噪音，还会让「回到今天」失去意义。
  Future<void> shiftRange(int days) async {
    final resourceId = _selectedResourceId;
    if (resourceId == null) return;

    final today = _dateOnly(DateTime.now());
    final next = _rangeStart.add(Duration(days: days));
    if (next.isBefore(today)) {
      if (_rangeStart.isAtSameMomentAs(today)) return;
      _rangeStart = today;
    } else {
      _rangeStart = next;
    }
    _calendar = null;
    notifyListeners();
    await _loadCalendar(resourceId);
  }

  /// 区间是否已经在「今天」这一屏（用于禁用「回到今天」按钮）。
  ///
  /// 每次读取都重新取当天日期：页面跨过午夜后，原来的「今天」会变成
  /// 昨天，这里会返回 false，「回到今天」随之可用。
  bool get isAtTodayRange => _rangeStart.isAtSameMomentAs(_dateOnly(DateTime.now()));

  /// 页面回到前台时调用：若区间起点已早于今天（典型场景是页面跨夜挂着），
  /// 把它夹回今天并重新拉取，避免继续展示昨天的日历。
  Future<void> ensureRangeNotPast() async {
    final resourceId = _selectedResourceId;
    if (resourceId == null) return;
    final today = _dateOnly(DateTime.now());
    if (!_rangeStart.isBefore(today)) return;

    _rangeStart = today;
    _calendar = null;
    notifyListeners();
    await _loadCalendar(resourceId);
  }

  /// 回到以今天为起点的区间。
  Future<void> resetRange() async {
    final resourceId = _selectedResourceId;
    if (resourceId == null) return;
    final today = _dateOnly(DateTime.now());
    if (_rangeStart.isAtSameMomentAs(today)) return;
    _rangeStart = today;
    _calendar = null;
    notifyListeners();
    await _loadCalendar(resourceId);
  }

  /// 提交预约：为当前选中资源预约 [slots]（日期 + 时段 id），[number] 为人数。
  ///
  /// 成功返回结果（`needsProcess` 表示还需走审批/流程页）并刷新当前日历；
  /// 失败抛异常：`ReservationApplyPendingException`（已有未提交预约单）、
  /// `UnauthenticatedException`（会话失效）或 `ServiceException`（服务端
  /// 拒绝，`message` 为服务端原文，如「请填写预约事由」）。
  Future<ReservationLaunchResult> launchReservation({
    required List<ReservationLaunchSlot> slots,
    required int number,
  }) async {
    final resourceId = _selectedResourceId;
    if (resourceId == null) {
      throw const ServiceException('请先选择活动室');
    }
    final result = await _api.launchReservation(
      resourceId: resourceId,
      slots: slots,
      number: number,
    );
    // 预约已改变占用情况，刷新当前区间日历；失败由 _loadCalendar 内部
    // 兜底，不掩盖提交成功的事实。
    await _loadCalendar(resourceId);
    return result;
  }

  // ── 我的预约 ─────────────────────────────────────────────────────────────

  /// 我的预约分页每页条数（与官方「我的预约」一致量级）。
  static const int _appointmentsPageSize = 20;

  /// 分页拉取的防失控上限：10 页 × 20 条，远超正常账号的量级。
  static const int _appointmentsMaxPages = 10;

  List<ReservationAppointment> _appointments = const [];
  bool _appointmentsLoading = false;

  /// 最近一次拉取失败的服务端消息；null 表示无错误。空字符串表示未知
  /// 异常（UI 落 l10n 兜底文案）。
  String? _appointmentsError;

  List<ReservationAppointment> get appointments =>
      List.unmodifiable(_appointments);

  bool get appointmentsLoading => _appointmentsLoading;

  String? get appointmentsError => _appointmentsError;

  /// 拉取我的预约（type=0 全部，自动翻页拉完）。
  ///
  /// 失败不抛出：存入 [appointmentsError] 由 UI 展示，避免「拉取失败被
  /// 当成没有预约记录」；成功前保留旧数据（下拉刷新失败不闪空）。
  Future<void> loadAppointments() async {
    _appointmentsLoading = true;
    _appointmentsError = null;
    notifyListeners();
    try {
      _appointments = await _fetchAllAppointments();
    } on ScuException catch (e) {
      _appointmentsError = e.message;
    } catch (e, logStackTrace) {
      AppLog.e(_tag, 'loadAppointments 失败', error: e, stackTrace: logStackTrace);
      // 空串 = 未知异常，UI 走 l10n 兜底。
      _appointmentsError = '';
    } finally {
      _appointmentsLoading = false;
      notifyListeners();
    }
  }

  Future<List<ReservationAppointment>> _fetchAllAppointments() async {
    final all = <ReservationAppointment>[];
    var page = 1;
    while (page <= _appointmentsMaxPages) {
      final batch = await _api.fetchAppointments(
        page: page,
        pageSize: _appointmentsPageSize,
      );
      all.addAll(batch);
      if (batch.length < _appointmentsPageSize) break;
      page++;
    }
    return all;
  }

  /// 取消一张预约单（整单的全部时段明细）。成功后刷新我的预约与当前日历。
  Future<void> cancelAppointment(ReservationAppointment appointment) async {
    await _api.cancelAppointment(
      appointmentId: appointment.id,
      detailIds: [for (final d in appointment.details) d.id],
    );
    final resourceId = _selectedResourceId;
    if (resourceId != null) {
      await _loadCalendar(resourceId);
    }
    await loadAppointments();
  }

  bool _isCalendarCurrent(String resourceId, DateTime start) =>
      _state != ReservationLoadState.idle &&
      resourceId == _selectedResourceId &&
      start.isAtSameMomentAs(_rangeStart);

  Future<void> _loadCalendar(String resourceId) async {
    final start = _rangeStart;
    final end = start.add(const Duration(days: visibleDays - 1));
    try {
      final calendar = await _api.fetchCalendar(
        resourceId: resourceId,
        startDate: start,
        endDate: end,
      );
      if (!_isCalendarCurrent(resourceId, start)) return;
      _calendar = calendar;
      _state = ReservationLoadState.loaded;
      _errorKind = null;
      _errorMessage = null;
    } on UnauthenticatedException {
      if (!_isCalendarCurrent(resourceId, start)) return;
      _state = ReservationLoadState.error;
      _errorKind = ReservationErrorKind.unauthenticated;
    } catch (e, logStackTrace) {
      if (!_isCalendarCurrent(resourceId, start)) return;
      AppLog.e(_tag, 'loadCalendar 失败', error: e, stackTrace: logStackTrace);
      _state = ReservationLoadState.error;
      _errorKind = ReservationErrorKind.failed;
      _errorMessage = e is ServiceException ? e.message : null;
    }
    notifyListeners();
  }

  /// 登出时复位。
  void clear() {
    _resources = const [];
    _selectedResourceId = null;
    _calendar = null;
    _appointments = const [];
    _appointmentsLoading = false;
    _appointmentsError = null;
    _state = ReservationLoadState.idle;
    _errorKind = null;
    _errorMessage = null;
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
