import 'package:flutter/material.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/models/course.dart';
import 'package:Bugaoshan/providers/app_config_provider.dart';

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
        final details = <({IconData icon, String text, int preferredMaxLines})>[
          if (config.showLocation && course.location.isNotEmpty)
            (
              icon: Icons.location_on_outlined,
              text: course.location,
              preferredMaxLines: 2,
            ),
          if (config.showTeacherName && course.teacher.isNotEmpty)
            (
              icon: Icons.person_outline,
              text: course.teacher,
              preferredMaxLines: 1,
            ),
          (
            icon: Icons.calendar_today_outlined,
            text: '${course.startWeek}-${course.endWeek}${l10n.week}',
            preferredMaxLines: 1,
          ),
        ];

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final detailLineBudget = switch (height) {
                < 56 => 0,
                < 100 => 2,
                _ => 4,
              };
              final visibleDetails =
                  <({IconData icon, String text, int preferredMaxLines})>[];
              var usedDetailLines = 0;
              for (final detail in details) {
                final nextUsedLines =
                    usedDetailLines + detail.preferredMaxLines;
                if (nextUsedLines > detailLineBudget) {
                  continue;
                }
                visibleDetails.add(detail);
                usedDetailLines = nextUsedLines;
              }
              final titleMaxLines = 6;

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
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isActive
                                ? course.name
                                : '${l10n.notThisWeek} ${course.name}',
                            maxLines: titleMaxLines,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: textColor,
                              height: 1.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (visibleDetails.isNotEmpty)
                            const SizedBox(height: 2),
                          ...visibleDetails.map(
                            (detail) => _buildIconText(
                              detail.icon,
                              detail.text,
                              smallFontSize,
                              textColor,
                              maxLines: detail.preferredMaxLines,
                            ),
                          ),
                        ],
                      ),
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
    Color color, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: fontSize,
          color: color.withAlpha(230),
          height: 1.1,
        ),
      ),
    );
  }
}
