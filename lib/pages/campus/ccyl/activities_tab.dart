import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_filter.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_filter_sheet.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_phase.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/pages/campus/ccyl/widgets/ccyl_level_chip.dart';
import 'package:bugaoshan/pages/campus/ccyl/widgets/ccyl_phase_chip.dart';
import 'package:bugaoshan/pages/campus/ccyl/activity_lib_detail_page.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/utils/app_log.dart';

class ActivitiesTab extends StatefulWidget {
  const ActivitiesTab({super.key});

  @override
  State<ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<ActivitiesTab> {
  static const _defaultPageSize = 10;
  // 本地筛选（状态/学时）无法下推到服务端，用更大分页减少筛选时的续拉轮数。
  static const _filteredPageSize = 20;
  // 本地筛选生效时自动续拉，直到命中数达到阈值或达到轮数上限，
  // 避免「筛选后列表不足一屏、无法滚动触发加载」的死胡同。
  static const _autoFillTarget = 5;
  static const _autoFillMaxRounds = 3;

  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  List<CyclActivity> _activities = [];
  bool _loading = false;
  LoadErrorType? _error;
  int _pageNum = 1;
  bool _hasMore = true;
  CcylActivityFilter _filter = CcylActivityFilter.empty;
  int _autoFillRounds = 0;

  // 筛选项数据（会话内懒加载缓存）。
  List<CcylLevelOption> _levelOptions = const [];
  List<CyclOrg> _orgOptions = const [];
  bool _optionsLoading = false;
  bool _optionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) {
        _loadActivities(loadMore: true);
      }
    }
  }

  // 系列详情页回传的场次归并状态（按 activityLibraryId 覆盖条目自身的
  // 乐观兜底状态），让「外面报名中、点进去未开始」这类不一致在访问后收敛。
  final _phaseOverrides = <String, List<CcylActivityPhase>>{};

  // 后台校准：对自身时间信息不足的系列条目（状态为乐观兜底），拉取场次
  // 详情并归并出真实状态。已尝试过的条目本会话内不再重复请求。
  final _seriesResolutionAttempted = <String>{};
  final _pendingSeriesResolution = <String>[];
  bool _resolvingSeriesPhases = false;

  List<CyclActivity> get _visibleActivities => _activities
      .where(
        (a) => _filter.matches(
          a,
          phasesOverride: _phaseOverrides[a.activityLibraryId],
        ),
      )
      .toList();

  Future<void> _loadActivities({bool loadMore = false}) async {
    if (_loading) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final pageSize = _filter.hasLocalFilter
        ? _filteredPageSize
        : _defaultPageSize;

    try {
      final provider = getIt<CcylProvider>();
      final page = loadMore ? _pageNum + 1 : 1;
      final results = await provider.service.searchActivities(
        pageNum: page,
        pageSize: pageSize,
        name: _searchCtrl.text,
        level: _filter.level,
        org: _filter.org,
      );

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _activities.addAll(results);
          _pageNum = page;
        } else {
          _activities = results;
          _pageNum = 1;
          _autoFillRounds = 0;
        }
        _hasMore = results.length >= pageSize;
      });
    } catch (e) {
      AppLog.e('CcylActivitiesTab', 'Activities load error: $e');
      if (mounted) {
        setState(() {
          _error = campusNetworkErrorType(LoadErrorType.ccylActivityLoadFailed);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }

    await _autoFillIfNeeded();
    _queueSeriesPhaseResolution();
  }

  /// 时间信息不足的系列条目（状态为乐观兜底）排队做后台校准：逐条拉取
  /// 场次详情并归并出真实状态回填，收敛「外部列表与场次状态不一致」
  /// （如场次已结束、外部仍显示报名中）。已尝试过的条目本会话内不重试。
  void _queueSeriesPhaseResolution() {
    for (final activity in _activities) {
      final id = activity.activityLibraryId;
      if (id.isEmpty ||
          _seriesResolutionAttempted.contains(id) ||
          _pendingSeriesResolution.contains(id)) {
        continue;
      }
      if (isCcylSeriesPhaseAmbiguous(activity)) {
        _pendingSeriesResolution.add(id);
      }
    }
    unawaited(_resolveQueuedSeriesPhases());
  }

  Future<void> _resolveQueuedSeriesPhases() async {
    if (_resolvingSeriesPhases) return;
    _resolvingSeriesPhases = true;
    try {
      while (mounted && _pendingSeriesResolution.isNotEmpty) {
        final id = _pendingSeriesResolution.removeAt(0);
        _seriesResolutionAttempted.add(id);
        try {
          final provider = getIt<CcylProvider>();
          final detail = await provider.service.getActivityLibDetail(id);
          final phases = mergeCcylSeriesPhases(detail.activities);
          if (!mounted) return;
          if (phases.isNotEmpty) {
            setState(() => _phaseOverrides[id] = phases);
          }
        } catch (e) {
          // 校准失败保留乐观兜底状态，本会话内不再重试。
          AppLog.w('CcylActivitiesTab', 'Series phase resolve failed: $e');
        }
      }
    } finally {
      _resolvingSeriesPhases = false;
    }
  }

  /// 本地筛选生效时，若命中数不足则继续加载后续页（有轮数上限）。
  Future<void> _autoFillIfNeeded() async {
    while (mounted &&
        _filter.hasLocalFilter &&
        _hasMore &&
        _visibleActivities.length < _autoFillTarget &&
        _autoFillRounds < _autoFillMaxRounds) {
      _autoFillRounds++;
      await _loadActivities(loadMore: true);
    }
  }

  Future<void> _onSearch() async {
    await _loadActivities();
  }

  void _applyFilter(CcylActivityFilter filter) {
    setState(() => _filter = filter);
    _loadActivities();
  }

  /// 筛选项懒加载：主办方取全量组织列表；活动等级的合法 code 无法静态获得
  /// （字典接口从未被调用、groupCode 未知），用一次大分页请求从真实数据归纳。
  /// 任一失败均静默降级——只影响对应筛选维度，状态与学时筛选不受影响。
  Future<void> _ensureFilterOptions() async {
    if (_optionsLoading) return;
    if (_optionsLoaded) return;
    setState(() => _optionsLoading = true);

    final provider = getIt<CcylProvider>();
    try {
      final orgs = await provider.service.getAllOrgs();
      if (mounted) setState(() => _orgOptions = orgs);
    } catch (e) {
      AppLog.w('CcylActivitiesTab', 'Organizer options load failed: $e');
    }

    try {
      final probe = await provider.service.searchActivities(pageSize: 100);
      final levels = <String, String>{};
      for (final activity in probe) {
        final code = activity.level;
        if (code.isEmpty) continue;
        levels.putIfAbsent(code, () {
          final name = activity.levelName;
          return name != null && name.isNotEmpty ? name : code;
        });
      }
      if (mounted) {
        setState(() {
          _levelOptions =
              levels.entries
                  .map((e) => CcylLevelOption(code: e.key, name: e.value))
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));
        });
      }
    } catch (e) {
      AppLog.w('CcylActivitiesTab', 'Level options load failed: $e');
    }

    if (mounted) {
      setState(() {
        _optionsLoaded = _orgOptions.isNotEmpty || _levelOptions.isNotEmpty;
        _optionsLoading = false;
      });
    }
  }

  Future<void> _openFilterSheet() async {
    await _ensureFilterOptions();
    if (!mounted) return;
    final result = await showCcylActivityFilterSheet(
      context,
      current: _filter,
      levelOptions: _levelOptions,
      orgOptions: _orgOptions,
    );
    if (result == null || result == _filter) return;
    _applyFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visibleActivities;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.ccylSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadActivities();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              IconButton(
                tooltip: l10n.ccylFilter,
                onPressed: _optionsLoading ? null : _openFilterSheet,
                icon: Badge(
                  isLabelVisible: _filter.isActive,
                  child: const Icon(Icons.filter_list),
                ),
              ),
            ],
          ),
        ),
        if (_filter.isActive) _buildActiveFilterBar(l10n),
        Expanded(
          child: _error != null
              ? RetryableErrorWidget(
                  errorType: _error!,
                  onRetry: _loadActivities,
                )
              : _activities.isEmpty && !_loading
              ? Center(
                  child: Text(
                    _filter.isActive ? l10n.ccylFilterNoMatch : l10n.noData,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadActivities,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    // 末尾固定保留一项：加载更多指示器或「无匹配」提示。
                    itemCount: visible.length + 1,
                    itemBuilder: (context, index) {
                      if (index >= visible.length) {
                        return _buildListFooter(l10n, visible.length);
                      }
                      final item = visible[index];
                      return _ActivityCard(
                        activity: item,
                        phasesOverride: _phaseOverrides[item.activityLibraryId],
                        onSeriesPhasesResolved: (phases) {
                          if (!mounted) return;
                          setState(() {
                            _phaseOverrides[item.activityLibraryId] = phases;
                          });
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterBar(AppLocalizations l10n) {
    final chips = <Widget>[
      if (_filter.level.isNotEmpty)
        InputChip(
          label: Text(_levelNameOf(_filter.level) ?? _filter.level),
          onDeleted: () => _applyFilter(_filter.copyWith(level: '')),
        ),
      if (_filter.org.isNotEmpty)
        InputChip(
          label: Text(_orgNameOf(_filter.org) ?? _filter.org),
          onDeleted: () => _applyFilter(_filter.copyWith(org: '')),
        ),
      if (_filter.minClassHour > 0)
        InputChip(
          label: Text(l10n.ccylFilterMinHoursValue(_filter.minClassHour)),
          onDeleted: () => _applyFilter(_filter.copyWith(minClassHour: 0)),
        ),
      if (_filter.phases.isNotEmpty)
        InputChip(
          label: Text(
            _filter.phases.map((p) => ccylPhaseLabel(l10n, p)).join('、'),
          ),
          onDeleted: () => _applyFilter(_filter.copyWith(phases: const {})),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(spacing: 8, children: chips),
                ),
              ),
              TextButton(
                onPressed: () => _applyFilter(CcylActivityFilter.empty),
                child: Text(l10n.ccylFilterClear),
              ),
            ],
          ),
          if (_filter.hasLocalFilter)
            Text(
              l10n.ccylFilterLocalHint(_activities.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String? _levelNameOf(String code) {
    for (final option in _levelOptions) {
      if (option.code == code) return option.name;
    }
    return null;
  }

  String? _orgNameOf(String orgNo) {
    for (final org in _orgOptions) {
      if (org.orgNo == orgNo) return org.orgName;
    }
    return null;
  }

  Widget _buildListFooter(AppLocalizations l10n, int visibleCount) {
    // 只在真正请求中才显示转圈，避免「已停止加载却一直转圈」的假加载。
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (visibleCount == 0) {
      // 已拉取数据但本地筛选拦掉了全部条目；还有更多页时给手动续拉入口，
      // 自动续拉有轮数上限，不能让用户误以为还在加载。
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              l10n.ccylFilterNoMatch,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_hasMore)
              TextButton(
                onPressed: () => _loadActivities(loadMore: true),
                child: Text(l10n.ccylLoadMore),
              ),
          ],
        ),
      );
    }
    if (_hasMore) {
      return Center(
        child: TextButton(
          onPressed: () => _loadActivities(loadMore: true),
          child: Text(l10n.ccylLoadMore),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ActivityCard extends StatelessWidget {
  final CyclActivity activity;

  /// 系列详情页回传的场次归并状态；为空时按条目自身数据推算。
  final List<CcylActivityPhase>? phasesOverride;

  /// 详情页加载完场次后回传归并状态，由列表 State 记录到覆盖表。
  final ValueChanged<List<CcylActivityPhase>>? onSeriesPhasesResolved;

  const _ActivityCard({
    required this.activity,
    this.phasesOverride,
    this.onSeriesPhasesResolved,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final override = phasesOverride;
    return StyledCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityLibDetailPage(
              activityLibraryId: activity.activityLibraryId,
              onSubActivitiesResolved: onSeriesPhasesResolved,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    activity.orgName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 16),
                if (activity.levelName != null)
                  CcylLevelChip(label: activity.levelName!),
              ],
            ),
            if (activity.startTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _timeRangeText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${activity.classHour} ${l10n.ccylHours}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                CcylPhaseChips(
                  phases: (override != null && override.isNotEmpty)
                      ? override
                      : resolveCcylActivityPhases(activity),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeRangeText() {
    final start = activity.startTime ?? '';
    final end = activity.endTime;
    return end == null || end.isEmpty ? start : '$start ~ $end';
  }
}
