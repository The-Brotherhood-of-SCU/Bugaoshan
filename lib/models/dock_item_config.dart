import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/constants.dart';

class DockItemConfig {
  final String id;
  final IconData icon;
  final IconData selectedIcon;

  const DockItemConfig({
    required this.id,
    required this.icon,
    required this.selectedIcon,
  });
}

const allDockItems = [
  DockItemConfig(
    id: dockIdCourse,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  DockItemConfig(
    id: dockIdCampus,
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  DockItemConfig(
    id: dockIdProfile,
    icon: Icons.person_outlined,
    selectedIcon: Icons.person,
  ),
  DockItemConfig(
    id: dockIdGrades,
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
  ),
  DockItemConfig(
    id: dockIdCcyl,
    icon: Icons.event_outlined,
    selectedIcon: Icons.event,
  ),
  DockItemConfig(
    id: dockIdPlanCompletion,
    icon: Icons.assignment_turned_in_outlined,
    selectedIcon: Icons.assignment_turned_in,
  ),
  DockItemConfig(
    id: dockIdTrainProgram,
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  DockItemConfig(
    id: dockIdClassroom,
    icon: Icons.meeting_room_outlined,
    selectedIcon: Icons.meeting_room,
  ),
  DockItemConfig(
    id: dockIdNetworkDevice,
    icon: Icons.router_outlined,
    selectedIcon: Icons.router,
  ),
  DockItemConfig(
    id: dockIdBalanceQuery,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  DockItemConfig(
    id: dockIdAcademicCalendar,
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
];

/// ID → DockItemConfig lookup map.
final Map<String, DockItemConfig> dockConfigMap = {
  for (final item in allDockItems) item.id: item,
};

/// Returns the [DockItemConfig] for [id].
/// Falls back to [dockIdProfile] if [id] is not found.
DockItemConfig dockConfigById(String id) =>
    dockConfigMap[id] ?? dockConfigMap[dockIdProfile]!;

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
