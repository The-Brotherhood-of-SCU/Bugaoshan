import 'package:bugaoshan/pages/campus/service_hall/service_hall_page.dart';
import 'package:bugaoshan/pages/campus/zysc/zysc_page.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/pages/campus/academic_calendar/academic_calendar_page.dart';
import 'package:bugaoshan/pages/campus/balance_query/balance_query_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_page.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_page.dart';
import 'package:bugaoshan/pages/campus/classroom/classroom_page.dart';
import 'package:bugaoshan/pages/campus/course_curriculum/course_curriculum_page.dart';
import 'package:bugaoshan/pages/campus/downloads/notice_downloaded_page.dart';
import 'package:bugaoshan/pages/campus/exam_plan/exam_plan_page.dart';
import 'package:bugaoshan/pages/campus/fitness_test/fitness_test_page.dart';
import 'package:bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:bugaoshan/pages/campus/network_device/network_device_page.dart';
import 'package:bugaoshan/pages/campus/passpoint/passpoint_page.dart';
import 'package:bugaoshan/pages/campus/notice/notice_page.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
import 'package:bugaoshan/pages/campus/repair/repair_page.dart';
import 'package:bugaoshan/pages/campus/train_program/train_program_page.dart';
import 'package:bugaoshan/pages/campus_page/campus_page.dart';
import 'package:bugaoshan/pages/course/main/course_page.dart';
import 'package:bugaoshan/pages/graduate/graduate_grades_page.dart';
import 'package:bugaoshan/pages/graduate/graduate_train_plan_page.dart';
import 'package:bugaoshan/pages/graduate/schedule_import_page.dart';
import 'package:bugaoshan/pages/profile/profile_page.dart';

class CampusItemConfig {
  final String id;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations) dockLabel;
  final String Function(AppLocalizations) dockFullLabel;
  final String Function(AppLocalizations) desc;
  final Widget Function() page;

  /// 目标受众；null 表示通用（本科生 / 研究生都展示）。
  ///
  /// 仅本科教务（zhjw）或研教务（gsapp）专属功能需要打标，
  /// 由 [campusItemVisibleForStudentType] 按全局学生身份过滤。
  final StudentType? audience;

  CampusItemConfig({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.dockLabel,
    required this.dockFullLabel,
    required this.desc,
    required this.page,
    this.audience,
  });
}

class CampusSection {
  final String Function(AppLocalizations) title;
  final List<CampusItemConfig> items;

  CampusSection({required this.title, required this.items});
}

final campusItemCourse = CampusItemConfig(
  id: dockIdCourse,
  icon: Icons.menu_book_outlined,
  selectedIcon: Icons.menu_book,
  dockLabel: (l10n) => l10n.dockLabelCourse,
  dockFullLabel: (l10n) => l10n.course,
  desc: (l10n) => '',
  page: () => const CoursePage(),
);

final campusItemCampus = CampusItemConfig(
  id: dockIdCampus,
  icon: Icons.school_outlined,
  selectedIcon: Icons.school,
  dockLabel: (l10n) => l10n.dockLabelCampus,
  dockFullLabel: (l10n) => l10n.campus,
  desc: (l10n) => '',
  page: () => const CampusPage(),
);

final campusItemProfile = CampusItemConfig(
  id: dockIdProfile,
  icon: Icons.person_outlined,
  selectedIcon: Icons.person,
  dockLabel: (l10n) => l10n.dockLabelProfile,
  dockFullLabel: (l10n) => l10n.profile,
  desc: (l10n) => '',
  page: () => const ProfilePage(),
);

final campusItemGrades = CampusItemConfig(
  id: dockIdGrades,
  icon: Icons.bar_chart_outlined,
  selectedIcon: Icons.bar_chart,
  dockLabel: (l10n) => l10n.dockLabelGrades,
  dockFullLabel: (l10n) => l10n.gradesStats,
  desc: (l10n) => l10n.gradesStatsDesc,
  page: () => const GradesPage(),
  audience: StudentType.undergraduate,
);

