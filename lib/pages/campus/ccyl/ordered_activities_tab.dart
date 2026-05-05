import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/services/ccyl_service.dart';
import 'package:bugaoshan/pages/campus/ccyl/activity_lib_detail_page.dart';
import 'package:bugaoshan/widgets/common/error_widgets.dart';

class OrderedActivitiesTab extends StatefulWidget {
  const OrderedActivitiesTab({super.key});

  @override
  State<OrderedActivitiesTab> createState() => _OrderedActivitiesTabState();
}

class _OrderedActivitiesTabState extends State<OrderedActivitiesTab> {
  List<CyclActivity> _activities = [];
  bool _loading = false;
  String? _error;
  int _pageNum = 1;
  bool _hasMore = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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

  Future<void> _loadActivities({bool loadMore = false}) async {
    if (_loading) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = getIt<CcylProvider>();
      final page = loadMore ? _pageNum + 1 : 1;
      final results = await provider.service.getOrderedActivities(
        pageNum: page,
      );

      setState(() {
        if (loadMore) {
          _activities.addAll(results);
          _pageNum = page;
        } else {
          _activities = results;
          _pageNum = 1;
        }
        _hasMore = results.length >= 10;
      });
    } catch (e) {
      debugPrint('Ordered activities load error: $e');
      if (mounted) {
        final hour = DateTime.now().hour;
        setState(() {
          _error = (hour >= 0 && hour < 6)
              ? 'campusNetworkRequiredAtNight'
              : 'ccylActivityLoadFailed';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 错误态：单独展示，不需要下拉刷新
    if (_error != null) {
      return TappableErrorWidget(
        message: _getErrorMessage(l10n, _error!),
        onRetry: _loadActivities,
      );
    }

    // 正常态：RefreshIndicator 包裹统一的 ListView，始终挂载 _scrollController
    // AlwaysScrollableScrollPhysics 保证空列表时也能触发下拉刷新
    return RefreshIndicator(
      onRefresh: () => _loadActivities(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        // 空列表时额外插入一个占位 item，使列表可滚动从而触发 RefreshIndicator
        itemCount: _activities.isEmpty
            ? 1
            : _activities.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 空列表占位
          if (_activities.isEmpty) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(l10n.noData),
              ),
            );
          }

          // 加载更多指示器
          if (index >= _activities.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return _OrderedActivityCard(activity: _activities[index]);
        },
      ),
    );
  }

  String _getErrorMessage(AppLocalizations l10n, String errorKey) {
    switch (errorKey) {
      case 'ccylActivityLoadFailed':
        return l10n.ccylActivityLoadFailed;
      case 'campusNetworkRequiredAtNight':
        return l10n.campusNetworkRequiredAtNight;
      default:
        return l10n.loadFailed;
    }
  }
}

class _OrderedActivityCard extends StatelessWidget {
  final CyclActivity activity;

  const _OrderedActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityLibDetailPage(
                activityLibraryId: activity.activityLibraryId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                  Text(
                    activity.orgName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  if (activity.levelName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        activity.levelName!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${activity.classHour} 学时',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (activity.starName?.isNotEmpty == true) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity.starName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
