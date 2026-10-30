import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/about/about_page.dart';
import 'package:bugaoshan/pages/course/management/schedule_management_page.dart';
import 'package:bugaoshan/pages/course/settings/course_schedule_setting.dart';
import 'package:bugaoshan/pages/settings/software_setting_page.dart';
import 'package:bugaoshan/providers/riverpod/course/course_pods.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/utils/open_link.dart' show openUserManual;
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class ProfileMenuCard extends ConsumerWidget {
  const ProfileMenuCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final hasSchedule = ref.watch(hasScheduleProvider);
    final hasUpdate = ref.watch(hasUpdateNotificationSettingProvider);

    final disabledColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    return InfoCard(
      children: [
        IconTile(
          icon: Icons.list_alt_rounded,
          label: localizations.scheduleManagement,
          onTap: () => popupOrNavigate(context, const ScheduleManagementPage()),
        ),
        IconTile(
          icon: Icons.schedule_rounded,
          label: localizations.scheduleSetting,
          iconColor: hasSchedule ? null : disabledColor,
          labelColor: hasSchedule ? null : disabledColor,
          onTap: hasSchedule
              ? () => popupOrNavigate(context, CourseScheduleSetting())
              : null,
        ),
        IconTile(
          icon: Icons.settings_rounded,
          label: localizations.softwareSetting,
          onTap: () => popupOrNavigate(context, SoftwareSettingPage()),
        ),
        LinkTile(
          icon: Icons.menu_book_rounded,
          label: localizations.userManual,
          onTap: openUserManual,
        ),
        BadgedTile(
          icon: Icons.info_outline_rounded,
          label: localizations.about,
          showBadge: hasUpdate,
          onTap: () => popupOrNavigate(context, AboutPage()),
        ),
      ],
    );
  }
}
