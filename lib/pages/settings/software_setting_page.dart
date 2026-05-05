import 'dart:io';

import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/set_dock_page.dart';
import 'package:bugaoshan/pages/settings/set_duration_page.dart';
import 'package:bugaoshan/pages/settings/set_language_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_color_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/common/styled_widget.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/dialog/eula_dialog.dart';
import 'package:bugaoshan/widgets/eula_content.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
        appConfig.courseRowHeight,
        appConfig.backgroundImagePath,
        appConfig.backgroundImageOpacity,
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
                ButtonWithMaxWidth(
                  onPressed: () {
                    popupOrNavigate(context, const SetDockPage());
                  },
                  icon: const Icon(Icons.dock_outlined),
                  child: Text(localizations.customDock),
                ),

                const Divider(),
                // Course card section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.courseCardSection,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
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
                // Background image section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.backgroundImage,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Background image
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ButtonWithMaxWidth(
                      onPressed: () => _pickBackgroundImage(appConfig),
                      icon: const Icon(Icons.wallpaper),
                      child: Text(localizations.setBackgroundImage),
                    ),
                    if (appConfig.backgroundImagePath.value != null) ...[
                      const SizedBox(height: 8),
                      ButtonWithMaxWidth(
                        onPressed: () {
                          final oldPath = appConfig.backgroundImagePath.value;
                          appConfig.backgroundImagePath.value = null;
                          if (oldPath != null) {
                            FileImage(File(oldPath)).evict();
                            File(oldPath).delete().ignore();
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        child: Text(localizations.removeBackgroundImage),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localizations.backgroundImageOpacity,
                                ),
                              ),
                              Text(
                                '${(appConfig.backgroundImageOpacity.value * 100).round()}%',
                              ),
                            ],
                          ),
                          Slider(
                            value: appConfig.backgroundImageOpacity.value,
                            min: 0.05,
                            max: 0.8,
                            divisions: 15,
                            onChanged: (v) =>
                                appConfig.backgroundImageOpacity.value = v,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const Divider(),
                // Course grid section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.courseGridSection,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Show course grid switch
                SwitchListTile(
                  title: Text(localizations.showCourseGrid),
                  value: appConfig.showCourseGrid.value,
                  onChanged: (v) => appConfig.showCourseGrid.value = v,
                  contentPadding: EdgeInsets.zero,
                ),
                // Course row height
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(localizations.courseRowHeight)),
                        Text('${appConfig.courseRowHeight.value.round()}'),
                      ],
                    ),
                    Slider(
                      value: appConfig.courseRowHeight.value,
                      min: 48,
                      max: 120,
                      divisions: 18,
                      onChanged: (v) => appConfig.courseRowHeight.value = v,
                    ),
                  ],
                ),
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
                    appConfig.colorOpacity.value = 0.85;
                    appConfig.courseCardFontSize.value = 14.0;
                    appConfig.showCourseGrid.value = true;
                    appConfig.courseRowHeight.value = 72.0;
                    appConfig.backgroundImageOpacity.value = 0.3;
                  },
                  icon: const Icon(Icons.refresh),
                  child: Text(localizations.resetToDefault),
                ),
                const Divider(),
                ButtonWithMaxWidth(
                  onPressed: () => _revokeEula(context, appConfig, localizations),
                  icon: const Icon(Icons.gavel),
                  child: Text(localizations.revokeEula),
                ),
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

  Future<void> _pickBackgroundImage(AppConfigProvider appConfig) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${appDir.path}/backgrounds');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    final ext = p.extension(picked.path);
    final destPath = '${bgDir.path}/schedule_bg$ext';

    // Delete old background file and evict from image cache
    final oldPath = appConfig.backgroundImagePath.value;
    if (oldPath != null) {
      FileImage(File(oldPath)).evict();
      final oldFile = File(oldPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    await File(picked.path).copy(destPath);
    appConfig.backgroundImageVersion.value++;
    appConfig.backgroundImagePath.value = destPath;
  }

  Future<void> _revokeEula(
    BuildContext context,
    AppConfigProvider appConfig,
    AppLocalizations localizations,
  ) async {
    final confirm = await showYesNoDialog(
      title: localizations.revokeEula,
      content: localizations.revokeEulaConfirm,
    );
    if (confirm == true) {
      appConfig.acceptedEulaVersion.value = 0;
      if (context.mounted) {
        final agreed = await showEulaDialog(context);
        if (agreed && context.mounted) {
          appConfig.acceptedEulaVersion.value = currentEulaVersion;
        }
      }
    }
  }
}
