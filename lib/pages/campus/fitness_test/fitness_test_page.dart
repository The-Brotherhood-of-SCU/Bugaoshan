import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';

class FitnessTestPage extends StatefulWidget {
  const FitnessTestPage({super.key});

  @override
  State<FitnessTestPage> createState() => _FitnessTestPageState();
}

class _FitnessTestPageState extends State<FitnessTestPage>
    with SingleTickerProviderStateMixin {
  static const _baseUrl =
      'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php';

  late final TabController _tabController;

  bool _loading = false;
  String? _error;

  // Notices
  List<Map<String, dynamic>> _notices = [];

  // Scores
  int _selectedYear = DateTime.now().year;
  Map<String, dynamic>? _scoreData;
  bool _scoreLoading = false;
  String? _scoreError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn && mounted) {
      _loadData();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<CookieClient?> _ensureClient() async {
    final auth = getIt<ScuAuthProvider>();
    if (auth.accessToken == null) return null;
    final client = await auth.service.bindSession();
    // Follow SSO redirect to activate fitness test session
    await client.followRedirects(
      Uri.parse('$_baseUrl/index/login/scuMsLogin'),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'User-Agent': _headers['User-Agent']!,
        'Authorization': 'Bearer ${auth.accessToken}',
      },
    );
    return client;
  }

  Future<void> _loadData() async {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) {
      if (auth.isAutoLoggingIn) return;
      setState(() => _error = 'notLoggedIn');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = await _ensureClient();
      if (client == null) {
        setState(() {
          _loading = false;
          _error = 'authFailed';
        });
        return;
      }

      try {
        // Load notices
        final noticeResp = await client.post(
          Uri.parse('$_baseUrl/index/News/getSchoolNoticeList'),
          headers: _headers,
        );
        final noticeJson = _parseJson(noticeResp.body, 'getSchoolNoticeList');
        if (noticeJson['status'] != 1) {
          throw Exception(noticeJson['info'] ?? '获取通知失败');
        }
        _notices = (noticeJson['data'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

        // Load scores for selected year
        await _loadScore(client);

        if (mounted) {
          setState(() => _loading = false);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Fitness test load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'networkError';
        });
      }
    }
  }

  Future<void> _loadScore(CookieClient client) async {
    setState(() {
      _scoreLoading = true;
      _scoreError = null;
    });

    try {
      final resp = await client.post(
        Uri.parse('$_baseUrl/index/Report/getStudentScore'),
        headers: _headers,
        body: 'year_num=$_selectedYear',
      );
      final json = _parseJson(resp.body, 'getStudentScore');
      if (json['status'] != 1) {
        setState(() {
          _scoreLoading = false;
          _scoreError = json['info'] ?? '查询失败';
        });
        return;
      }
      final data = json['data'];
      setState(() {
        _scoreData = data is Map<String, dynamic> ? data : null;
        _scoreLoading = false;
      });
    } catch (e) {
      debugPrint('Fitness test score error: $e');
      setState(() {
        _scoreLoading = false;
        _scoreError = 'networkError';
      });
    }
  }

  Future<void> _onYearChanged(int year) async {
    _selectedYear = year;
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) return;

    try {
      final client = await _ensureClient();
      if (client == null) return;
      try {
        await _loadScore(client);
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Year change error: $e');
    }
  }

  Map<String, dynamic> _parseJson(String body, String api) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('[$api] JSON 解析失败: $body');
    }
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Origin': 'https://pead.scu.edu.cn',
    'Pragma': 'no-cache',
    'Referer':
        'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php/index/index',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0',
    'X-Requested-With': 'XMLHttpRequest',
    'sec-ch-ua':
        '"Microsoft Edge";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fitnessTest),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.fitnessTestNotices),
            Tab(text: l10n.fitnessTestScores),
          ],
        ),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn && auth.isAutoLoggingIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.autoLoggingIn),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      if (_error == 'notLoggedIn') {
        if (getIt<ScuAuthProvider>().isAutoLoggingIn) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.autoLoggingIn),
              ],
            ),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.login,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(l10n.loginRequired, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.person),
                  label: Text(l10n.goToLogin),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: GestureDetector(
          onTap: _loadData,
          child: SizedBox(
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  _error == 'networkError' ? l10n.networkError : l10n.loadFailed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildNoticesTab(l10n),
        _buildScoresTab(l10n),
      ],
    );
  }

  // ==================== Notices Tab ====================

  Widget _buildNoticesTab(AppLocalizations l10n) {
    if (_notices.isEmpty) {
      return Center(
        child: Text(
          l10n.noData,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notices.length,
        itemBuilder: (context, index) => _buildNoticeCard(_notices[index], l10n),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice, AppLocalizations l10n) {
    final isSticky = notice['is_stick'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showNoticeDetail(notice, l10n),
        borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.fitnessTestSticky,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
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
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Year selector
          Card(
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
                    value: _selectedYear,
                    underline: const SizedBox(),
                    items: years
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text('$y'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != _selectedYear) {
                        _onYearChanged(value);
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
    if (_scoreLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_scoreError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                _scoreError == 'networkError'
                    ? l10n.networkError
                    : _scoreError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_scoreData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.fitnessTestNoScore,
            style: TextStyle(
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
    final totalScore = _scoreData!['total_score'] ?? 0;
    final totalGrade = _scoreData!['total_grade'] ?? '';
    final gradeColor = _getGradeColor(totalGrade);

    return Card(
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      totalGrade,
                      style: TextStyle(
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

  Widget _buildInfoCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              l10n.fitnessTestStudentName,
              _scoreData!['student_name'] ?? '-',
            ),
            _infoRow(
              l10n.fitnessTestStudentNum,
              _scoreData!['student_num'] ?? '-',
            ),
            _infoRow(l10n.fitnessTestSex, _scoreData!['sex'] ?? '-'),
            _infoRow(
              l10n.fitnessTestStudentYear,
              _scoreData!['studentYear'] ?? '-',
            ),
            _infoRow(
              l10n.fitnessTestReportType,
              _scoreData!['report_type'] ?? '-',
            ),
            _infoRow(
              l10n.fitnessTestReportStatus,
              _scoreData!['report_status'] ?? '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItemsCard(AppLocalizations l10n) {
    final items = [
      _ScoreItem(
        icon: Icons.monitor_weight_outlined,
        label: l10n.fitnessTestBmi,
        rawScore: _scoreData!['bmi_score'] ?? '-',
        gradedScore: '${_scoreData!['bmi_score2'] ?? '-'}',
        grade: _scoreData!['bmi_grade'] ?? '-',
        colorClass: _scoreData!['bmi_class'] ?? 'green',
      ),
      _ScoreItem(
        icon: Icons.air,
        label: l10n.fitnessTestVitalCapacity,
        rawScore: '${_scoreData!['vc_score'] ?? '-'}',
        gradedScore: '${_scoreData!['vc_score2'] ?? '-'}',
        grade: _scoreData!['vc_grade'] ?? '-',
        colorClass: _scoreData!['vc_class'] ?? 'green',
      ),
      _ScoreItem(
        icon: Icons.directions_run,
        label: l10n.fitnessTestStandingLongJump,
        rawScore: '${_scoreData!['jump_score'] ?? '-'} cm',
        gradedScore: '${_scoreData!['jump_score2'] ?? '-'}',
        grade: _scoreData!['jump_grade'] ?? '-',
        colorClass: _scoreData!['jump_class'] ?? 'green',
      ),
      _ScoreItem(
        icon: Icons.accessibility_new,
        label: l10n.fitnessTestSitAndReach,
        rawScore: '${_scoreData!['sit_and_reach_score'] ?? '-'} cm',
        gradedScore: '${_scoreData!['sit_and_reach_score2'] ?? '-'}',
        grade: _scoreData!['sit_and_reach_grade'] ?? '-',
        colorClass: _scoreData!['sit_and_reach_class'] ?? 'green',
      ),
      _ScoreItem(
        icon: Icons.fitness_center,
        label: _scoreData!['sex'] == '女'
            ? l10n.fitnessTestSitUp
            : l10n.fitnessTestPullUp,
        rawScore: '${_scoreData!['pull_and_sit_score'] ?? '-'}',
        gradedScore: '${_scoreData!['pull_and_sit_score2'] ?? '-'}',
        grade: _scoreData!['pull_and_sit_grade'] ?? '-',
        colorClass: _scoreData!['pull_and_sit_class'] ?? 'green',
      ),
      _ScoreItem(
        icon: Icons.speed,
        label: l10n.fitnessTestFiftyMeters,
        rawScore: '${_scoreData!['50m_score'] ?? '-'} s',
        gradedScore: '${_scoreData!['50m_score2'] ?? '-'}',
        grade: _scoreData!['50m_grade'] ?? '-',
        colorClass: _scoreData!['50m_class'] ?? 'green',
      ),
      _ScoreItem(
        icon: Icons.timer_outlined,
        label: l10n.fitnessTestRun,
        rawScore: '${_scoreData!['run_score'] ?? '-'}',
        gradedScore: '${_scoreData!['run_score2'] ?? '-'}',
        grade: _scoreData!['run_grade'] ?? '-',
        colorClass: _scoreData!['run_class'] ?? 'green',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.fitnessTestScores,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            ...items.map((item) => _buildScoreItemRow(item)),
          ],
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
