// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/add_widget/add_widget_page.dart';
import 'package:bugaoshan/pages/settings/set_dock_page.dart';
import 'package:bugaoshan/pages/settings/set_duration_page.dart';
import 'package:bugaoshan/pages/settings/set_language_page.dart';
import 'package:bugaoshan/pages/settings/set_theme_color_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/common/styled_widget.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/providers/set_theme_color_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:math' as math;
import 'package:image/image.dart' as img;
// 'dart:typed_data' not needed; Flutter's foundation provides Uint8List
import 'package:flutter/foundation.dart';
import 'package:system_theme/system_theme.dart';

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
        appConfig.widgetShowTomorrow,
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
                      onPressed: () => _pickBackgroundImage(context, appConfig),
                      icon: const Icon(Icons.wallpaper),
                      child: Text(localizations.setBackgroundImage),
                    ),
                    FutureBuilder<bool>(
                      future: () async {
                        final path = appConfig.backgroundImagePath.value;
                        if (path == null) return false;
                        try {
                          return await File(path).exists();
                        } catch (_) {
                          return false;
                        }
                      }(),
                      builder: (context, snapshot) {
                        final exists = snapshot.data == true;
                        if (!exists) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ButtonWithMaxWidth(
                              onPressed: () async {
                                final oldPath =
                                    appConfig.backgroundImagePath.value;
                                appConfig.backgroundImagePath.value = null;
                                if (oldPath != null) {
                                  FileImage(File(oldPath)).evict();
                                  File(oldPath).delete().ignore();
                                }
                                if (appConfig.themeColorMode.value ==
                                    ThemeColorMode.backgroundImage) {
                                  await SystemTheme.accentColor.load();
                                  appConfig.themeColor.value =
                                      SystemTheme.accentColor.accent;
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
                                      appConfig.backgroundImageOpacity.value =
                                          v,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
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

  Future<void> _pickBackgroundImage(
    BuildContext context,
    AppConfigProvider appConfig,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${appDir.path}/backgrounds');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    final ext = p.extension(picked.path).toLowerCase();
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

    try {
      final mq = MediaQuery.of(logicRootContext);
      final maxW = (mq.size.width * mq.devicePixelRatio).round();
      final maxH = (mq.size.height * mq.devicePixelRatio).round();
      final bytes = await picked.readAsBytes();

      final compress = await showYesNoDialog(
        context: logicRootContext,
        title: AppLocalizations.of(
          logicRootContext,
        )!.backgroundImageCompressTitle,
        content: AppLocalizations.of(
          logicRootContext,
        )!.backgroundImageCompressContent,
      );

      if (!logicRootContext.mounted) return;

      if (compress == true) {
        try {
          final outBytes = await compute(_resizeImageIsolate, {
            'bytes': bytes,
            'ext': ext,
            'maxW': maxW,
            'maxH': maxH,
          });
          if (outBytes.isEmpty) {
            await File(picked.path).copy(destPath);
          } else {
            await File(destPath).writeAsBytes(outBytes, flush: true);
          }
          if (!logicRootContext.mounted) return;
          ScaffoldMessenger.of(logicRootContext).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  logicRootContext,
                )!.backgroundImageCompressedSnackbar,
              ),
            ),
          );
        } catch (e) {
          debugPrint('Background image resize failed: $e');
          await File(picked.path).copy(destPath);
        }
      } else {
        await File(picked.path).copy(destPath);
      }
    } catch (e) {
      debugPrint('Background image handling failed: $e');
      await File(picked.path).copy(destPath);
    }
    appConfig.backgroundImagePath.value = destPath;

    if (appConfig.themeColorMode.value == ThemeColorMode.backgroundImage) {
      final themeColorProvider = SetThemeColorProvider(appConfig);
      final result = await themeColorProvider.extractColorFromBackgroundImage();
      if (result == ExtractColorResult.success &&
          themeColorProvider.extractedColor != null) {
        appConfig.themeColor.value = themeColorProvider.extractedColor!;
      }
    }

    if (!logicRootContext.mounted) return;
    if (appConfig.themeColorMode.value != ThemeColorMode.backgroundImage) {
      ScaffoldMessenger.of(logicRootContext).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(logicRootContext)!.backgroundImageSetHint,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// Runs in a separate isolate. Expects a Map with keys: 'bytes' (List<int>),
// 'ext' (String), 'maxW' (int), 'maxH' (int). Returns encoded image bytes.
List<int> _resizeImageIsolate(Map<String, dynamic> params) {
  final bytes = params['bytes'] as List<int>;
  final ext = params['ext'] as String? ?? '.jpg';
  final maxW = params['maxW'] as int? ?? 1920;
  final maxH = params['maxH'] as int? ?? 1080;

  final src = img.decodeImage(Uint8List.fromList(bytes));
  if (src == null) return bytes;

  int targetW = src.width;
  int targetH = src.height;
  if (src.width > maxW || src.height > maxH) {
    final scale = math.min(maxW / src.width, maxH / src.height);
    targetW = math.max(1, (src.width * scale).round());
    targetH = math.max(1, (src.height * scale).round());
  }

  final resized = img.copyResize(src, width: targetW, height: targetH);
  if (ext == '.png') {
    return img.encodePng(resized);
  } else {
    return img.encodeJpg(resized, quality: 88);
  }
}
