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
import 'package:bugaoshan/widgets/common/styled_widget.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class SoftwareSettingPage extends StatelessWidget {
  const SoftwareSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();

    return ListenableBuilder(
      listenable: Listenable.merge([appConfig.widgetShowTomorrow]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(localizations.softwareSetting)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Column(
              spacing: 16,
              children: [
                ButtonWithMaxWidth(
                  onPressed: () {
                    popupOrNavigate(context, SetLanguagePage());
                  },
                  icon: const Icon(Icons.language),
                  child: Text(localizations.modifyLanguage),
                ),
                ButtonWithMaxWidth(
                  onPressed: () {
                    popupOrNavigate(context, SetDurationPage());
                  },
                  icon: const Icon(Icons.timer),
                  child: Text(localizations.animationDuration),
                ),
                ButtonWithMaxWidth(
                  onPressed: () {
                    popupOrNavigate(context, SetThemeColorPage());
                  },
                  icon: const Icon(Icons.color_lens),
                  child: Text(localizations.themeColor),
                ),
                ButtonWithMaxWidth(
                  onPressed: () {
                    popupOrNavigate(context, const SetDockPage());
                  },
                  icon: const Icon(Icons.dock_outlined),
                  child: Text(localizations.customDock),
                ),

                ButtonWithMaxWidth(
                  onPressed: () {
                    popupOrNavigate(context, const SetCourseStylePage());
                  },
                  icon: const Icon(Icons.style),
                  child: Text(localizations.courseStyleSetting),
                ),

                if (Platform.isAndroid) ...[
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      localizations.addWidgetSection,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  ButtonWithMaxWidth(
                    onPressed: () {
                      popupOrNavigate(context, const AddWidgetPage());
                    },
                    icon: const Icon(Icons.widgets_outlined),
                    child: Text(localizations.addWidgetPageTitle),
                  ),
                  const SizedBox(height: 8),
                  // Show tomorrow setting for widget
                  SwitchListTile(
                    title: Text(localizations.widgetShowTomorrowAfterEnd),
                    value: appConfig.widgetShowTomorrow.value,
                    onChanged: (v) async {
                      appConfig.widgetShowTomorrow.value = v;
                      // Trigger widget update immediately (force)
                      final service = getIt<WidgetUpdateService>();
                      try {
                        await service.updateWidgetData(force: true);
                      } catch (e, st) {
                        debugPrint('WidgetUpdate toggle failed: $e');
                        debugPrint('$st');
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                const Divider(),
                // Other section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.otherSection,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                ButtonWithMaxWidth(
                  onPressed: () {
                    appConfig.backgroundImageOpacity.value = 0.3;
                  },
                  icon: const Icon(Icons.refresh),
                  child: Text(localizations.resetToDefault),
                ),
                const Divider(),
                ButtonWithMaxWidth(
                  onPressed: () async {
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
                  icon: const Icon(Icons.delete, color: Colors.red),
                  child: Text(
                    localizations.clearAllData,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
