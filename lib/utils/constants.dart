import 'package:flutter/material.dart' show Curve, Curves;
import 'package:flutter/services.dart';

const Curve appCurve = Curves.easeOutQuart;

const String orgLink = "https://github.com/The-Brotherhood-of-SCU";
const String appLink = "https://github.com/The-Brotherhood-of-SCU/Bugaoshan";

/// 随应用打包的法律文档资源（pubspec.yaml → docs/legal/）
const String kEulaAsset = 'docs/legal/eula.md';
const String kPrivacyPolicyAsset = 'docs/legal/privacy-policy.md';
const String kSupportAsset = 'docs/legal/support.md';

const String dockIdCourse = 'course';
const String dockIdCampus = 'campus';
const String dockIdProfile = 'profile';
const String dockIdGrades = 'grades';
const String dockIdCcyl = 'ccyl';
const String dockIdPlanCompletion = 'plan_completion';
const String dockIdTrainProgram = 'train_program';
const String dockIdClassroom = 'classroom';
const String dockIdNetworkDevice = 'network_device';
const String dockIdPasspoint = 'passpoint';
const String dockIdCloudPrint = 'cloud_print';
const String dockIdBalanceQuery = 'balance_query';
const String dockIdAcademicCalendar = 'academic_calendar';
const String dockIdFitnessTest = 'fitness_test';
const String dockIdNotice = 'notice';
const String dockIdDownloadedAttachments = 'downloaded_attachments';
const String dockIdClassScheduleInquiry = 'class_schedule_inquiry';
const String dockIdExamPlan = 'exam_plan';
const String dockIdZysc = 'zysc';
const String dockIdLeave = 'leave';
const String dockIdRepair = 'repair';
const String dockIdReservation = 'reservation';

// ── 研究生（gsapp）dock 项 ─────────────────────────────────────
const String dockIdGraduateGrades = 'graduate_grades';
const String dockIdGraduateTrainPlan = 'graduate_train_plan';
const String dockIdGraduateScheduleImport = 'graduate_schedule_import';

const Duration kHttpTimeout = Duration(seconds: 15);

/// gh-proxy 镜像前缀，统一此前 gh-proxy.org / gh-proxy.com 两处混用。
///
/// 直接拼接在原始 GitHub URL 之前，对 `github.com/*/releases/download/*` 与
/// `raw.githubusercontent.com/*` 均适用。由 [GithubResourceService] 消费。
const String kGithubProxyPrefix = 'https://gh-proxy.org/';

const String kCcylSpCode =
    'bDBhREE1WDMzK3llSzZyVFZNeE81czRDd1hESTI4NWxGaFdsTnlvcGt3eVdTb2cxSjN5a1FJTDVMWTBEQkFFd2k1bWZRMy82OXN6V21ZYzFLd2NlSDdUaWlVcVJ1emxVVnF4Q3RZNWxjWlVoTEZqUktVSWVmY1ZaKzBLYUlBWDYvaU5MS1E5Y25nT1BoSzRIM0FIOWVCQjMxMXd5b0JrenNuWDBDM1BKU0FwUVVnZHdoSWYrc0hKZmEwSHRQbFZDV1o2dzFtQ3Nuci9wV1ExZHRMMytueHpLZVg5djJJcGFRbkJxZFJCQWJZWHI2dlpQNHVxNFNhcHM3Y3RkK2g1dWFuUEtNT1JZblFXRFBLUEdrcGdxNHR5eEcxclh5YXQ5a2FXN3JSZ2g2OTAxWCt0TUdTNXJDRVdNeDNTU3duTk1nNW9RSyt4WkdzSjNkR3NvVEFDMzFCQmJHUVcrVitybmszQVd0djFpUUJ5dDJySlRTajZIem1qZFYwMjVWcVpEaUtKd1AwQzI3TUpZd3FyY1hqdkxUZkFCd3JwL3ltczdXcmlTUzhZYVJPR0QwOXk2aDJIdUlCUTAvbEJWd0xzcUZXSElxaENpR0pseG1XYTZRbWlFaklERTd6TlhBQkJLdTZGUS8rNTBBYWRkcDVrRXdBM0tqejMvd1AvTklkZW5oNll4MllINlFiNVRucXNhZWtzUlh3d1BOQzBrMERSM0tId3dyS1hONkF6VDZwRGl3S3h1aDNLSGVmcTBRTktXUXMxTTZxeW1lcmgzYVlGWDNmVHdvUnJkWXVhbHN0aEtHKzU5TnFuVm1NbXU4dnhZQk8zKzQrdnV3aTJEaGY4VXRnV3lHeTVBcFFnWlUyQTFsWjdsR1RyNHh1TjV5dUlVc1VNNTRlbEtETTVVYWZoYnFPTXFrM2MxUHVNSHVHLzRtUFk4cmZzaXNUVkovWlhuSkhWWXpYQUJ4UDE4bGt2NXJkMFlXZHM0cFlYVVduKy9ZWGNKTlBDNEVrSzE3R0NVWDNxcCtiQkVyaXMzaTRXam1wWTFzYkpWZTAxYzZ0VGlxcGkvcEYyLzJPND0=';

