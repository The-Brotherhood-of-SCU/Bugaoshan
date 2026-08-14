import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/fitness_test_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

class FitnessTestPage extends StatefulWidget {
  const FitnessTestPage({super.key});

  @override
  State<FitnessTestPage> createState() => _FitnessTestPageState();
}

class _FitnessTestPageState extends State<FitnessTestPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final FitnessTestProvider _provider;
  bool _privacyHidden = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _provider = getIt<FitnessTestProvider>();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([getIt<ScuAuthProvider>(), _provider]),
      builder: (context, _) => Scaffold(
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
        body: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) {
      return auth.isAutoLoggingIn
          ? const AutoLoginLoadingWidget()
          : const LoginRequiredWidget();
    }

    // Provider 是数据的唯一来源。首次进入或登出后重新登录时，页面只表达
    // 「确保已加载」意图；它不保存请求结果、加载态或认证会话。
    if (_provider.noticesState == FitnessTestLoadState.idle ||
        _provider.scoreState == FitnessTestLoadState.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && getIt<ScuAuthProvider>().isLoggedIn) {
          _provider.ensureLoaded();
        }
      });
    }

    if (_provider.noticesState == FitnessTestLoadState.loading &&
        _provider.notices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final noticesError = _provider.noticesError;
    if (_provider.noticesState == FitnessTestLoadState.error &&
        noticesError != null) {
      return _buildError(noticesError, _provider.refresh);
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildScoresTab(l10n), _buildNoticesTab(l10n)],
    );
  }

  // ==================== Notices Tab ====================

  Widget _buildNoticesTab(AppLocalizations l10n) {
    final notices = _provider.notices;
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
      onRefresh: _provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notices.length,
        itemBuilder: (context, index) => _buildNoticeCard(notices[index], l10n),
      ),
    );
  }

  Widget _buildError(Object error, Future<void> Function() onRetry) {
    if (error is LoadErrorType) {
      return RetryableErrorWidget(errorType: error, onRetry: onRetry);
    }
    return RetryableErrorWidget.message(
      message: error.toString(),
      onRetry: onRetry,
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice, AppLocalizations l10n) {
    final isSticky = notice['is_stick'] == 1;

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
                if (isSticky) ...[
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
                    notice['title'] ?? '',
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
                  notice['create_time'] ?? '',
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
                  '${notice['read_num'] ?? 0} ${l10n.fitnessTestReadCount}',
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

  void _showNoticeDetail(Map<String, dynamic> notice, AppLocalizations l10n) {
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
                      notice['title'] ?? '',
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
                padding: const EdgeInsets.all(16),
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
                        notice['create_time'] ?? '',
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
                        '${notice['read_num'] ?? 0} ${l10n.fitnessTestReadCount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _stripHtml(notice['content'] ?? ''),
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

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<p>|<p\s[^>]*>'), '')
        .replaceAll('</p>', '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  // ==================== Scores Tab ====================

  Widget _buildScoresTab(AppLocalizations l10n) {
    final currentYear = DateTime.now().year;
    final years = List.generate(9, (i) => currentYear - i);

    return RefreshIndicator(
      onRefresh: _provider.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
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
                    value: _provider.selectedYear,
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
                      if (value != null && value != _provider.selectedYear) {
                        _provider.selectYear(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Score content
          _buildScoreContent(l10n),
        ],
      ),
    );
  }

  Widget _buildScoreContent(AppLocalizations l10n) {
    if (_provider.scoreState == FitnessTestLoadState.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final scoreError = _provider.scoreError;
    if (_provider.scoreState == FitnessTestLoadState.error &&
        scoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: _buildError(scoreError, _provider.refreshScore),
      );
    }

    if (_provider.scoreData == null) {
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
        _buildTotalScoreCard(l10n),
        const SizedBox(height: 16),
        _buildInfoCard(l10n),
        const SizedBox(height: 16),
        _buildScoreItemsCard(l10n),
      ],
    );
  }

  Widget _buildTotalScoreCard(AppLocalizations l10n) {
    final score = _provider.scoreData!;
    final totalScore = score['total_score'] ?? 0;
    final totalGrade = score['total_grade']?.toString() ?? '';
    final gradeColor = _getGradeColor(totalGrade);

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
                '$totalScore',
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
                      totalGrade,
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

  Widget _buildInfoCard(AppLocalizations l10n) {
    final score = _provider.scoreData!;
    final name = score['student_name']?.toString() ?? '-';
    final studentNum = score['student_num']?.toString() ?? '-';

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _privacyHidden = !_privacyHidden),
              child: _infoRow(
                l10n.fitnessTestStudentName,
                _privacyHidden ? _maskText(name) : name,
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
                    ? _maskText(studentNum, visibleStart: 2, visibleEnd: 2)
                    : studentNum,
                trailing: Icon(
                  _privacyHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _infoRow(l10n.fitnessTestSex, score['sex']?.toString() ?? '-'),
            _infoRow(
              l10n.fitnessTestStudentYear,
              score['studentYear']?.toString() ?? '-',
            ),
            _infoRow(
              l10n.fitnessTestReportType,
              score['report_type']?.toString() ?? '-',
            ),
            _infoRow(
              l10n.fitnessTestReportStatus,
              score['report_status']?.toString() ?? '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return InfoRow(label: label, value: value, trailing: trailing);
  }

  Widget _buildScoreItemsCard(AppLocalizations l10n) {
    final score = _provider.scoreData!;
    final items = [
      _ScoreItem(
        icon: Icons.monitor_weight_outlined,
        label: l10n.fitnessTestBmi,
        rawScore: '${score['bmi_score'] ?? '-'}',
        gradedScore: '${score['bmi_score2'] ?? '-'}',
        grade: '${score['bmi_grade'] ?? '-'}',
        colorClass: '${score['bmi_class'] ?? 'green'}',
      ),
      _ScoreItem(
        icon: Icons.air,
        label: l10n.fitnessTestVitalCapacity,
        rawScore: '${score['vc_score'] ?? '-'}',
        gradedScore: '${score['vc_score2'] ?? '-'}',
        grade: '${score['vc_grade'] ?? '-'}',
        colorClass: '${score['vc_class'] ?? 'green'}',
      ),
      _ScoreItem(
        icon: Icons.directions_run,
        label: l10n.fitnessTestStandingLongJump,
        rawScore: '${score['jump_score'] ?? '-'} cm',
        gradedScore: '${score['jump_score2'] ?? '-'}',
        grade: '${score['jump_grade'] ?? '-'}',
        colorClass: '${score['jump_class'] ?? 'green'}',
      ),
      _ScoreItem(
        icon: Icons.accessibility_new,
        label: l10n.fitnessTestSitAndReach,
        rawScore: '${score['sit_and_reach_score'] ?? '-'} cm',
        gradedScore: '${score['sit_and_reach_score2'] ?? '-'}',
        grade: '${score['sit_and_reach_grade'] ?? '-'}',
        colorClass: '${score['sit_and_reach_class'] ?? 'green'}',
      ),
      _ScoreItem(
        icon: Icons.fitness_center,
        label: score['sex'] == '女'
            ? l10n.fitnessTestSitUp
            : l10n.fitnessTestPullUp,
        rawScore: '${score['pull_and_sit_score'] ?? '-'}',
        gradedScore: '${score['pull_and_sit_score2'] ?? '-'}',
        grade: '${score['pull_and_sit_grade'] ?? '-'}',
        colorClass: '${score['pull_and_sit_class'] ?? 'green'}',
      ),
      _ScoreItem(
        icon: Icons.speed,
        label: l10n.fitnessTestFiftyMeters,
        rawScore: '${score['50m_score'] ?? '-'} s',
        gradedScore: '${score['50m_score2'] ?? '-'}',
        grade: '${score['50m_grade'] ?? '-'}',
        colorClass: '${score['50m_class'] ?? 'green'}',
      ),
      _ScoreItem(
        icon: Icons.timer_outlined,
        label: l10n.fitnessTestRun,
        rawScore: '${score['run_score'] ?? '-'}',
        gradedScore: '${score['run_score2'] ?? '-'}',
        grade: '${score['run_grade'] ?? '-'}',
        colorClass: '${score['run_class'] ?? 'green'}',
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
    final color = item.colorClass == 'red'
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
                item.rawScore,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                '${item.gradedScore} · ${item.grade}',
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

  Color _getGradeColor(String grade) {
    if (grade.contains('优秀') || grade.contains('Excellent')) {
      return Colors.blue;
    }
    if (grade.contains('良好') || grade.contains('Good')) {
      return Colors.green;
    }
    if (grade.contains('及格') || grade.contains('Pass')) {
      return Colors.orange;
    }
    if (grade.contains('不及格') || grade.contains('Fail')) {
      return Colors.red;
    }
    return Colors.grey;
  }
}

class _ScoreItem {
  const _ScoreItem({
    required this.icon,
    required this.label,
    required this.rawScore,
    required this.gradedScore,
    required this.grade,
    required this.colorClass,
  });

  final IconData icon;
  final String label;
  final String rawScore;
  final String gradedScore;
  final String grade;
  final String colorClass;
}
