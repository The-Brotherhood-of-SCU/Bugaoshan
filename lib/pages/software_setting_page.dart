import 'package:flutter/material.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/pages/set_duration_page.dart';
import 'package:Bugaoshan/pages/set_language_page.dart';
import 'package:Bugaoshan/pages/set_theme_color_page.dart';
import 'package:Bugaoshan/providers/app_config_provider.dart';
import 'package:Bugaoshan/providers/course_provider.dart';
import 'package:Bugaoshan/widgets/common/styled_widget.dart';
import 'package:Bugaoshan/widgets/dialog/dialog.dart';
import 'package:Bugaoshan/widgets/route/router_utils.dart';

class SoftwareSettingPage extends StatelessWidget {
  const SoftwareSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();

    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfig.colorOpacity,
        appConfig.courseCardFontSize,
        appConfig.showCourseGrid,
      ]),
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

                const Divider(),
                // Color opacity
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(localizations.colorOpacity)),
                        Text(
                          '${(appConfig.colorOpacity.value * 100).round()}%',
                        ),
                      ],
                    ),
                    Slider(
                      value: appConfig.colorOpacity.value,
                      min: 0.3,
                      max: 1.0,
                      divisions: 14,
                      onChanged: (v) => appConfig.colorOpacity.value = v,
                    ),
                  ],
                ),
                // Font size
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(localizations.fontSize)),
                        Text('${appConfig.courseCardFontSize.value.round()}'),
                      ],
                    ),
                    Slider(
                      value: appConfig.courseCardFontSize.value,
                      min: 8,
                      max: 20,
                      divisions: 12,
                      onChanged: (v) => appConfig.courseCardFontSize.value = v,
                    ),
                  ],
                ),
                const Divider(),
                // Show course grid switch
                SwitchListTile(
                  title: Text(localizations.showCourseGrid),
                  value: appConfig.showCourseGrid.value,
                  onChanged: (v) => appConfig.showCourseGrid.value = v,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),

                ButtonWithMaxWidth(
                  onPressed: () async {
                    final confirm = await showYesNoDialog(
                      title: localizations.clearAllData,
                      content: localizations.confirmMessage,
                    );
                    if (confirm == true) {
                      appConfig.clearAll();
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
