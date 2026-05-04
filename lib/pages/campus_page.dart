import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/academic_calendar/academic_calendar_page.dart';
import 'package:bugaoshan/pages/campus/balance_query/balance_query_page.dart';
import 'package:bugaoshan/pages/campus/classroom/classroom_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_page.dart';
import 'package:bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
import 'package:bugaoshan/pages/campus/network_device/network_device_page.dart';
import 'package:bugaoshan/pages/campus/train_program/train_program_page.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class CampusPage extends StatefulWidget {
  const CampusPage({super.key});

  @override
  State<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends State<CampusPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowController;
  late final Animation<double> _arrowAnimation;
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _arrowAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels > 40 && _showHint) {
      setState(() => _showHint = false);
    } else if (notification.metrics.pixels <= 40 && !_showHint) {
      setState(() => _showHint = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWeb = kIsWeb;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onScroll(notification);
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    _SectionHeader(title: l10n.academicSection),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.bar_chart_outlined,
                      title: l10n.gradesStats,
                      desc: l10n.gradesStatsDesc,
                      appOnly: false,
                      onTap: () =>
                          popupOrNavigate(logicRootContext, const GradesPage()),
                    ),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.event_outlined,
                      title: l10n.ccylTitle,
                      desc: l10n.ccylDesc,
                      appOnly: false,
                      onTap: () =>
                          popupOrNavigate(logicRootContext, const CcylPage()),
                    ),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.assignment_turned_in_outlined,
                      title: l10n.planCompletion,
                      desc: l10n.planCompletionDesc,
                      appOnly: false,
                      onTap: () => popupOrNavigate(
                        logicRootContext,
                        const PlanCompletionPage(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: l10n.utilitiesSection),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.school_outlined,
                      title: l10n.trainProgram,
                      desc: l10n.trainProgramDesc,
                      appOnly: false,
                      onTap: () => popupOrNavigate(
                        logicRootContext,
                        const TrainProgramPage(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.meeting_room_outlined,
                      title: l10n.classroomQuery,
                      desc: l10n.classroomQueryDesc,
                      appOnly: isWeb,
                      onTap: isWeb
                          ? null
                          : () => popupOrNavigate(
                              logicRootContext,
                              const ClassroomPage(),
                            ),
                    ),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.router_outlined,
                      title: l10n.networkDeviceQuery,
                      desc: l10n.networkDeviceQueryDesc,
                      appOnly: false,
                      onTap: () => popupOrNavigate(
                        logicRootContext,
                        const NetworkDevicePage(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: l10n.balanceQuery,
                      desc: l10n.balanceQueryDesc,
                      appOnly: false,
                      onTap: () => popupOrNavigate(
                        logicRootContext,
                        const BalanceQueryPage(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CampusCard(
                      icon: Icons.calendar_month_outlined,
                      title: l10n.academicCalendar,
                      desc: l10n.academicCalendarDesc,
                      appOnly: false,
                      onTap: () => popupOrNavigate(
                        logicRootContext,
                        const AcademicCalendarPage(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _MoreFeaturesCard(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showHint ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColor.withValues(alpha: 0),
                      bgColor.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _arrowAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _arrowAnimation.value),
                    child: child,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    size: 28,
                  ),
                ),
              ),
            ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
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
