import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/pages/settings/add_widget/add_widget_page.dart';
import 'package:bugaoshan/pages/settings/set_dock_page.dart';
import 'package:bugaoshan/pages/settings/set_duration_page.dart';
import 'package:bugaoshan/pages/settings/set_language_page.dart';
import 'package:bugaoshan/pages/settings/set_app_icon_page.dart';
import 'package:bugaoshan/pages/settings/set_course_style_page.dart';
import 'package:bugaoshan/pages/settings/set_font_page.dart';
import 'package:bugaoshan/pages/settings/set_student_type_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_color_page.dart';
import 'package:bugaoshan/pages/settings/reminder_setting_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_mode_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/section_title.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class SoftwareSettingPage extends StatelessWidget {
  const SoftwareSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(localizations.softwareSetting)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          SectionTitle(title: localizations.settingsGeneral),
          InfoCard(
            children: [
              IconTile(
                icon: Icons.language,
                label: localizations.modifyLanguage,
                onTap: () => popupOrNavigate(context, SetLanguagePage()),
              ),
              IconTile(
                icon: Icons.notifications_active_outlined,
                label: localizations.reminderSettingsTitle,
                onTap: () =>
                    popupOrNavigate(context, const ReminderSettingPage()),
              ),
              ValueListenableBuilder<StudentType>(
                valueListenable: appConfig.studentType,
                builder: (context, studentType, _) => IconTile(
                  icon: Icons.badge_outlined,
                  label: localizations.studentTypeSetting,
                  value: studentType == StudentType.graduate
                      ? localizations.studentTypeGraduate
                      : localizations.studentTypeUndergraduate,
                  onTap: () =>
                      popupOrNavigate(context, const SetStudentTypePage()),
                ),
              ),
              if (Platform.isAndroid)
                IconTile(
                  icon: Icons.photo_size_select_actual_outlined,
                  label: localizations.appIcon,
                  onTap: () => popupOrNavigate(context, const SetAppIconPage()),
                ),
              IconTile(
                icon: Icons.timer,
                label: localizations.animationDuration,
                onTap: () => popupOrNavigate(context, SetDurationPage()),
              ),
              IconTile(
                icon: Icons.dock_outlined,
                label: localizations.customDock,
                onTap: () => popupOrNavigate(context, const SetDockPage()),
              ),
              if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
                IconTile(
                  icon: Icons.widgets_outlined,
                  label: localizations.addWidgetPageTitle,
                  onTap: () => popupOrNavigate(context, const AddWidgetPage()),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SectionTitle(title: localizations.settingsStyle),
          InfoCard(
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: appConfig.themeMode,
                builder: (context, mode, _) => IconTile(
                  icon: Icons.dark_mode_outlined,
                  label: localizations.darkMode,
                  value: switch (mode) {
                    ThemeMode.system => localizations.followSystem,
                    ThemeMode.light => localizations.themeModeLight,
                    ThemeMode.dark => localizations.themeModeDark,
                  },
                  onTap: () =>
                      popupOrNavigate(context, const SetThemeModePage()),
                ),
              ),
              IconTile(
                icon: Icons.color_lens,
                label: localizations.themeColor,
                onTap: () => popupOrNavigate(context, SetThemeColorPage()),
              ),
              IconTile(
                icon: Icons.style,
                label: localizations.courseStyleSetting,
                onTap: () =>
                    popupOrNavigate(context, const SetCourseStylePage()),
              ),
              IconTile(
                icon: Icons.font_download,
                label: localizations.setFont,
                onTap: () => popupOrNavigate(context, const SetFontPage()),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: appConfig.logPersistenceEnabled,
                builder: (context, enabled, _) => SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(localizations.logPersistenceSwitch),
                  subtitle: Text(
                    localizations.logPersistenceSwitchHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: enabled,
                  onChanged: (v) => appConfig.logPersistenceEnabled.value = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionTitle(title: localizations.settingsDanger),
          InfoCard(
            children: [
              IconTile(
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
                    // 日志文件也清掉：用户点了「清除所有数据」就应真的全清，
                    // 否则残留日志既不符预期，也与 privacy-policy / EULA 的
                    // 「按数据类型另行删除」说明产生矛盾。
                    await getIt<AppLogger>().deletePersistedFiles();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