final campusItemCcyl = CampusItemConfig(
  id: dockIdCcyl,
  icon: Icons.event_outlined,
  selectedIcon: Icons.event,
  dockLabel: (l10n) => l10n.dockLabelCcyl,
  dockFullLabel: (l10n) => l10n.ccylTitle,
  desc: (l10n) => l10n.ccylDesc,
  page: () => const CcylPage(),
);

final campusItemPlanCompletion = CampusItemConfig(
  id: dockIdPlanCompletion,
  icon: Icons.assignment_turned_in_outlined,
  selectedIcon: Icons.assignment_turned_in,
  dockLabel: (l10n) => l10n.dockLabelPlanCompletion,
  dockFullLabel: (l10n) => l10n.planCompletion,
  desc: (l10n) => l10n.planCompletionDesc,
  page: () => const PlanCompletionPage(),
  audience: StudentType.undergraduate,
);

final campusItemFitnessTest = CampusItemConfig(
  id: dockIdFitnessTest,
  icon: Icons.directions_run,
  selectedIcon: Icons.directions_run,
  dockLabel: (l10n) => l10n.dockLabelFitnessTest,
  dockFullLabel: (l10n) => l10n.fitnessTest,
  desc: (l10n) => l10n.fitnessTestDesc,
  page: () => const FitnessTestPage(),
);

final campusItemTrainProgram = CampusItemConfig(
  id: dockIdTrainProgram,
  icon: Icons.history_edu_outlined,
  selectedIcon: Icons.history_edu,
  dockLabel: (l10n) => l10n.dockLabelTrainProgram,
  dockFullLabel: (l10n) => l10n.trainProgram,
  desc: (l10n) => l10n.trainProgramDesc,
  page: () => const TrainProgramPage(),
  audience: StudentType.undergraduate,
);

final campusItemClassroom = CampusItemConfig(
  id: dockIdClassroom,
  icon: Icons.meeting_room_outlined,
  selectedIcon: Icons.meeting_room,
  dockLabel: (l10n) => l10n.dockLabelClassroom,
  dockFullLabel: (l10n) => l10n.classroomQuery,
  desc: (l10n) => l10n.classroomQueryDesc,
  page: () => const ClassroomPage(),
  audience: StudentType.undergraduate,
);

final campusItemClassScheduleInquiry = CampusItemConfig(
  id: dockIdClassScheduleInquiry,
  icon: Icons.calendar_view_week_outlined,
  selectedIcon: Icons.calendar_view_week,
  dockLabel: (l10n) => l10n.dockLabelClassScheduleInquiry,
  dockFullLabel: (l10n) => l10n.classScheduleInquiry,
  desc: (l10n) => l10n.classScheduleInquiryDesc,
  page: () => const ClassScheduleInquiryPage(),
  audience: StudentType.undergraduate,
);

final campusItemCourseCurriculum = CampusItemConfig(
  id: dockIdCourseCurriculum,
  icon: Icons.calendar_view_month_outlined,
  selectedIcon: Icons.calendar_view_month,
  dockLabel: (l10n) => l10n.dockLabelCourseCurriculum,
  dockFullLabel: (l10n) => l10n.courseCurriculum,
  desc: (l10n) => l10n.courseCurriculumDesc,
  page: () => const CourseCurriculumPage(),
  audience: StudentType.undergraduate,
);

final campusItemNetworkDevice = CampusItemConfig(
  id: dockIdNetworkDevice,
  icon: Icons.router_outlined,
  selectedIcon: Icons.router,
  dockLabel: (l10n) => l10n.dockLabelNetworkDevice,
  dockFullLabel: (l10n) => l10n.networkDeviceQuery,
  desc: (l10n) => l10n.networkDeviceQueryDesc,
  page: () => const NetworkDevicePage(),
);

