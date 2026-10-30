import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:bugaoshan/pages/settings/set_proxy_page.dart';
import 'package:bugaoshan/pages/settings/set_student_type_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_color_page.dart';
import 'package:bugaoshan/pages/settings/reminder_setting_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_mode_page.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/course/course_pods.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/section_title.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/utils/system_insets.dart';

class SoftwareSettingPage extends ConsumerWidget {
  const SoftwareSettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final studentType = ref.watch(studentTypeSettingProvider);
    final mode = ref.watch(themeModeSettingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.softwareSetting)),
      body: ListView(
        padding: withSystemBottomInset(
          context,
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        children: [
          SectionTitle(title: localizations.settingsGeneral),
          InfoCard(
            children: [
              IconTile(
                icon: Icons.language,
                label: localizations.modifyLanguage,
                onTap: () => popupOrNavigate(context, const SetLanguagePage()),
              ),
              IconTile(
                icon: Icons.notifications_active_outlined,
                label: localizations.reminderSettingsTitle,
                onTap: () =>
                    popupOrNavigate(context, const ReminderSettingPage()),
              ),
              IconTile(
                icon: Icons.badge_outlined,
                label: localizations.studentTypeSetting,
                value: studentType == StudentType.graduate
                    ? localizations.studentTypeGraduate
                    : localizations.studentTypeUndergraduate,
                onTap: () =>
                    popupOrNavigate(context, const SetStudentTypePage()),
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
                onTap: () => popupOrNavigate(context, const SetDurationPage()),
              ),
              IconTile(
                icon: Icons.dock_outlined,
                label: localizations.customDock,
                onTap: () => popupOrNavigate(context, const SetDockPage()),
              ),
              IconTile(
                icon: Icons.alt_route,
                label: localizations.networkProxy,
                onTap: () => popupOrNavigate(context, const SetProxyPage()),
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
              IconTile(
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
              IconTile(
                icon: Icons.color_lens,
                label: localizations.themeColor,
                onTap: () => popupOrNavigate(context, const SetThemeColorPage()),
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
                    final scuAuth = ref.read(scuAuthProviderBridge);
                    await scuAuth.logout();
                    await scuAuth.clearCredentials();
                    await ref.read(appConfigProviderBridge).clearAll();
                    final courseProv = ref.read(courseProvider);
                    await courseProv.clearAllData();
                    // 日志文件也清掉：用户点了「清除所有数据」就应真的全清，
                    // 否则残留日志既不符预期，也与 privacy-policy / EULA 的
                    // 「按数据类型另行删除」说明产生矛盾。
                    await getIt<AppLogger>().deletePersistedFiles(
                      preserveEnabled: true,
                    );
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
