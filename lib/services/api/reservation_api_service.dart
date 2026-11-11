import 'dart:convert';

import 'package:bugaoshan/pages/campus/reservation/models/reservation_models.dart';
import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/reservation_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:http/http.dart' as http;

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
  ReservationApiService(this._auth);

  static const String _tag = 'ReservationApiService';

  final ReservationAuth _auth;

  @override
  Future<List<ReservationResource>> fetchResources() {
    return _request((client) async {
      final json = await _getJson(
        client,
        kReservationTopicResourceListPath,
        query: {
          'id': kReservationTopicId,
          'p': '1',
          'pageSize': '100',
        },
      );
      // 抓包结构：`d = {data: [ {base: {...}} ], resources: [], total, ... }`。
      return reservationResourcesFromJson(json);
    });
  }

  @override
  Future<ReservationCalendar> fetchCalendar({
    required String resourceId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _request((client) async {
      // 服务端要求 date 是一个 JSON 字符串（不是对象），见 2026-10-23 抓包。
      final date = jsonEncode({
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      });
      final json = await _getJson(
        client,
        kReservationCalendarPath,
        query: {'id': resourceId, 'date': date, 'collective': '0'},
      );
      return ReservationCalendar.fromJson(json);
    });
  }

  @override
  Future<ReservationLaunchResult> launchReservation({
    required String resourceId,
    required List<ReservationLaunchSlot> slots,
    required int number,
  }) {
    return _request((client) async {
      final json = await _postJson(
        client,
        kReservationLaunchPath,
        body: buildLaunchBody(
          resourceId: resourceId,
          slots: slots,
          number: number,
        ),
      );
      return ReservationLaunchResult.fromJson(json);
    });
  }

  @override
  Future<List<ReservationAppointment>> fetchAppointments({
    int type = 0,
    int page = 1,
    int pageSize = 20,
  }) {
    return _request((client) async {
      final json = await _getJson(
        client,
        kReservationAppointmentListPath,
        query: {'p': '$page', 'type': '$type', 'pageSize': '$pageSize'},
      );
      final rows = json['data'];
      if (rows is! List) return const [];
      return [
        for (final row in rows) ?ReservationAppointment.fromJson(row),
      ];
    });
  }

  @override
  Future<void> cancelAppointment({
    required String appointmentId,
    required List<String> detailIds,
  }) {
    return _request((client) async {
      await _postJson(
        client,
        kReservationCancelPath,
        body: <String, dynamic>{
          'appointment_id': appointmentId,
          'appointment_detail_id': jsonEncode(detailIds),
        },
      );
    });
  }

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return retryOnUnauthenticated(
      _auth.getClient,
      fn,
      invalidate: _auth.invalidate,
      logTag: _tag,
    );
  }

  /// GET 预约接口并解包 `{e, m, d}`，成功返回 `d`。
  Future<Map<String, dynamic>> _getJson(
    CookieClient client,
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$kReservationBaseUrl$path').replace(
      queryParameters: query,
    );
    final response = await client.get(uri, headers: _headers);
    return _decodeEnvelope(response, path);
  }

  /// POST JSON 预约接口并解包 `{e, m, d}`，成功返回 `d`。
  Future<Map<String, dynamic>> _postJson(
    CookieClient client,
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$kReservationBaseUrl$path');
    final response = await client.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeEnvelope(response, path);
  }

  /// 解包 `{e, m, d}` 信封：`UN_AUTH` 转认证异常，`APPLY` 转未提交预约单
  /// 异常，其它非 `OK` 抛 [ServiceException] 带服务端 `m` 原文。
  Future<Map<String, dynamic>> _decodeEnvelope(
    http.Response response,
    String path,
  ) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UnauthenticatedException('预约系统会话未建立或已过期');
    }
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw ServiceException(
        '预约系统请求失败',
        statusCode: response.statusCode,
      );
    }

    // 空 body 不直接判成未登录：网关偶发剥 body 时会白白触发一次重认证。
    // 先按「无数据」处理，只有带登录页特征或业务码明确 UN_AUTH 才转认证异常。
    if (response.body.trim().isEmpty) {
      throw ServiceException('预约系统返回了空响应');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      if (looksLikeLoginPage(response.body)) {
        throw const UnauthenticatedException('预约系统会话已过期');
      }
      AppLog.e(_tag, '$path 响应非 JSON（len=${response.body.length}）');
      throw ServiceException('预约系统返回了无法解析的数据');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ServiceException('预约系统返回了无法解析的数据');
    }

    final code = decoded['e']?.toString();
    if (code == 'UN_AUTH') {
      throw const UnauthenticatedException('预约系统会话未建立或已过期');
    }
    if (code == 'APPLY') {
      throw const ReservationApplyPendingException();
    }
    if (code != 'OK') {
      final message = decoded['m']?.toString();
      throw ServiceException(
        (message == null || message.isEmpty) ? '预约系统请求失败' : message,
      );
    }

    final data = decoded['d'];
    return data is Map<String, dynamic> ? data : const {};
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/plain, */*',
    'User-Agent': kDefaultUserAgent,
    'Referer': kReservationSpecialPageUrl,
    'X-Requested-With': 'XMLHttpRequest',
  };

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