const String kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0';

/// 研教务 SSO 入口（gsapp 域）。
///
/// 2026-09-20 实测该域在公网 / 校园网均不可达；当前研究生功能（课表、
/// 成绩、培养进度）全部部署在 ehall 域，这里仅保留给 [GsAuth] 的
/// best-effort 预热，失败不阻断 ehall 主链路。
const String kGsSsoUrl = 'https://gsapp.scu.edu.cn/';

/// 研教务在「网上办事大厅」域名下的基址。
///
/// 研究生「我的课表」应用实测部署在该域名下（用户抓包确认，第三方课程表
/// 亦从这里取数）：
/// `https://ehall.scu.edu.cn/gsapp/sys/wdkbapp/*default/index.do#/xskcb`
const String kGsEhallBaseUrl = 'https://ehall.scu.edu.cn';

/// 研究生「我的课表」页面地址（我的课表 app，路由 `#/xskcb`）。
const String kGsSchedulePageUrl =
    '$kGsEhallBaseUrl/gsapp/sys/wdkbapp/*default/index.do'
    '?THEME=cherry&EMAP_LANG=zh#/xskcb';

/// 研究生「我的成绩」应用页面地址（EMAP 应用 index，建立应用会话用）。
const String kGsGradesAppIndexUrl =
    '$kGsEhallBaseUrl/gsapp/sys/wdcjapp/*default/index.do';

/// 研究生「培养进度」应用页面地址（EMAP 应用 index，建立应用会话用）。
const String kGsTrainPlanAppIndexUrl =
    '$kGsEhallBaseUrl/gsapp/sys/wdpyjhapp/*default/index.do';

/// 研究生「我的培养计划」数据接口（2026-09-21 模拟机内抓包定案：
/// MODULE_PATH 取自应用 index.js，均为 GET 无参，零框架信封
/// `{success, reListData, reMapData, msg}`，与 wdcjapp 的 EMAP
/// datas 信封不同）。
const String kGsTrainPlanModulePath = '/gsapp/sys/wdpyjhapp/modules/wdpyjh';

/// 方案基本信息（方案名/方案代码/培养层次/审核状态）。
const String kGsTrainPlanInfoPath = '$kGsTrainPlanModulePath/wdxx.do';

/// 分类学分统计（总计已选/要求 + 方案内外 + 每课程类别一行）。
const String kGsTrainPlanCreditStatsPath =
    '$kGsTrainPlanModulePath/wdkclbtj.do';

/// 方案课程明细（fakcxx[]，含方案内外标记）。
const String kGsTrainPlanCoursesPath = '$kGsTrainPlanModulePath/wdfakcxx.do';

/// 除课表页（[kGsSchedulePageUrl]，兼做 ehall 会话检测）之外需要 SSO
/// 预热的 EMAP 应用 index 列表——EMAP 应用会话要靠访问应用自身 index
/// 建立，缺了会「明明已登录却进不去」。**新增研究生模块时把该应用的
/// index 追加进列表即可，无需再改 gs_auth 主链。**
const List<String> kGsExtraAppIndexUrls = [
  kGsGradesAppIndexUrl,
  kGsTrainPlanAppIndexUrl,
];

// ── 研教务 wdkbapp 数据接口（2026-09-15 登录抓包实测确认）──────────────
//
// 均为 POST + form-urlencoded，基址用 [kGsEhallBaseUrl]（与页面同源，
// 会话 cookie 实测有效）。请求体参数名是金智风格的 XNXQDM（学期5位码，
// 如 20261=2026年秋季学期），不是 EMAP 常见的 xnm/xqm。

/// 学生课表查询（排课结构）：每节课一行，字段 KCMC/JSXM/JASMC/XQ(星期,
/// 周一=1)/KSJCDM/JSJCDM/ZCMC（周次文本）。
const String kGsScheduleEndpointPath =
    '/gsapp/sys/wdkbapp/modules/xskcb/xspkjgcx.do';

/// 学期列表（课表页学期下拉框数据源，5位学期码）。
const String kGsSemesterListPath =
    '/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do';

/// 首次上课日期（含 SCSKRQ + PKSJ，用于反推学期第1周周一）。
const String kGsFirstClassPath = '/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';

