import 'dart:convert';

import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/gs_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/graduate_schedule_parser.dart';
import 'package:bugaoshan/utils/graduate_grades_parser.dart';
import 'package:bugaoshan/utils/gs_json_envelope.dart';

/// 研教务（gsapp / EMAP）API 服务（第1层）。
///
/// 通过 [GsAuth] 获取的 CookieClient 访问研教务接口。响应信封已实测确认
/// （见 [unwrapGsEnvelope]）：`{"code":"0","datas":{"<动作名>":{"rows":[…]}}}`
/// —— [_postForm] 统一解包后交给各解析器。
///
/// 课表链路（2026-09-15 登录抓包实测定案，见 `.tmp/gs/findings.md` §8；
/// 2026-09-20 浏览器抓包补充确认行内另带 ZCBH 周次位串与 KSSJ/JSSJ 时刻）：
/// - 课表 `POST xspkjgcx.do`，body `XNXQDM=<学期5位码>&*order=-ZCBH`，
///   行字段 KCMC/JSXM/JASMC/XQ(星期,周一=1)/KSJCDM/JSJCDM/ZCMC/ZCBH/KSSJ/JSSJ；
/// - 学期列表 `kfdxnxqcx.do`、首次上课日期 `xsjxrwcx.do`（SCSKRQ）。
///
/// 成绩链路（2026-09-20 抓包定案）：`POST xscjcx.do`（wdcjapp），标准 GS
/// 信封，行字段见 [GraduateGradeRow]。
///
/// 培养计划的 `.do` 端点尚未定案，对应方法随功能一并添加
/// （应用入口：培养进度 `/sys/wdpyjhapp/*default/index.do`、
/// 培养方案 `/sys/wdpyfaappscu/*default/index.do#/pyfaxq`）。
class GsApiService {
  GsApiService(this._gsAuth);

  static const String _tag = 'GsApiService';

  final GsAuth _gsAuth;

  /// 研究生课表（供课表导入，直连）。
  ///
  /// [xnxqdm] 缺省时自动取最新学期码（[fetchSemesters] 的最大值）；
  /// 获取学期码失败则传空让服务端按会话默认（与页面初次加载一致）。
  ///
  /// 返回值同时带解析出的课程与由行内 `KSSJ`/`JSSJ` 派生的课表专属
  /// 时刻表（接口没给时刻或脏数据时为 null，调用方沿用预置作息）。
  Future<({List<Course> courses, List<TimeSlot>? timeSlots})> fetchSchedule({
    String? xnxqdm,
  }) async {
    final term = xnxqdm ?? await latestSemesterCode() ?? '';
    final rows = await _postForm(kGsScheduleEndpointPath, {
      'XNXQDM': term,
      '*order': '-ZCBH',
    });
    return (
      courses: graduateCoursesFromJson(rows),
      timeSlots: graduateTimeSlotsFromRows(
        rows,
        fallback: ScheduleConfig.wangJiangHuaXiTimeSlots,
      ),
    );
  }

  /// 学期码列表（kfdxnxqcx.do），按码值降序（最大 = 最新学期）。
  ///
  /// 响应行结构未逐字段核实，这里只宽松抽取形如 5 位数字的学期码
  /// （候选键 XNXQDM/DM/NXQDM/WID）。
  Future<List<String>> fetchSemesters() async {
    final rows = await _postForm(kGsSemesterListPath, const {});
    final codePattern = RegExp(r'^\d{5}$');
    final codes = <String>{};
    for (final row in rows) {
      for (final key in const ['XNXQDM', 'DM', 'NXQDM', 'WID']) {
        final value = row[key]?.toString();
        if (value != null && codePattern.hasMatch(value)) {
          codes.add(value);
          break;
        }
      }
    }
    final sorted = codes.toList()..sort();
    return sorted.reversed.toList();
  }

  /// 最新学期码；学期列表不可用时返回 null（调用方回退到服务端默认学期）。
  Future<String?> latestSemesterCode() async {
    try {
      final semesters = await fetchSemesters();
      return semesters.isEmpty ? null : semesters.first;
    } catch (e) {
      AppLog.w(_tag, 'latestSemesterCode: $e');
      return null;
    }
  }

  /// 首次上课日期行（SCSKRQ / PKSJ），供学期第 1 周周一反推，
  /// 见 [semesterStartMondayFromFirstClassRows]。
  Future<List<Map<String, dynamic>>> fetchFirstClassRows(
    String xnxqdm,
  ) async {
    return _postForm(kGsFirstClassPath, {
      'XNXQDM': xnxqdm,
      'XH': '',
      'pageNumber': '1',
      'pageSize': '999',
    });
  }