final campusItemPasspoint = CampusItemConfig(
  id: dockIdPasspoint,
  icon: Icons.wifi_password_outlined,
  selectedIcon: Icons.wifi_password,
  dockLabel: (l10n) => l10n.dockLabelPasspoint,
  dockFullLabel: (l10n) => l10n.passpointTitle,
  desc: (l10n) => l10n.passpointDesc,
  page: () => const PasspointPage(),
);

final campusItemBalanceQuery = CampusItemConfig(
  id: dockIdBalanceQuery,
  icon: Icons.account_balance_wallet_outlined,
  selectedIcon: Icons.account_balance_wallet,
  dockLabel: (l10n) => l10n.dockLabelBalanceQuery,
  dockFullLabel: (l10n) => l10n.balanceQuery,
  desc: (l10n) => l10n.balanceQueryDesc,
  page: () => const BalanceQueryPage(),
);

final campusItemAcademicCalendar = CampusItemConfig(
  id: dockIdAcademicCalendar,
  icon: Icons.calendar_month_outlined,
  selectedIcon: Icons.calendar_month,
  dockLabel: (l10n) => l10n.dockLabelAcademicCalendar,
  dockFullLabel: (l10n) => l10n.academicCalendar,
  desc: (l10n) => l10n.academicCalendarDesc,
  page: () => const AcademicCalendarPage(),
);

final campusItemExamPlan = CampusItemConfig(
  id: dockIdExamPlan,
  icon: Icons.assignment_outlined,
  selectedIcon: Icons.assignment,
  dockLabel: (l10n) => l10n.dockLabelExamPlan,
  dockFullLabel: (l10n) => l10n.examPlan,
  desc: (l10n) => l10n.examPlanDesc,
  page: () => const ExamPlanPage(),
  audience: StudentType.undergraduate,
);

final campusItemNotice = CampusItemConfig(
  id: dockIdNotice,
  icon: Icons.campaign_outlined,
  selectedIcon: Icons.campaign,
  dockLabel: (l10n) => l10n.dockLabelNotice,
  dockFullLabel: (l10n) => l10n.noticeSection,
  desc: (l10n) => l10n.campusNoticesDesc,
  page: () => const NoticePage(),
);

final campusItemDownloads = CampusItemConfig(
  id: dockIdDownloadedAttachments,
  icon: Icons.folder_open,
  selectedIcon: Icons.folder_open,
  dockLabel: (l10n) => l10n.dockLabelDownloads,
  dockFullLabel: (l10n) => l10n.downloadedAttachments,
  desc: (l10n) => l10n.downloadedAttachmentsDesc,
  page: () => const NoticeDownloadedPage(),
);

final campusItemZysc = CampusItemConfig(
  id: dockIdZysc,
  icon: Icons.event_outlined,
  selectedIcon: Icons.event,
  dockLabel: (l10n) => l10n.dockLabelZysc,
  dockFullLabel: (l10n) => l10n.zyscTitle,
  desc: (l10n) => l10n.zyscDesc,
  page: () => const ZyscPage(),
);

final campusItemLeave = CampusItemConfig(
  id: dockIdLeave,
  icon: Icons.fact_check_outlined,
  selectedIcon: Icons.fact_check,
  dockLabel: (l10n) => l10n.dockLabelLeave,
  dockFullLabel: (l10n) => l10n.serviceHallTitle,
  desc: (l10n) => l10n.leaveDesc,
  page: () => const ServiceHallPage(),
);

final campusItemRepair = CampusItemConfig(
  id: dockIdRepair,
  icon: Icons.build_outlined,
  selectedIcon: Icons.build,
  dockLabel: (l10n) => l10n.dockLabelRepair,
  dockFullLabel: (l10n) => l10n.repairTitle,
  desc: (l10n) => l10n.repairDesc,
  page: () => const RepairPage(),
);

final campusItemGraduateGrades = CampusItemConfig(
  id: dockIdGraduateGrades,
  icon: Icons.grading_outlined,
  selectedIcon: Icons.grading,
  dockLabel: (l10n) => l10n.graduateGrades,
  dockFullLabel: (l10n) => l10n.graduateGrades,
  desc: (l10n) => l10n.graduateGradesDesc,
  page: () => const GraduateGradesPage(),
  audience: StudentType.graduate,
);

