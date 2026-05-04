import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/about/about_page.dart';
import 'package:bugaoshan/pages/course/course_schedule_setting.dart';
import 'package:bugaoshan/pages/course/schedule_management_page.dart';
import 'package:bugaoshan/pages/settings/software_setting_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final primaryColor = theme.colorScheme.primary;

    Widget buildTile({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Widget? trailing,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              ?trailing,
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          buildTile(
            icon: Icons.list_alt_rounded,
            label: localizations.scheduleManagement,
            onTap: () =>
                popupOrNavigate(context, const ScheduleManagementPage()),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          buildTile(
            icon: Icons.schedule_rounded,
            label: localizations.scheduleSetting,
            onTap: () => popupOrNavigate(context, CourseScheduleSetting()),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          buildTile(
            icon: Icons.settings_rounded,
            label: localizations.softwareSetting,
            onTap: () => popupOrNavigate(context, SoftwareSettingPage()),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: getIt<AppConfigProvider>().hasUpdateNotification,
            builder: (context, hasUpdate, _) {
              return buildTile(
                icon: Icons.info_outline_rounded,
                label: localizations.about,
                onTap: () => popupOrNavigate(context, AboutPage()),
                trailing: hasUpdate
                    ? Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