  /// 研究生成绩行（wdcjapp，2026-09-20 抓包定案）。
  ///
  /// 抓包请求未带查询参数（服务端默认分页 pageSize=12，样本里
  /// totalSize/pageNumber/pageSize/extParams.totalPage 齐全）。这里按信封
  /// 分页元数据**循环翻页取全**，不赌一次大 pageSize——服务端对 pageSize
  /// 有 cap 时也能取全，统计不会静默缺行。
  Future<List<GraduateGradeRow>> fetchGrades() async {
    final rows = await _postFormAllPages(kGsGradesEndpointPath, const {});
    return graduateGradeRowsFromJson(rows);
  }

  /// POST 表单到 ehall 域的 `.do` 接口，解包信封为行列表。
  ///
  /// 包一层 [retryOnUnauthenticated]（与本科教务在线导入同一自愈模式）：
  /// 首次请求若抛 [UnauthenticatedException]，先 [_gsAuth.invalidate] 清掉
  /// 会话缓存、重新 SSO，再重试一次；第二次仍失败才穿透给调用方。
  Future<List<Map<String, dynamic>>> _postForm(
    String path,
    Map<String, String> fields,
  ) {
    return retryOnUnauthenticated(
      _gsAuth.getClient,
      (client) => _postEnvelopeOnce(client, path, fields)
          .then(gsRows),
      invalidate: _gsAuth.invalidate,
    );
  }

  /// 按 EMAP 分页信封循环翻页，聚合全部行。
  ///
  /// 每页独立包一层 [retryOnUnauthenticated]（某页会话中途过期也能自愈，
  /// 重试只重发当前页）。终止条件按可信度依次兜底：
  /// - 返回空页立即停（防 totalPage 谎报导致死循环）；
  /// - `extParams.totalPage` 给了且翻满 → 停；
  /// - `totalSize` 给了且累计行数够了 → 停；
  /// - 返回行数少于请求 pageSize（未满页即最后一页）→ 停；
  /// - 硬上限 [_maxPagedRequests] 次防呆。
  Future<List<Map<String, dynamic>>> _postFormAllPages(
    String path,
    Map<String, String> fields, {
    int pageSize = 200,
  }) async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final envelope = await retryOnUnauthenticated(
        _gsAuth.getClient,
        (client) async {
          final decoded = await _postEnvelopeOnce(client, path, {
            ...fields,
            'pageNumber': '$page',
            'pageSize': '$pageSize',
          });
          return gsPagedEnvelope(decoded) ??
              GsPagedEnvelope(rows: const []);
        },
        invalidate: _gsAuth.invalidate,
      );
      if (envelope.rows.isEmpty) break;
      all.addAll(envelope.rows);
      final totalPage = envelope.totalPage;
      final totalSize = envelope.totalSize;
      if (totalPage != null && page >= totalPage) break;
      if (totalSize != null && all.length >= totalSize) break;
      // 未满页即最后一页。页大小以信封回显的 pageSize 为准——服务端
      // cap 过 pageSize 时它反映的是实际容量，不能用请求值判断。
      final effectivePageSize = envelope.pageSize ?? pageSize;
      if (envelope.rows.length < effectivePageSize) break;
      page++;
      if (page > 50) break;
    }
    return all;
  }

  /// [retryOnUnauthenticated] 里的单次请求：状态码校验 + 信封 JSON 解码。
  ///
  /// - 401/403 → [UnauthenticatedException]；
  /// - **空 body → [UnauthenticatedException]**：会话过期时服务端可能回
  ///   200 空响应（网关剥 body），当成「无数据」会让成绩页显示「暂无
  ///   成绩」而不是「去登录」——空 body 走自愈重试，重试仍空才穿透；
  /// - 响应不是 JSON：会话失效时服务端给的是登录页 HTML，用
  ///   [looksLikeLoginPage] 强特征判定后抛 [UnauthenticatedException]（让
  ///   自动重试与全局「登录会话已过期」提示生效），其余非 JSON 抛
  ///   [ServiceException]；
  /// - 信封 `code` 非成功值 → 由 [unwrapGsEnvelope] 抛 [ServiceException]，
  ///   这里**不吞**该异常。
  Future<Object?> _postEnvelopeOnce(
    CookieClient client,
    String path,
    Map<String, String> fields,
  ) async {
    final response = await client.post(
      Uri.parse('$kGsEhallBaseUrl$path'),
      headers: {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'User-Agent': kDefaultUserAgent,
        'Referer': kGsSchedulePageUrl,
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: fields,
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UnauthenticatedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw ServiceException('研教务请求失败', statusCode: response.statusCode);
    }
    if (response.body.isEmpty) {
      throw const UnauthenticatedException('研教务返回了空响应');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      if (looksLikeLoginPage(response.body)) {
        throw const UnauthenticatedException('研教务会话已过期');
      }
      AppLog.e(_tag, '$path 响应非 JSON（len=${response.body.length}）');
      throw ServiceException('研教务返回了无法解析的数据');
    }
    return decoded;
  }
}
