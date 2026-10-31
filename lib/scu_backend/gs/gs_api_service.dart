import 'dart:convert';

import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/scu_backend/core/api_session.dart';
import 'package:bugaoshan/scu_backend/gs/gs_auth.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/gs/gs_json_envelope.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/graduate_grades_parser.dart';
import 'package:bugaoshan/utils/graduate_schedule_parser.dart';

/// 研教务（gsapp / EMAP）API 服务（第1层）。
class GsApiService {
  GsApiService(GsAuth gsAuth, {ApiSession? session})
    : _session =
          session ??
          ApiSession(
            getClient: gsAuth.getClient,
            invalidate: gsAuth.invalidate,
            baseUrl: Uri.parse(kGsEhallBaseUrl),
            logTag: _tag,
          );

  static const String _tag = 'GsApiService';

  /// 分页循环防呆硬上限：正常请求 totalPage / totalSize / 未满页都会先
  /// 于它命中，只兜「服务端元数据全撒谎」的死循环。
  static const int _maxPagedRequests = 50;

  /// 表单 POST 的站点特定 Header（Accept / Referer 与页面一致）；
  /// 其余通用 Header 由 [ApiSession] 注入。
  static const Map<String, String> _postHeaders = {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Referer': kGsSchedulePageUrl,
    'X-Requested-With': 'XMLHttpRequest',
  };

  /// 培养进度 GET 的站点特定 Header。
  static const Map<String, String> _zeroHeaders = {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Referer': kGsTrainPlanAppIndexUrl,
    'X-Requested-With': 'XMLHttpRequest',
  };

  final ApiSession _session;

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
    } catch (e, logStackTrace) {
      AppLog.e(
        _tag,
        'latestSemesterCode 失败',
        error: e,
        stackTrace: logStackTrace,
      );

      return null;
    }
  }

  /// 首次上课日期行（SCSKRQ / PKSJ），供学期第 1 周周一反推，
  /// 见 [semesterStartMondayFromFirstClassRows]。
  Future<List<Map<String, dynamic>>> fetchFirstClassRows(String xnxqdm) async {
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
  Future<List<Map<String, dynamic>>> _postForm(
    String path,
    Map<String, String> fields,
  ) async {
    return gsRows(await _postEnvelope(path, fields));
  }

  /// 按 EMAP 分页信封循环翻页，聚合全部行。
  ///
  /// 每页独立走一次 [ApiSession] 请求（某页会话中途过期也能自愈，
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
      final envelope =
          gsPagedEnvelope(
            await _postEnvelope(path, {
              ...fields,
              'pageNumber': '$page',
              'pageSize': '$pageSize',
            }),
          ) ??
          const GsPagedEnvelope(rows: []);
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
      if (page > _maxPagedRequests) break;
    }
    return all;
  }

  /// 单次表单 POST：认证生命周期、状态码校验与 JSON 解析均由
  /// [ApiSession] 完成，这里只负责信封校验。
  Future<Map<String, dynamic>> _postEnvelope(
    String path,
    Map<String, String> fields,
  ) async {
    final decoded = await _session.postFormForJsonMap(
      path,
      fields,
      headers: _postHeaders,
      apiName: path,
    );
    unwrapGsEnvelope(decoded);
    return decoded;
  }

  /// ── 研究生培养进度（wdpyjhapp，2026-09-21 模拟机内抓包定案）────────
  ///
  /// 三个 GET 无参接口，零框架信封（`{success, reListData, reMapData, msg}`），
  /// 与 wdcjapp 的 EMAP datas 信封不同，单独走 [_getZeroJson]。

  /// 方案基本信息（方案名/方案代码/培养层次/审核状态）。
  Future<GraduateTrainPlanInfo> fetchTrainPlanInfo() async {
    final decoded = await _getZeroJson(kGsTrainPlanInfoPath);
    final reMapData = _zeroReMapData(decoded);
    final xsxx = reMapData['XSXX'];
    return GraduateTrainPlanInfo.fromJson(
      xsxx is Map<String, dynamic> ? xsxx : const {},
    );
  }

  /// 分类学分统计：返回（总计, 每课程类别一行）。
  ///
  /// `reMapData`：YXXF 总计已选 / ZDXF 学分要求 / FANYXXF 方案内 / FAWYXXF
  /// 方案外；`reListData`：每类 DM/MC/YXXF（已选）/ZDXF（要求）/YXMS（门数）。
  Future<
    (GraduateTrainPlanCreditStats, List<GraduateTrainPlanCategoryProgress>)
  >
  fetchTrainPlanCreditStats() async {
    final decoded = await _getZeroJson(kGsTrainPlanCreditStatsPath);
    final reMapData = _zeroReMapData(decoded);
    final stats = GraduateTrainPlanCreditStats.fromJson(reMapData);
    final list = decoded['reListData'];
    final rows = [
      if (list is List)
        for (final row in list)
          if (row is Map<String, dynamic>)
            GraduateTrainPlanCategoryProgress.fromJson(row),
    ];
    return (stats, rows);
  }

  /// 方案课程明细（按课程类别分组展示用，含方案内外标记）。
  Future<List<GraduateTrainPlanCourse>> fetchTrainPlanCourses() async {
    final decoded = await _getZeroJson(kGsTrainPlanCoursesPath);
    final list = decoded['fakcxx'];
    return [
      if (list is List)
        for (final row in list)
          if (row is Map<String, dynamic>)
            GraduateTrainPlanCourse.fromJson(row),
    ];
  }

  Map<String, dynamic> _zeroReMapData(Map<String, dynamic> decoded) {
    final reMapData = decoded['reMapData'];
    return reMapData is Map<String, dynamic> ? reMapData : const {};
  }

  /// GET 零信封请求（认证自愈与状态码校验由 [ApiSession] 完成）。
  Future<Map<String, dynamic>> _getZeroJson(String path) async {
    final response = await _session.followRedirects(
      path,
      headers: _zeroHeaders,
      apiName: path,
    );

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (logError, logStackTrace) {
      AppLog.e(
        _tag,
        '_getZeroJson 失败',
        error: logError,
        stackTrace: logStackTrace,
      );
      if (looksLikeLoginPage(response.body)) {
        throw const UnauthenticatedException('研教务会话已过期');
      }
      AppLog.e(_tag, '$path 响应非 JSON（len=${response.body.length}）');
      throw ServiceException('研教务返回了无法解析的数据');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ServiceException('研教务返回了无法解析的数据');
    }
    if (decoded['success'] != true) {
      final msg = decoded['msg']?.toString();
      throw ServiceException((msg == null || msg.isEmpty) ? '研教务接口返回失败' : msg);
    }
    return decoded;
  }
}
