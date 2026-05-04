import 'package:flutter/material.dart';
import 'package:bugaoshan/pages/campus_page.dart';
import 'package:bugaoshan/pages/campus/academic_calendar/academic_calendar_page.dart';
import 'package:bugaoshan/pages/campus/balance_query/balance_query_page.dart';
import 'package:bugaoshan/pages/campus/classroom/classroom_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_page.dart';
import 'package:bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:bugaoshan/pages/campus/network_device/network_device_page.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
import 'package:bugaoshan/pages/campus/train_program/train_program_page.dart';
import 'package:bugaoshan/pages/course/course_page.dart';
import 'package:bugaoshan/pages/profile_page.dart';
import 'package:bugaoshan/utils/constants.dart';

/// Lightweight dock item: icon + selectedIcon only, no page widget.
const dockMeta = <String, ({IconData icon, IconData selectedIcon})>{
  dockIdCourse: (
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  dockIdCampus: (icon: Icons.school_outlined, selectedIcon: Icons.school),
  dockIdProfile: (icon: Icons.person_outlined, selectedIcon: Icons.person),
  dockIdGrades: (
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
  ),
  dockIdCcyl: (icon: Icons.event_outlined, selectedIcon: Icons.event),
  dockIdPlanCompletion: (
    icon: Icons.assignment_turned_in_outlined,
    selectedIcon: Icons.assignment_turned_in,
  ),
  dockIdTrainProgram: (
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  dockIdClassroom: (
    icon: Icons.meeting_room_outlined,
    selectedIcon: Icons.meeting_room,
  ),
  dockIdNetworkDevice: (
    icon: Icons.router_outlined,
    selectedIcon: Icons.router,
  ),
  dockIdBalanceQuery: (
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  dockIdAcademicCalendar: (
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
};

/// Only builds the page widget when actually selected.
Widget buildDockPage(String id) => switch (id) {
  dockIdCourse => CoursePage(),
  dockIdCampus => const CampusPage(),
  dockIdProfile => ProfilePage(),
  dockIdGrades => const GradesPage(),
  dockIdCcyl => const CcylPage(),
  dockIdPlanCompletion => const PlanCompletionPage(),
  dockIdTrainProgram => const TrainProgramPage(),
  dockIdClassroom => const ClassroomPage(),
  dockIdNetworkDevice => const NetworkDevicePage(),
  dockIdBalanceQuery => const BalanceQueryPage(),
  dockIdAcademicCalendar => const AcademicCalendarPage(),
  _ => ProfilePage(),
};
