import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/course/course_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

class SetCourseStylePage extends StatelessWidget {
  const SetCourseStylePage({super.key});

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
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(localizations.courseStyleSetting)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Column(
              spacing: 16,
              children: [
                // Preview section
                SizedBox(
                  height: 400,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: const CoursePage(demoMode: true),
                  ),
                ),
                ..._buildSettings(context, localizations, appConfig),
              ],
            ),
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
      // Reset to default
      Align(
        alignment: Alignment.center,
        child: TextButton.icon(
          onPressed: () {
            appConfig.colorOpacity.value = 0.85;
            appConfig.courseCardFontSize.value = 14.0;
            appConfig.showCourseGrid.value = true;
            appConfig.courseRowHeight.value = 72.0;
          },
          icon: const Icon(Icons.refresh),
          label: Text(localizations.resetToDefault),
        ),
      ),
    ];
  }
}
