import 'package:flutter/material.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/providers/app_config_provider.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final ScheduleConfig config;
  final int displayWeek;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CourseCard({
    super.key,
    required this.course,
    required this.config,
    required this.displayWeek,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appConfig = getIt<AppConfigProvider>();
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfig.colorOpacity,
        appConfig.courseCardFontSize,
      ]),
      builder: (context, _) {
        final isActive = course.isActiveInWeek(displayWeek);
        final color = course.color.withValues(
          alpha: isActive
              ? appConfig.colorOpacity.value
              : appConfig.colorOpacity.value * 0.2,
        );
        const textColor = Colors.white;
        final fontSize = appConfig.courseCardFontSize.value;
        final smallFontSize = fontSize - 1;
        final details = <({IconData icon, String text})>[
          if (config.showLocation && course.location.isNotEmpty)
            (icon: Icons.location_on_outlined, text: course.location),
          if (config.showTeacherName && course.teacher.isNotEmpty)
            (icon: Icons.person_outline, text: course.teacher),
          (
            icon: Icons.calendar_today_outlined,
            text: '${course.startWeek}-${course.endWeek}${l10n.week}',
          ),
        ];

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final maxDetailCount = switch (height) {
                < 56 => 0,
                < 78 => 1,
                < 100 => 2,
                _ => 3,
              };
              final visibleDetails = details.take(maxDetailCount).toList();
              final titleMaxLines = maxDetailCount == 0 ? 3 : 2;

              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    border: isActive
                        ? null
                        : Border.all(
                            color: textColor.withAlpha(50),
                            width: 0.5,
                          ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: SizedBox.expand(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActive
                              ? course.name
                              : '${l10n.notThisWeek} ${course.name}',
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.1,
                          ),
                        ),
                        if (visibleDetails.isNotEmpty) const SizedBox(height: 2),
                        ...visibleDetails.map(
                          (detail) => _buildIconText(
                            detail.icon,
                            detail.text,
                            smallFontSize,
                            textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIconText(
    IconData icon,
    String text,
    double fontSize,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: fontSize, color: color.withAlpha(200)),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                color: color.withAlpha(230),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
