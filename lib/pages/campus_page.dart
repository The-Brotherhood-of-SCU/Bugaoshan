import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/pages/campus/classroom/classroom_page.dart';
import 'package:Bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:Bugaoshan/pages/campus/train_program/train_program_page.dart';
import 'package:Bugaoshan/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class CampusPage extends StatelessWidget {
  const CampusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWeb = kIsWeb;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(title: Text(l10n.campus)),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              _CampusCard(
                icon: Icons.meeting_room_outlined,
                title: l10n.classroomQuery,
                desc: l10n.classroomQueryDesc,
                appOnly: isWeb,
                onTap: isWeb
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClassroomPage(),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              _CampusCard(
                icon: Icons.bar_chart_outlined,
                title: l10n.gradesStats,
                desc: l10n.gradesStatsDesc,
                appOnly: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GradesPage()),
                ),
              ),
              const SizedBox(height: 8),
              _CampusCard(
                icon: Icons.school_outlined,
                title: l10n.trainProgram,
                desc: l10n.trainProgramDesc,
                appOnly: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrainProgramPage()),
                ),
              ),
              const SizedBox(height: 8),
              _MoreFeaturesCard(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CampusCard extends StatelessWidget {
  const _CampusCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.appOnly,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool appOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disabled = appOnly;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: disabled
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: disabled
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: disabled
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (disabled) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.appOnly,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                disabled ? Icons.block : Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreFeaturesCard extends StatelessWidget {
  const _MoreFeaturesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse('$appLink/issues/new?template=feature_request.yml'),
          mode: LaunchMode.externalApplication,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_comment_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.moreFeaturesTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.moreFeaturesDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
