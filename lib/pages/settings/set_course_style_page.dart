import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/course/main/course_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/common/styled_widget.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/providers/set_theme_color_provider.dart';
import 'package:bugaoshan/models/background_image_crop.dart';
import 'package:bugaoshan/pages/settings/background_image_crop_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:system_theme/system_theme.dart';

class SetCourseStylePage extends StatelessWidget {
  const SetCourseStylePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();

    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfig.backgroundImagePath,
        appConfig.backgroundImageOpacity,
        appConfig.colorOpacity,
        appConfig.courseCardFontSize,
        appConfig.showCourseGrid,
        appConfig.courseRowHeight,
        appConfig.showTeacherName,
        appConfig.showLocation,
        appConfig.showWeekend,
        appConfig.showNonCurrentWeekCourses,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(localizations.courseStyleSetting)),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight = (constraints.maxHeight * 0.5).clamp(
                200.0,
                400.0,
              );
              return Column(
                children: [
                  // Preview section
                  SizedBox(
                    height: previewHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppShapes.medium),
                        child: CoursePage(
                          key: ValueKey(
                            appConfig.backgroundImagePath.value ?? '__none__',
                          ),
                          demoMode: true,
                        ),
                      ),
                    ),
                  ),
                  // Settings section
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        spacing: 16,
                        children: _buildSettings(
                          context,
                          localizations,
                          appConfig,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildSettings(
    BuildContext context,
    AppLocalizations localizations,
    AppConfigProvider appConfig,
  ) {
    return [
      const Divider(),
      // Course card settings
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
        spacing: 4,
        children: [
          Row(
            children: [
              Expanded(child: Text(localizations.colorOpacity)),
              Text('${(appConfig.colorOpacity.value * 100).round()}%'),
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
      // Course grid settings
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
      // Display settings
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          localizations.displaySetting,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      SwitchListTile(
        title: Text(localizations.showTeacher),
        value: appConfig.showTeacherName.value,
        onChanged: (v) => appConfig.showTeacherName.value = v,
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        title: Text(localizations.showLocation),
        value: appConfig.showLocation.value,
        onChanged: (v) => appConfig.showLocation.value = v,
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        title: Text(localizations.showWeekend),
        value: appConfig.showWeekend.value,
        onChanged: (v) => appConfig.showWeekend.value = v,
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        title: Text(localizations.showNonCurrentWeekCourses),
        value: appConfig.showNonCurrentWeekCourses.value,
        onChanged: (v) => appConfig.showNonCurrentWeekCourses.value = v,
        contentPadding: EdgeInsets.zero,
      ),
      const Divider(),
      // Background image settings
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
          if (appConfig.backgroundImagePath.value != null) ...[
            const SizedBox(height: 8),
            ButtonWithMaxWidth(
              onPressed: () => _editBackgroundImageCrop(context, appConfig),
              icon: const Icon(Icons.crop_free),
              child: Text(localizations.editBackgroundImageCrop),
            ),
            const SizedBox(height: 8),
            ButtonWithMaxWidth(
              onPressed: () => _removeBackgroundImage(appConfig),
              icon: const Icon(Icons.delete_outline),
              child: Text(localizations.removeBackgroundImage),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(localizations.backgroundImageOpacity)),
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
                  onChanged: (v) => appConfig.backgroundImageOpacity.value = v,
                ),
              ],
            ),
          ],
        ],
      ),
      const Divider(),
      // Reset to default
      Align(
        alignment: Alignment.center,
        child: TextButton.icon(
          onPressed: () {
            appConfig.colorOpacity.value = 0.85;
            appConfig.courseCardFontSize.value = 14.0;
            appConfig.showCourseGrid.value = true;
            appConfig.courseRowHeight.value = 72.0;
            appConfig.backgroundImageOpacity.value = 0.3;
            appConfig.showTeacherName.value = true;
            appConfig.showLocation.value = true;
            appConfig.showWeekend.value = false;
            appConfig.showNonCurrentWeekCourses.value = true;
          },
          icon: const Icon(Icons.refresh),
          label: Text(localizations.resetToDefault),
        ),
      ),
    ];
  }

  Future<void> _removeBackgroundImage(AppConfigProvider appConfig) async {
    final oldPath = appConfig.backgroundImagePath.value;
    appConfig.backgroundImagePath.value = null;
    if (oldPath != null) {
      FileImage(File(oldPath)).evict();
      File(oldPath).delete().ignore();
    }
    if (appConfig.themeColorMode.value == ThemeColorMode.backgroundImage) {
      await SystemTheme.accentColor.load();
      appConfig.themeColor.value = SystemTheme.accentColor.accent;
    }
  }

  Future<void> _editBackgroundImageCrop(
    BuildContext context,
    AppConfigProvider appConfig,
  ) async {
    final path = appConfig.backgroundImagePath.value;
    if (path == null) return;
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<BackgroundImageCrop>(
      MaterialPageRoute(
        builder: (_) => BackgroundImageCropEditor(
          imagePath: path,
          initialCrop: appConfig.backgroundImageCrop.value,
        ),
      ),
    );
    if (result == null) return;
    appConfig.backgroundImageCrop.value = result;
    if (!context.mounted) return;
    await _maybeExtractColor(context, appConfig);
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

    if (!context.mounted) return;
    // 选图后进入裁剪编辑器；保存时才写入路径与裁剪参数。
    final crop = await Navigator.of(context).push<BackgroundImageCrop>(
      MaterialPageRoute(
        builder: (_) => BackgroundImageCropEditor(imagePath: destPath),
      ),
    );
    if (crop == null) {
      // 用户取消裁剪：不设置新背景图，清理刚复制的临时文件。
      FileImage(File(destPath)).evict();
      if (await File(destPath).exists()) {
        await File(destPath).delete();
      }
      return;
    }

    // 替换图片时清除旧裁剪参数（新图重新编辑）。
    appConfig.backgroundImageCrop.value = null;
    appConfig.backgroundImagePath.value = destPath;
    appConfig.backgroundImageCrop.value = crop;

    if (!context.mounted) return;
    await _maybeExtractColor(context, appConfig);
  }

  /// 设置/调整背景图后，若主题色模式为「从背景图提取」则重新取色。
  Future<void> _maybeExtractColor(
    BuildContext context,
    AppConfigProvider appConfig,
  ) async {
    if (appConfig.themeColorMode.value != ThemeColorMode.backgroundImage) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.backgroundImageSetHint),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    final themeColorProvider = SetThemeColorProvider(appConfig);
    final result = await themeColorProvider.extractColorFromBackgroundImage();
    if (result == ExtractColorResult.success &&
        themeColorProvider.extractedColor != null) {
      appConfig.themeColor.value = themeColorProvider.extractedColor!;
    }
  }
}
