import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/about/about_page.dart';
import 'package:bugaoshan/pages/course/course_schedule_setting.dart';
import 'package:bugaoshan/pages/course/schedule_management_page.dart';
import 'package:bugaoshan/pages/settings/software_setting_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final courseProvider = getIt<CourseProvider>();

    return InfoCard(
      children: [
        IconTile(
          icon: Icons.list_alt_rounded,
          label: localizations.scheduleManagement,
          onTap: () => popupOrNavigate(context, const ScheduleManagementPage()),
        ),
        ValueListenableBuilder(
          valueListenable: courseProvider.allSchedules,
          builder: (context, allSchedules, _) {
            final hasSchedule = allSchedules.isNotEmpty;
            final disabledColor = Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
            return IconTile(
              icon: Icons.schedule_rounded,
              label: localizations.scheduleSetting,
              iconColor: hasSchedule ? null : disabledColor,
              labelColor: hasSchedule ? null : disabledColor,
              onTap: hasSchedule
                  ? () => popupOrNavigate(context, CourseScheduleSetting())
                  : null,
            );
          },
        ),
        IconTile(
          icon: Icons.settings_rounded,
          label: localizations.softwareSetting,
          onTap: () => popupOrNavigate(context, SoftwareSettingPage()),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: getIt<AppConfigProvider>().hasUpdateNotification,
          builder: (context, hasUpdate, _) {
            return BadgedTile(
              icon: Icons.info_outline_rounded,
              label: localizations.about,
              showBadge: hasUpdate,
              onTap: () => popupOrNavigate(context, AboutPage()),
            );
          },
        ),
      ],
    );
  }
}
