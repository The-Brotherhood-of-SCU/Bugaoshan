import 'dart:io';

import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/add_widget/add_widget_page.dart';
import 'package:bugaoshan/pages/settings/set_dock_page.dart';
import 'package:bugaoshan/pages/settings/set_duration_page.dart';
import 'package:bugaoshan/pages/settings/set_language_page.dart';
import 'package:bugaoshan/pages/settings/set_course_style_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_color_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class SoftwareSettingPage extends StatelessWidget {
  const SoftwareSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return ListenableBuilder(
      listenable: Listenable.merge([appConfig.widgetShowTomorrow]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(localizations.softwareSetting)),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // General settings card
              _buildCard(
                theme: theme,
                surfaceColor: surfaceColor,
                children: [
                  _SettingTile(
                    icon: Icons.language,
                    label: localizations.modifyLanguage,
                    onTap: () => popupOrNavigate(context, SetLanguagePage()),
                  ),
                  _divider(theme),
                  _SettingTile(
                    icon: Icons.timer,
                    label: localizations.animationDuration,
                    onTap: () => popupOrNavigate(context, SetDurationPage()),
                  ),
                  _divider(theme),
                  _SettingTile(
                    icon: Icons.color_lens,
                    label: localizations.themeColor,
                    onTap: () => popupOrNavigate(context, SetThemeColorPage()),
                  ),
                  _divider(theme),
                  _SettingTile(
                    icon: Icons.dock_outlined,
                    label: localizations.customDock,
                    onTap: () => popupOrNavigate(context, const SetDockPage()),
                  ),
                  _divider(theme),
                  _SettingTile(
                    icon: Icons.style,
                    label: localizations.courseStyleSetting,
                    onTap: () =>
                        popupOrNavigate(context, const SetCourseStylePage()),
                  ),
                ],
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 12),
                // Widget settings card
                _buildCard(
                  theme: theme,
                  surfaceColor: surfaceColor,
                  children: [
                    _SettingTile(
                      icon: Icons.widgets_outlined,
                      label: localizations.addWidgetPageTitle,
                      onTap: () =>
                          popupOrNavigate(context, const AddWidgetPage()),
                    ),
                    _divider(theme),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _iconContainer(
                            theme.colorScheme.primary,
                            Icons.calendar_today_outlined,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              localizations.widgetShowTomorrowAfterEnd,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          Switch(
                            value: appConfig.widgetShowTomorrow.value,
                            onChanged: (v) async {
                              appConfig.widgetShowTomorrow.value = v;
                              final service = getIt<WidgetUpdateService>();
                              try {
                                await service.updateWidgetData(force: true);
                              } catch (e, st) {
                                debugPrint('WidgetUpdate toggle failed: $e');
                                debugPrint('$st');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Danger zone card
              _buildCard(
                theme: theme,
                surfaceColor: surfaceColor,
                children: [
                  _SettingTile(
                    icon: Icons.delete,
                    iconColor: Colors.red,
                    label: localizations.clearAllData,
                    labelColor: Colors.red,
                    onTap: () async {
                      final confirm = await showYesNoDialog(
                        title: localizations.clearAllData,
                        content: localizations.confirmMessage,
                      );
                      if (confirm == true) {
                        final scuAuth = getIt<ScuAuthProvider>();
                        await scuAuth.logout();
                        await scuAuth.clearCredentials();
                        await appConfig.clearAll();
                        final courseProvider = getIt<CourseProvider>();
                        await courseProvider.clearAllData();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildCard({
    required ThemeData theme,
    required Color surfaceColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  static Widget _divider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 56,
      color: theme.dividerColor.withValues(alpha: 0.08),
    );
  }

  static Widget _iconContainer(Color primaryColor, IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: primaryColor, size: 20),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _SettingTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = iconColor ?? theme.colorScheme.primary;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SoftwareSettingPage._iconContainer(primaryColor, icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(color: labelColor),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            size: 20,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: tile);
    }
    return tile;
  }
}
