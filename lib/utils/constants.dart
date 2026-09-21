import 'package:flutter/services.dart';

const String orgLink = "https://github.com/The-Brotherhood-of-SCU";
const String appLink = "https://github.com/The-Brotherhood-of-SCU/Bugaoshan";

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

// ── 研究生（gsapp）dock 项 ─────────────────────────────────────
const String dockIdGraduateSection = 'graduate';
const String dockIdGraduateGrades = 'graduate_grades';
const String dockIdGraduateTrainPlan = 'graduate_train_plan';
const String dockIdGraduateScheduleImport = 'graduate_schedule_import';
const String dockIdLabAttendance = 'lab_attendance';
const String dockIdThesisProgress = 'thesis_progress';
const String dockIdMentorTasks = 'mentor_tasks';

const Duration kHttpTimeout = Duration(seconds: 15);

const String kCcylSpCode =
    'bDBhREE1WDMzK3llSzZyVFZNeE81czRDd1hESTI4NWxGaFdsTnlvcGt3eVdTb2cxSjN5a1FJTDVMWTBEQkFFd2k1bWZRMy82OXN6V21ZYzFLd2NlSDdUaWlVcVJ1emxVVnF4Q3RZNWxjWlVoTEZqUktVSWVmY1ZaKzBLYUlBWDYvaU5MS1E5Y25nT1BoSzRIM0FIOWVCQjMxMXd5b0JrenNuWDBDM1BKU0FwUVVnZHdoSWYrc0hKZmEwSHRQbFZDV1o2dzFtQ3Nuci9wV1ExZHRMMytueHpLZVg5djJJcGFRbkJxZFJCQWJZWHI2dlpQNHVxNFNhcHM3Y3RkK2g1dWFuUEtNT1JZblFXRFBLUEdrcGdxNHR5eEcxclh5YXQ5a2FXN3JSZ2g2OTAxWCt0TUdTNXJDRVdNeDNTU3duTk1nNW9RSyt4WkdzSjNkR3NvVEFDMzFCQmJHUVcrVitybmszQVd0djFpUUJ5dDJySlRTajZIem1qZFYwMjVWcVpEaUtKd1AwQzI3TUpZd3FyY1hqdkxUZkFCd3JwL3ltczdXcmlTUzhZYVJPR0QwOXk2aDJIdUlCUTAvbEJWd0xzcUZXSElxaENpR0pseG1XYTZRbWlFaklERTd6TlhBQkJLdTZGUS8rNTBBYWRkcDVrRXdBM0tqejMvd1AvTklkZW5oNll4MllINlFiNVRucXNhZWtzUlh3d1BOQzBrMERSM0tId3dyS1hONkF6VDZwRGl3S3h1aDNLSGVmcTBRTktXUXMxTTZxeW1lcmgzYVlGWDNmVHdvUnJkWXVhbHN0aEtHKzU5TnFuVm1NbXU4dnhZQk8zKzQrdnV3aTJEaGY4VXRnV3lHeTVBcFFnWlUyQTFsWjdsR1RyNHh1TjV5dUlVc1VNNTRlbEtETTVVYWZoYnFPTXFrM2MxUHVNSHVHLzRtUFk4cmZzaXNUVkovWlhuSkhWWXpYQUJ4UDE4bGt2NXJkMFlXZHM0cFlYVVduKy9ZWGNKTlBDNEVrSzE3R0NVWDNxcCtiQkVyaXMzaTRXam1wWTFzYkpWZTAxYzZ0VGlxcGkvcEYyLzJPND0=';

const String kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0';

/// 研教务 SSO 入口（真实地址待抓包确认，见 TODO(gs-api)）。
const String kGsSsoUrl = 'https://gsapp.scu.edu.cn/';

/// 研教务 API 基址（gsapp 应用组）。
const String kGsApiBaseUrl = 'https://gsapp.scu.edu.cn';

/// 研教务在「网上办事大厅」域名下的基址。
///
/// 研究生「我的课表」应用实测部署在该域名下（用户抓包确认，第三方课程表
/// 亦从这里取数）：
/// `https://ehall.scu.edu.cn/gsapp/sys/wdkbapp/*default/index.do#/xskcb`
/// 与 [kGsApiBaseUrl] 是否共用同一套 cookie 尚未验证，见 TODO(gs-api)。
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
