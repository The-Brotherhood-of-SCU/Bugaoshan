import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/pages/campus/fitness_test/models/fitness_models.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/fitness_test_pods.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/common/swipe_page_view.dart';
import 'package:bugaoshan/utils/system_insets.dart';

class FitnessTestPage extends ConsumerStatefulWidget {
  const FitnessTestPage({super.key});

  @override
  ConsumerState<FitnessTestPage> createState() => _FitnessTestPageState();
}

class _FitnessTestPageState extends ConsumerState<FitnessTestPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _privacyHidden = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(scuAuthProviderBridge);

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.fitnessTest)),
        body: auth.isAutoLoggingIn
            ? const AutoLoginLoadingWidget()
            : const LoginRequiredWidget(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fitnessTest),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.fitnessTestScores),
            Tab(text: l10n.fitnessTestNotices),
          ],
        ),
      ),
      body: SwipePageView(
        tabController: _tabController,
        keepPagesAlive: true,
        children: [_buildScoresTab(l10n), _buildNoticesTab(l10n)],
      ),
    );
  }

  // ==================== Notices Tab ====================

  Widget _buildNoticesTab(AppLocalizations l10n) {
    final asyncNotices = ref.watch(fitnessNoticesProvider);

    return asyncNotices.when(
      data: (notices) {
        if (notices.isEmpty) {
          return Center(
            child: Text(
              l10n.noData,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(fitnessNoticesProvider.future),
          child: ListView.builder(
            padding: withSystemBottomInset(context, EdgeInsets.all(16)),
            itemCount: notices.length,
            itemBuilder: (context, index) => _buildNoticeCard(notices[index], l10n),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildError(
        error,
        () => ref.refresh(fitnessNoticesProvider.future),
      ),
    );
  }

  Widget _buildError(Object error, Future<void> Function() onRetry) {
    final effectiveError = () {
      if (error is UnauthenticatedException) return LoadErrorType.sessionExpired;
      if (error is ServiceException) return error.message;
      return campusNetworkErrorType(LoadErrorType.networkError);
    }();
    if (effectiveError is LoadErrorType) {
      return RetryableErrorWidget(errorType: effectiveError, onRetry: onRetry);
    }
    return RetryableErrorWidget.message(
      message: effectiveError.toString(),
      onRetry: onRetry,
    );
  }

  Widget _buildNoticeCard(FitnessNotice notice, AppLocalizations l10n) {
    return StyledCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _showNoticeDetail(notice, l10n),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (notice.isSticky) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppShapes.xs),
                    ),
                    child: Text(
                      l10n.fitnessTestSticky,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    notice.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  notice.createTime,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${notice.readNum} ${l10n.fitnessTestReadCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDetail(FitnessNotice notice, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      notice.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: withSystemBottomInset(context, EdgeInsets.all(16)),
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notice.createTime,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${notice.readNum} ${l10n.fitnessTestReadCount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    notice.plainContent,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Scores Tab ====================

  Widget _buildScoresTab(AppLocalizations l10n) {
    final currentYear = DateTime.now().year;
    final years = List.generate(9, (i) => currentYear - i);
    final selectedYear = ref.watch(fitnessSelectedYearProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(fitnessScoreDataProvider(selectedYear).future),
      child: ListView(
        padding: withSystemBottomInset(context, EdgeInsets.all(16)),
        children: [
          // Year selector
          StyledCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    l10n.fitnessTestYear,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  DropdownButton<int>(
                    value: selectedYear,
                    underline: const SizedBox(),
                    // 桌面端收起菜单后按钮仍持有焦点，默认 focusColor 会留下一块
                    // 常驻灰底；这里将其去掉（悬停高亮保留，可正常随鼠标移出消失）。
                    focusColor: Colors.transparent,
                    items: years
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != selectedYear) {
                        ref.read(fitnessSelectedYearProvider.notifier).selectYear(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Score content
          _buildScoreContent(selectedYear, l10n),
        ],
      ),
    );
  }

  Widget _buildScoreContent(int selectedYear, AppLocalizations l10n) {
    final asyncScore = ref.watch(fitnessScoreDataProvider(selectedYear));

    return asyncScore.when(
      data: (score) {
        if (score == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.fitnessTestNoScore,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            _buildTotalScoreCard(score, l10n),
            const SizedBox(height: 16),
            _buildInfoCard(score, l10n),
            const SizedBox(height: 16),
            _buildScoreItemsCard(score, l10n),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: _buildError(
          error,
          () => ref.refresh(fitnessScoreDataProvider(selectedYear).future),
        ),
      ),
    );
  }

  Widget _buildTotalScoreCard(FitnessScore score, AppLocalizations l10n) {
    final gradeColor = score.gradeColorFor(context);

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: gradeColor, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                '${score.totalScore}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fitnessTestTotalScore,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppShapes.medium),
                    ),
                    child: Text(
                      score.totalGrade,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: gradeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskText(String text, {int visibleStart = 1, int visibleEnd = 0}) {
    if (text.length <= visibleStart + visibleEnd) return '*' * text.length;
    final start = text.substring(0, visibleStart);
    final end = visibleEnd > 0 ? text.substring(text.length - visibleEnd) : '';
    final masked = '*' * (text.length - visibleStart - visibleEnd);
    return '$start$masked$end';
  }

  Widget _buildInfoCard(FitnessScore score, AppLocalizations l10n) {

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _privacyHidden = !_privacyHidden),
              child: _infoRow(
                l10n.fitnessTestStudentName,
                _privacyHidden
                    ? _maskText(score.studentName)
                    : score.studentName,
                trailing: Icon(
                  _privacyHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _privacyHidden = !_privacyHidden),
              child: _infoRow(
                l10n.fitnessTestStudentNum,
                _privacyHidden
                    ? _maskText(
                        score.studentNum,
                        visibleStart: 2,
                        visibleEnd: 2,
                      )
                    : score.studentNum,
                trailing: Icon(
                  _privacyHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _infoRow(l10n.fitnessTestSex, score.sex),
            _infoRow(l10n.fitnessTestStudentYear, score.studentYear),
            _infoRow(l10n.fitnessTestReportType, score.reportType),
            _infoRow(l10n.fitnessTestReportStatus, score.reportStatus),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return InfoRow(label: label, value: value, trailing: trailing);
  }

  Widget _buildScoreItemsCard(FitnessScore score, AppLocalizations l10n) {
    final items = [
      _ScoreItem(
        icon: Icons.monitor_weight_outlined,
        label: l10n.fitnessTestBmi,
        data: score.bmi,
        rawScoreDisplay: score.bmi.rawScore,
      ),
      _ScoreItem(
        icon: Icons.air,
        label: l10n.fitnessTestVitalCapacity,
        data: score.vitalCapacity,
        rawScoreDisplay: score.vitalCapacity.rawScore,
      ),
      _ScoreItem(
        icon: Icons.directions_run,
        label: l10n.fitnessTestStandingLongJump,
        data: score.jump,
        rawScoreDisplay: '${score.jump.rawScore} cm',
      ),
      _ScoreItem(
        icon: Icons.accessibility_new,
        label: l10n.fitnessTestSitAndReach,
        data: score.sitAndReach,
        rawScoreDisplay: '${score.sitAndReach.rawScore} cm',
      ),
      _ScoreItem(
        icon: Icons.fitness_center,
        label: score.sex == '女'
            ? l10n.fitnessTestSitUp
            : l10n.fitnessTestPullUp,
        data: score.pullAndSit,
        rawScoreDisplay: score.pullAndSit.rawScore,
      ),
      _ScoreItem(
        icon: Icons.speed,
        label: l10n.fitnessTestFiftyMeters,
        data: score.fiftyM,
        rawScoreDisplay: '${score.fiftyM.rawScore} s',
      ),
      _ScoreItem(
        icon: Icons.timer_outlined,
        label: l10n.fitnessTestRun,
        data: score.run,
        rawScoreDisplay: score.run.rawScore,
      ),
    ];

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...items.map((item) => _buildScoreItemRow(item))],
        ),
      ),
    );
  }

  Widget _buildScoreItemRow(_ScoreItem item) {
    final color = item.data.isFail
        ? Theme.of(context).colorScheme.error
        : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.rawScoreDisplay,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                '${item.data.gradedScore} · ${item.data.grade}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreItem {
  const _ScoreItem({
    required this.icon,
    required this.label,
    required this.data,
    required this.rawScoreDisplay,
  });

  final IconData icon;
  final String label;
  final FitnessScoreItem data;
  final String rawScoreDisplay;
}
