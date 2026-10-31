import 'dart:async';
import 'dart:io';

import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/course/main/course_page.dart';
import 'package:bugaoshan/pages/settings/background_crop_editor_page.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/widgets/common/styled_widget.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/providers/set_theme_color_provider.dart';
import 'package:bugaoshan/utils/system_insets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:system_theme/system_theme.dart';

class SetCourseStylePage extends ConsumerWidget {
  const SetCourseStylePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final bgPath = ref.watch(backgroundImagePathSettingProvider);

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
                      key: ValueKey(bgPath ?? '__none__'),
                      demoMode: true,
                    ),
                  ),
                ),
              ),
              // Settings section
              Expanded(
                child: SingleChildScrollView(
                  padding: withSystemBottomInset(
                    context,
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  child: Column(
                    spacing: 16,
                    children: _buildSettings(context, ref, localizations),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSettings(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations localizations,
  ) {
    final colorOpacity = ref.watch(colorOpacitySettingProvider);
    final fontSize = ref.watch(courseCardFontSizeSettingProvider);
    final showCourseGrid = ref.watch(showCourseGridSettingProvider);
    final rowHeight = ref.watch(courseRowHeightSettingProvider);
    final showTeacher = ref.watch(showTeacherNameSettingProvider);
    final showLocation = ref.watch(showLocationSettingProvider);
    final showCourseWeeks = ref.watch(showCourseWeeksSettingProvider);
    final showWeekend = ref.watch(showWeekendSettingProvider);
    final showNonCurrent = ref.watch(showNonCurrentWeekCoursesSettingProvider);
    final bgPath = ref.watch(backgroundImagePathSettingProvider);
    final bgOpacity = ref.watch(backgroundImageOpacitySettingProvider);

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
              Text('${(colorOpacity * 100).round()}%'),
            ],
          ),
          AdaptiveGlassSlider(
            semanticLabel: localizations.colorOpacity,
            value: colorOpacity,
            min: 0.3,
            max: 1.0,
            divisions: 14,
            onChanged: (v) =>
                ref.read(colorOpacitySettingProvider.notifier).update(v),
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
              Text('${fontSize.round()}'),
            ],
          ),
          AdaptiveGlassSlider(
            semanticLabel: localizations.fontSize,
            value: fontSize,
            min: 8,
            max: 20,
            divisions: 12,
            onChanged: (v) =>
                ref.read(courseCardFontSizeSettingProvider.notifier).update(v),
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
      AdaptiveGlassSwitchListTile(
        title: Text(localizations.showCourseGrid),
        value: showCourseGrid,
        onChanged: (v) =>
            ref.read(showCourseGridSettingProvider.notifier).update(v),
        contentPadding: EdgeInsets.zero,
      ),
      // Course row height
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(localizations.courseRowHeight)),
              Text('${rowHeight.round()}'),
            ],
          ),
          AdaptiveGlassSlider(
            semanticLabel: localizations.courseRowHeight,
            value: rowHeight,
            min: 48,
            max: 120,
            divisions: 18,
            onChanged: (v) =>
                ref.read(courseRowHeightSettingProvider.notifier).update(v),
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
      AdaptiveGlassSwitchListTile(
        title: Text(localizations.showTeacher),
        value: showTeacher,
        onChanged: (v) =>
            ref.read(showTeacherNameSettingProvider.notifier).update(v),
        contentPadding: EdgeInsets.zero,
      ),
      AdaptiveGlassSwitchListTile(
        title: Text(localizations.showLocation),
        value: showLocation,
        onChanged: (v) =>
            ref.read(showLocationSettingProvider.notifier).update(v),
        contentPadding: EdgeInsets.zero,
      ),
      AdaptiveGlassSwitchListTile(
        title: Text(localizations.showCourseWeeks),
        value: showCourseWeeks,
        onChanged: (v) =>
            ref.read(showCourseWeeksSettingProvider.notifier).update(v),
        contentPadding: EdgeInsets.zero,
      ),
      AdaptiveGlassSwitchListTile(
        title: Text(localizations.showWeekend),
        value: showWeekend,
        onChanged: (v) =>
            ref.read(showWeekendSettingProvider.notifier).update(v),
        contentPadding: EdgeInsets.zero,
      ),
      AdaptiveGlassSwitchListTile(
        title: Text(localizations.showNonCurrentWeekCourses),
        value: showNonCurrent,
        onChanged: (v) =>
            ref.read(showNonCurrentWeekCoursesSettingProvider.notifier).update(v),
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
            onPressed: () => _pickBackgroundImage(context, ref),
            icon: const Icon(Icons.wallpaper),
            child: Text(localizations.setBackgroundImage),
          ),
          if (bgPath != null) ...[
            const SizedBox(height: 8),
            ButtonWithMaxWidth(
              onPressed: () => _editBackgroundCrop(context, ref),
              icon: const Icon(Icons.crop_free),
              child: Text(localizations.editBackgroundArea),
            ),
            const SizedBox(height: 8),
            ButtonWithMaxWidth(
              onPressed: () => _removeBackgroundImage(ref),
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
                    Text('${(bgOpacity * 100).round()}%'),
                  ],
                ),
                AdaptiveGlassSlider(
                  semanticLabel: localizations.backgroundImageOpacity,
                  value: bgOpacity,
                  min: 0.05,
                  max: 0.8,
                  divisions: 15,
                  onChanged: (v) =>
                      ref.read(backgroundImageOpacitySettingProvider.notifier).update(v),
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
            ref.read(colorOpacitySettingProvider.notifier).update(0.85);
            ref.read(courseCardFontSizeSettingProvider.notifier).update(14.0);
            ref.read(showCourseGridSettingProvider.notifier).update(true);
            ref.read(courseRowHeightSettingProvider.notifier).update(72.0);
            ref.read(backgroundImageOpacitySettingProvider.notifier).update(0.3);
            ref.read(showTeacherNameSettingProvider.notifier).update(true);
            ref.read(showLocationSettingProvider.notifier).update(true);
            ref.read(showCourseWeeksSettingProvider.notifier).update(true);
            ref.read(showWeekendSettingProvider.notifier).update(false);
            ref.read(showNonCurrentWeekCoursesSettingProvider.notifier).update(true);
          },
          icon: const Icon(Icons.refresh),
          label: Text(localizations.resetToDefault),
        ),
      ),
    ];
  }

  Future<void> _removeBackgroundImage(WidgetRef ref) async {
    final oldPath = ref.read(backgroundImagePathSettingProvider);
    ref.read(backgroundImagePathSettingProvider.notifier).update(null);
    ref.read(backgroundImageCropSettingProvider.notifier).update(null);
    if (oldPath != null) {
      unawaited(FileImage(File(oldPath)).evict());
      File(oldPath).delete().ignore();
    }
    if (ref.read(themeColorModeSettingProvider) == ThemeColorMode.backgroundImage) {
      await SystemTheme.accentColor.load();
      ref.read(themeColorSettingProvider.notifier).update(SystemTheme.accentColor.accent);
    }
  }

  Future<void> _editBackgroundCrop(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final path = ref.read(backgroundImagePathSettingProvider);
    if (path == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BackgroundCropEditorPage(imagePath: path),
      ),
    );
  }

  Future<void> _pickBackgroundImage(
    BuildContext context,
    WidgetRef ref,
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

    final oldPath = ref.read(backgroundImagePathSettingProvider);
    if (oldPath != null) {
      unawaited(FileImage(File(oldPath)).evict());
      final oldFile = File(oldPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    await File(picked.path).copy(destPath);
    ref.read(backgroundImagePathSettingProvider.notifier).update(destPath);
    ref.read(backgroundImageCropSettingProvider.notifier).update(null);

    final mode = ref.read(themeColorModeSettingProvider);
    if (mode == ThemeColorMode.backgroundImage) {
      final themeColorProvider = SetThemeColorProvider(
        getBackgroundImagePath: () => destPath,
        getThemeColorMode: () => mode,
        getThemeColor: () => ref.read(themeColorSettingProvider),
      );
      final result = await themeColorProvider.extractColorFromBackgroundImage();
      if (result == ExtractColorResult.success &&
          themeColorProvider.extractedColor != null) {
        ref.read(themeColorSettingProvider.notifier).update(themeColorProvider.extractedColor!);
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BackgroundCropEditorPage(imagePath: destPath),
      ),
    );

    if (!context.mounted) return;
    if (mode != ThemeColorMode.backgroundImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.backgroundImageSetHint),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
