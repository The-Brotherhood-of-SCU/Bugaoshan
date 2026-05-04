import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/constants.dart';

class DockItemConfig {
  final String id;
  final int iconCodePoint;
  final int selectedIconCodePoint;
  final String labelKey;

  const DockItemConfig({
    required this.id,
    required this.iconCodePoint,
    required this.selectedIconCodePoint,
    required this.labelKey,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  IconData get selectedIcon =>
      IconData(selectedIconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => {
        'id': id,
        'iconCodePoint': iconCodePoint,
        'selectedIconCodePoint': selectedIconCodePoint,
        'labelKey': labelKey,
      };

  factory DockItemConfig.fromJson(Map<String, dynamic> json) =>
      DockItemConfig(
        id: json['id'] as String,
        iconCodePoint: json['iconCodePoint'] as int,
        selectedIconCodePoint: json['selectedIconCodePoint'] as int,
        labelKey: json['labelKey'] as String,
      );
}

List<DockItemConfig> allDockItems() => [
      DockItemConfig(
        id: dockIdCourse,
        iconCodePoint: Icons.menu_book_outlined.codePoint,
        selectedIconCodePoint: Icons.menu_book.codePoint,
        labelKey: dockIdCourse,
      ),
      DockItemConfig(
        id: dockIdCampus,
        iconCodePoint: Icons.school_outlined.codePoint,
        selectedIconCodePoint: Icons.school.codePoint,
        labelKey: dockIdCampus,
      ),
      DockItemConfig(
        id: dockIdProfile,
        iconCodePoint: Icons.person_outlined.codePoint,
        selectedIconCodePoint: Icons.person.codePoint,
        labelKey: dockIdProfile,
      ),
      DockItemConfig(
        id: dockIdGrades,
        iconCodePoint: Icons.bar_chart_outlined.codePoint,
        selectedIconCodePoint: Icons.bar_chart.codePoint,
        labelKey: dockIdGrades,
      ),
      DockItemConfig(
        id: dockIdCcyl,
        iconCodePoint: Icons.event_outlined.codePoint,
        selectedIconCodePoint: Icons.event.codePoint,
        labelKey: dockIdCcyl,
      ),
      DockItemConfig(
        id: dockIdPlanCompletion,
        iconCodePoint: Icons.assignment_turned_in_outlined.codePoint,
        selectedIconCodePoint: Icons.assignment_turned_in.codePoint,
        labelKey: dockIdPlanCompletion,
      ),
      DockItemConfig(
        id: dockIdTrainProgram,
        iconCodePoint: Icons.school_outlined.codePoint,
        selectedIconCodePoint: Icons.school.codePoint,
        labelKey: dockIdTrainProgram,
      ),
      DockItemConfig(
        id: dockIdClassroom,
        iconCodePoint: Icons.meeting_room_outlined.codePoint,
        selectedIconCodePoint: Icons.meeting_room.codePoint,
        labelKey: dockIdClassroom,
      ),
      DockItemConfig(
        id: dockIdNetworkDevice,
        iconCodePoint: Icons.router_outlined.codePoint,
        selectedIconCodePoint: Icons.router.codePoint,
        labelKey: dockIdNetworkDevice,
      ),
      DockItemConfig(
        id: dockIdBalanceQuery,
        iconCodePoint: Icons.account_balance_wallet_outlined.codePoint,
        selectedIconCodePoint: Icons.account_balance_wallet.codePoint,
        labelKey: dockIdBalanceQuery,
      ),
      DockItemConfig(
        id: dockIdAcademicCalendar,
        iconCodePoint: Icons.calendar_month_outlined.codePoint,
        selectedIconCodePoint: Icons.calendar_month.codePoint,
        labelKey: dockIdAcademicCalendar,
      ),
    ];
