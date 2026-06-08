import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/pages/campus/academic_calendar/academic_calendar_page.dart';
import 'package:bugaoshan/pages/campus/balance_query/balance_query_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_page.dart';
import 'package:bugaoshan/pages/campus/class_schedule_inquiry/class_schedule_inquiry_page.dart';
import 'package:bugaoshan/pages/campus/classroom/classroom_page.dart';
import 'package:bugaoshan/pages/campus/downloads/notice_downloaded_page.dart';
import 'package:bugaoshan/pages/campus/fitness_test/fitness_test_page.dart';
import 'package:bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:bugaoshan/pages/campus/network_device/network_device_page.dart';
import 'package:bugaoshan/pages/campus/notice/notice_page.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
import 'package:bugaoshan/pages/campus/train_program/train_program_page.dart';
import 'package:bugaoshan/pages/campus_page.dart';
import 'package:bugaoshan/pages/course/course_page.dart';
import 'package:bugaoshan/pages/profile/profile_page.dart';

class CampusItemConfig {
  final String id;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations) dockLabel;
  final String Function(AppLocalizations) dockFullLabel;
  final String Function(AppLocalizations) desc;
  final Widget Function() page;

  CampusItemConfig({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.dockLabel,
    required this.dockFullLabel,
    required this.desc,
    required this.page,
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
);

final campusItemClassroom = CampusItemConfig(
  id: dockIdClassroom,
  icon: Icons.meeting_room_outlined,
  selectedIcon: Icons.meeting_room,
  dockLabel: (l10n) => l10n.dockLabelClassroom,
  dockFullLabel: (l10n) => l10n.classroomQuery,
  desc: (l10n) => l10n.classroomQueryDesc,
  page: () => const ClassroomPage(),
);

final campusItemClassScheduleInquiry = CampusItemConfig(
  id: dockIdClassScheduleInquiry,
  icon: Icons.calendar_view_week_outlined,
  selectedIcon: Icons.calendar_view_week,
  dockLabel: (l10n) => l10n.dockLabelClassScheduleInquiry,
  dockFullLabel: (l10n) => l10n.classScheduleInquiry,
  desc: (l10n) => l10n.classScheduleInquiryDesc,
  page: () => const ClassScheduleInquiryPage(),
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

final campusSections = [
  CampusSection(
    title: (l10n) => l10n.academicSection,
    items: [
      campusItemGrades,
      campusItemCcyl,
      campusItemPlanCompletion,
      campusItemFitnessTest,
    ],
  ),
  CampusSection(
    title: (l10n) => l10n.utilitiesSection,
    items: [
      campusItemTrainProgram,
      campusItemClassScheduleInquiry,
      campusItemClassroom,
      campusItemNetworkDevice,
      campusItemBalanceQuery,
      campusItemAcademicCalendar,
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
