import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/constants.dart';

class DockItemConfig {
  final String id;
  final int iconCodePoint;
  final int selectedIconCodePoint;

  const DockItemConfig({
    required this.id,
    required this.iconCodePoint,
    required this.selectedIconCodePoint,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  IconData get selectedIcon =>
      IconData(selectedIconCodePoint, fontFamily: 'MaterialIcons');

}

List<DockItemConfig> allDockItems() => [
      DockItemConfig(
        id: dockIdCourse,
        iconCodePoint: Icons.menu_book_outlined.codePoint,
        selectedIconCodePoint: Icons.menu_book.codePoint,
      ),
      DockItemConfig(
        id: dockIdCampus,
        iconCodePoint: Icons.school_outlined.codePoint,
        selectedIconCodePoint: Icons.school.codePoint,
      ),
      DockItemConfig(
        id: dockIdProfile,
        iconCodePoint: Icons.person_outlined.codePoint,
        selectedIconCodePoint: Icons.person.codePoint,
      ),
      DockItemConfig(
        id: dockIdGrades,
        iconCodePoint: Icons.bar_chart_outlined.codePoint,
        selectedIconCodePoint: Icons.bar_chart.codePoint,
      ),
      DockItemConfig(
        id: dockIdCcyl,
        iconCodePoint: Icons.event_outlined.codePoint,
        selectedIconCodePoint: Icons.event.codePoint,
      ),
      DockItemConfig(
        id: dockIdPlanCompletion,
        iconCodePoint: Icons.assignment_turned_in_outlined.codePoint,
        selectedIconCodePoint: Icons.assignment_turned_in.codePoint,
      ),
      DockItemConfig(
        id: dockIdTrainProgram,
        iconCodePoint: Icons.school_outlined.codePoint,
        selectedIconCodePoint: Icons.school.codePoint,
      ),
      DockItemConfig(
        id: dockIdClassroom,
        iconCodePoint: Icons.meeting_room_outlined.codePoint,
        selectedIconCodePoint: Icons.meeting_room.codePoint,
      ),
      DockItemConfig(
        id: dockIdNetworkDevice,
        iconCodePoint: Icons.router_outlined.codePoint,
        selectedIconCodePoint: Icons.router.codePoint,
      ),
      DockItemConfig(
        id: dockIdBalanceQuery,
        iconCodePoint: Icons.account_balance_wallet_outlined.codePoint,
        selectedIconCodePoint: Icons.account_balance_wallet.codePoint,
      ),
      DockItemConfig(
        id: dockIdAcademicCalendar,
        iconCodePoint: Icons.calendar_month_outlined.codePoint,
        selectedIconCodePoint: Icons.calendar_month.codePoint,
      ),
    ];

/// ID → DockItemConfig lookup map.
final Map<String, DockItemConfig> _dockConfigMap = {
  for (final item in allDockItems()) item.id: item,
};

/// Returns the [DockItemConfig] for [id], or throws if not found.
DockItemConfig dockConfigById(String id) => _dockConfigMap[id]!;

String dockLabel(String id, AppLocalizations l10n) => switch (id) {
      dockIdCourse => l10n.dockLabelCourse,
      dockIdCampus => l10n.dockLabelCampus,
      dockIdProfile => l10n.dockLabelProfile,
      dockIdGrades => l10n.dockLabelGrades,
      dockIdCcyl => l10n.dockLabelCcyl,
      dockIdPlanCompletion => l10n.dockLabelPlanCompletion,
      dockIdTrainProgram => l10n.dockLabelTrainProgram,
      dockIdClassroom => l10n.dockLabelClassroom,
      dockIdNetworkDevice => l10n.dockLabelNetworkDevice,
      dockIdBalanceQuery => l10n.dockLabelBalanceQuery,
      dockIdAcademicCalendar => l10n.dockLabelAcademicCalendar,
      _ => id,
    };