// ── 研教务 wdcjapp 数据接口（2026-09-20 抓包定案）────────────────────
//
// 成绩查询同样是 POST + form-urlencoded、ehall 域、标准 GS 信封
// `{"code":"0","datas":{"xscjcx":{"rows":[…]}}}`。

/// 研究生成绩查询：每门课一行，字段 KCMC/KCDM/XNXQDM/XF(学分)/
/// DYBFZCJ(对应百分成绩)/JDZ(绩点)/CJ(成绩原文,分制内编码)/CJXSZ(显示值,
/// 如「免修通过」)/SFJG(是否及格)/SFYX(是否有效)/BZSM(备注)。
const String kGsGradesEndpointPath =
    '/gsapp/sys/wdcjapp/modules/wdcj/xscjcx.do';

// ── 预约系统（service.scu.edu.cn/reservation，2026-10-23 抓包定案）──────
//
// 独立部署的预约系统（Nuxt SPA），与办事大厅同域但**会话独立**：
// 登录后 service.scu.edu.cn 域下持有 `reservation_uid`（办事大厅是
// `vjuid`）。接口统一信封 `{e, m, d}`，`e == "OK"` 为成功，
// `UN_AUTH` 表示会话未建立 / 已过期。

/// 预约系统根路径（业务接口与页面都在其下）。
const String kReservationBaseUrl = 'https://service.scu.edu.cn/reservation';

/// 「望江校区研究生活动室」专题 id（#347 的入口专题）。
const String kReservationTopicId = '37';

/// 专题页面地址（兼作 SSO 的 redirect_url 与业务请求的 Referer）。
const String kReservationSpecialPageUrl =
    '$kReservationBaseUrl/fe/site/special/m_special'
    '?id=$kReservationTopicId&platform_id=28';

/// 预约系统 SSO 入口：`/api/login/main` 302 到 id.scu.edu.cn 的 CAS
/// plugin，回跳 `/api/login/cas` 时下发 `reservation_uid`。
final String kReservationSsoUrl = Uri.parse(
  '$kReservationBaseUrl/api/login/main',
).replace(queryParameters: {'redirect_url': kReservationSpecialPageUrl}).toString();

/// 专题资源列表（`d.data[].base` 为资源定义，`time` / `appointmen_list_info`
/// 在列表接口里恒为空，时段要单独查 calendar）。
const String kReservationTopicResourceListPath =
    '/api/topic/resource-list';

/// 资源日历：`id`(资源) + `date`(JSON 字符串 `{start_date,end_date}`)
/// + `collective`(0)。返回 `{time:[时段], day:[日期], data:{日期:{时段id:{status,total,num,amount}}}}`。
const String kReservationCalendarPath = '/site/resource/calendar';

/// 提交预约：`POST`，body 为
/// `{data, data_colle, code, number, collective, captcha}`，其中 `data` 是
/// JSON **字符串**：`[{resource_id, period: [{date, period_id}], number}]`
/// （自由时间段类资源则是 `{start_date,end_date,start_time,end_time}`，
/// 见 2026-10-24 对官方前端 `site/resourceLaunch` 的分析）。
/// 成功 `d = {is_relate, process_url, process_id, time}`；`e == "APPLY"`
/// 表示存在未提交的预约单。
const String kReservationLaunchPath = '/site/resource/launch';

/// 我的预约列表：`GET`，query `{p, type, pageSize}`；`type` 与官方「我的预约」
/// tab 一致（0 全部 / 1 待申请 / 2 审核中 / 3 已预约 / 4 待签到）。响应
/// `d = {data: [预约单], total}`，行含 `id / resource_name / created /
/// status / type / is_cancel / is_creater / detail`，其中 `detail` 是
/// `日期 -> [{id, str_time}]` 的对象（可按明细部分取消）。
const String kReservationAppointmentListPath = '/site/appointment/appointment-list';

/// 取消预约：`POST`，body `{appointment_id, appointment_detail_id}`，其中
/// `appointment_detail_id` 是**明细 id 的 JSON 字符串**（传整单全部明细
/// 即整单取消）。服务器要求该单 `is_cancel == 1` 且当前用户是创建者。
const String kReservationCancelPath = '/site/appointment/appointment-cancel';

const MethodChannel kUpdateMethodChannel = MethodChannel('bugaoshan/update');
const MethodChannel kDynamicIconMethodChannel = MethodChannel(
  'bugaoshan/dynamic_icon',
);
const EventChannel kDownloadCancelEventChannel = EventChannel(
  'bugaoshan/download_cancel',
);

// 以下常量自上游 main 移植（2026-09-15 同步）
const String dockIdCourseCurriculum = 'course_curriculum';

const String officialWebsiteLink = "https://bugaoshan.scubro.dev/";

const String userManualLink = "https://bugaoshan-docs.scubro.dev/manual/";
