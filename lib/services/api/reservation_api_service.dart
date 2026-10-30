import 'dart:convert';

import 'package:bugaoshan/pages/campus/reservation/models/reservation_models.dart';
import 'package:bugaoshan/services/api/api_session.dart';
import 'package:bugaoshan/services/auth/reservation_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 预约系统的业务 API 最小契约，供 [ReservationProvider] 注入测试替身。
abstract interface class ReservationApi {
  /// 专题下的资源（活动室）列表。
  Future<List<ReservationResource>> fetchResources();

  /// 资源在 [startDate]..[endDate]（含端点）区间的日历。
  Future<ReservationCalendar> fetchCalendar({
    required String resourceId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// 提交预约：为 [resourceId] 预约 [slots]（日期 + 时段 id），[number] 为人数。
  ///
  /// 成功返回结果（`needsProcess` 表示还需走审批/流程页）；存在未提交的
  /// 预约单时抛 [ReservationApplyPendingException]。
  Future<ReservationLaunchResult> launchReservation({
    required String resourceId,
    required List<ReservationLaunchSlot> slots,
    required int number,
  });

  /// 我的预约列表：[type] 与官方 tab 一致（0 全部 / 1 待申请 / 2 审核中 /
  /// 3 已预约 / 4 待签到），[page] 从 1 起。
  Future<List<ReservationAppointment>> fetchAppointments({
    int type = 0,
    int page = 1,
    int pageSize = 20,
  });

  /// 取消预约（传整单全部明细 id 即整单取消）。服务端拒绝（如该单已进入
  /// 不可取消状态）时抛 [ServiceException] 带服务端原文。
  Future<void> cancelAppointment({
    required String appointmentId,
    required List<String> detailIds,
  });
}

/// 预约系统 API Service（第 1 层）。
///
/// 认证由 [ReservationAuth] 负责（`reservation_uid` 会话），请求失败按
/// 统一认证自愈链重试一次；`e` 非 `OK` 时抛 [ServiceException] 带服务端
/// `m` 原文，`UN_AUTH` 转 [UnauthenticatedException] 以触发重认证。
class ReservationApiService implements ReservationApi {
  static const String _tag = 'ReservationApiService';

  // ignore: unused_field
  final ReservationAuth _auth;
  final ApiSession _session;

  ReservationApiService(this._auth, {ApiSession? session})
    : _session =
          session ??
          ApiSession(
            getClient: _auth.getClient,
            invalidate: _auth.invalidate,
            baseUrl: Uri.parse(kReservationBaseUrl),
            logTag: _tag,
            emptyBodyThrowsUnauthenticated: false,
            jsonValidator: (json) {
              final code = json['e']?.toString();
              if (code == 'UN_AUTH') {
                throw const UnauthenticatedException('预约系统会话未建立或已过期');
              }
            },
            defaultHeaders: const {
              'Referer': kReservationSpecialPageUrl,
            },
          );

  @override
  Future<List<ReservationResource>> fetchResources() async {
    final json = await _session.getJsonMap(
      kReservationTopicResourceListPath,
      query: {
        'id': kReservationTopicId,
        'p': '1',
        'pageSize': '100',
      },
      apiName: 'fetchResources',
    );
    final data = _unwrap(json);
    return reservationResourcesFromJson(data);
  }

  @override
  Future<ReservationCalendar> fetchCalendar({
    required String resourceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 服务端要求 date 是一个 JSON 字符串（不是对象），见 2026-10-23 抓包。
    final date = jsonEncode({
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
    });
    final json = await _session.getJsonMap(
      kReservationCalendarPath,
      query: {'id': resourceId, 'date': date, 'collective': '0'},
      apiName: 'fetchCalendar',
    );
    final data = _unwrap(json);
    return ReservationCalendar.fromJson(data);
  }

  @override
  Future<ReservationLaunchResult> launchReservation({
    required String resourceId,
    required List<ReservationLaunchSlot> slots,
    required int number,
  }) async {
    final json = await _session.postJsonForJsonMap(
      kReservationLaunchPath,
      buildLaunchBody(
        resourceId: resourceId,
        slots: slots,
        number: number,
      ),
      apiName: 'launchReservation',
    );
    final data = _unwrap(json);
    return ReservationLaunchResult.fromJson(data);
  }

  @override
  Future<List<ReservationAppointment>> fetchAppointments({
    int type = 0,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _session.getJsonMap(
      kReservationAppointmentListPath,
      query: {'p': '$page', 'type': '$type', 'pageSize': '$pageSize'},
      apiName: 'fetchAppointments',
    );
    final data = _unwrap(json);
    final rows = data['data'];
    if (rows is! List) return const [];
    return [
      for (final row in rows) ?ReservationAppointment.fromJson(row),
    ];
  }

  @override
  Future<void> cancelAppointment({
    required String appointmentId,
    required List<String> detailIds,
  }) async {
    final json = await _session.postJsonForJsonMap(
      kReservationCancelPath,
      <String, dynamic>{
        'appointment_id': appointmentId,
        'appointment_detail_id': jsonEncode(detailIds),
      },
      apiName: 'cancelAppointment',
    );
    _unwrap(json);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final code = json['e']?.toString();
    if (code == 'APPLY') {
      throw const ReservationApplyPendingException();
    }
    if (code != 'OK') {
      final message = json['m']?.toString();
      throw ServiceException(
        (message == null || message.isEmpty) ? '预约系统请求失败' : message,
      );
    }
    final data = json['d'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 构建 `site/resource/launch` 的请求体，字段与官方前端一致（见
/// [kReservationLaunchPath] 注释）。`data` / `captcha` 是 JSON **字符串**，
/// 独立成顶层函数便于单测断言。
Map<String, dynamic> buildLaunchBody({
  required String resourceId,
  required List<ReservationLaunchSlot> slots,
  required int number,
}) {
  final data = jsonEncode([
    {
      'resource_id': resourceId,
      'period': [
        for (final slot in slots)
          {'date': slot.date, 'period_id': slot.periodId},
      ],
      'number': number,
    },
  ]);
  return {
    'data': data,
    'data_colle': '[]',
    'code': '',
    'number': number,
    'collective': 0,
    'captcha': jsonEncode({'token': '', 'pointJson': ''}),
  };
}