final campusItemGraduateTrainPlan = CampusItemConfig(
  id: dockIdGraduateTrainPlan,
  icon: Icons.account_tree_outlined,
  selectedIcon: Icons.account_tree,
  dockLabel: (l10n) => l10n.graduateTrainPlan,
  dockFullLabel: (l10n) => l10n.graduateTrainPlan,
  desc: (l10n) => l10n.graduateTrainPlanDesc,
  page: () => const GraduateTrainPlanPage(),
  audience: StudentType.graduate,
);

final campusItemGraduateScheduleImport = CampusItemConfig(
  id: dockIdGraduateScheduleImport,
  icon: Icons.cloud_download_outlined,
  selectedIcon: Icons.cloud_download,
  dockLabel: (l10n) => l10n.graduateScheduleImport,
  dockFullLabel: (l10n) => l10n.graduateScheduleImport,
  desc: (l10n) => l10n.graduateScheduleImportDesc,
  page: () => const GraduateScheduleImportPage(),
  audience: StudentType.graduate,
);

final campusSections = [
  // 研究生条目不单设分区：有全局身份开关后按「对应本科功能」的位置
  // 就地并入——研究生成绩挨着成绩统计、培养进度挨着方案修读情况，
  // 课表导入挨着班级课表/课程课表。audience 过滤负责显隐。
  CampusSection(
    title: (l10n) => l10n.academicSection,
    items: [
      campusItemGrades,
      campusItemGraduateGrades,
      campusItemCcyl,
      campusItemPlanCompletion,
      campusItemGraduateTrainPlan,
      campusItemFitnessTest,
      campusItemExamPlan,
    ],
  ),
  CampusSection(
    title: (l10n) => l10n.utilitiesSection,
    items: [
      campusItemTrainProgram,
      campusItemClassScheduleInquiry,
      campusItemCourseCurriculum,
      campusItemGraduateScheduleImport,
      campusItemClassroom,
      campusItemNetworkDevice,
      campusItemPasspoint,
      campusItemBalanceQuery,
      campusItemRepair,
      campusItemAcademicCalendar,
      campusItemZysc,
      campusItemLeave,
    ],
  ),
  CampusSection(
    title: (l10n) => l10n.noticeSection,
    items: [campusItemNotice, campusItemDownloads],
  ),
];

final allCampusItems = [
  campusItemCourse,
  campusItemCampus,
  campusItemProfile,
  ...campusSections.expand((s) => s.items),
];

const defaultVisibleDockIds = [dockIdCourse, dockIdCampus, dockIdProfile];

CampusItemConfig campusItemConfigById(String id) => allCampusItems.firstWhere(
  (item) => item.id == id,
  orElse: () => campusItemProfile,
);

/// 该功能项在指定学生身份下是否展示；[CampusItemConfig.audience] 为 null
/// （通用）时恒为 true。
bool campusItemVisibleForStudentType(CampusItemConfig item, StudentType type) =>
    item.audience == null || item.audience == type;

/// 按学生身份过滤校园页功能分区；过滤后为空的分区整个隐藏
/// （如本科生模式下「研究生」分区）。
List<CampusSection> campusSectionsForStudentType(StudentType type) => [
  for (final section in campusSections)
    if (section.items.any(
      (item) => campusItemVisibleForStudentType(item, type),
    ))
      CampusSection(
        title: section.title,
        items: [
          for (final item in section.items)
            if (campusItemVisibleForStudentType(item, type)) item,
        ],
      ),
];

/// 按学生身份过滤全部功能项（含课程/校园/我的三项），供 dock 自定义页
/// 与首页 dock 渲染使用。
List<CampusItemConfig> allCampusItemsForStudentType(StudentType type) => [
  for (final item in allCampusItems)
    if (campusItemVisibleForStudentType(item, type)) item,
];
