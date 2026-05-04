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
import 'package:bugaoshan/pages/profile/profile_page.dart';
import 'package:bugaoshan/utils/constants.dart';

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
