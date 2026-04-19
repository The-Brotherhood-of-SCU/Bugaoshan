import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/serivces/ccyl_service.dart';
import 'package:bugaoshan/pages/campus/ccyl/activity_lib_detail_page.dart';

class OrderedActivitiesTab extends StatefulWidget {
  const OrderedActivitiesTab({super.key});

  @override
  State<OrderedActivitiesTab> createState() => _OrderedActivitiesTabState();
}

class _OrderedActivitiesTabState extends State<OrderedActivitiesTab> {
  final _scrollController = ScrollController();
  List<CyclActivity> _activities = [];
  bool _loading = false;
  String? _error;
  int _pageNum = 1;
  bool _hasMore = true;

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
      if (mounted) {
        setState(() {
          _error = e.toString();
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

    return _error != null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadActivities,
                  child: Text(l10n.loadFailed),
                ),
              ],
            ),
          )
        : _activities.isEmpty && !_loading
        ? Center(child: Text(l10n.noData))
        : RefreshIndicator(
            onRefresh: () => _loadActivities(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _activities.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _activities.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final activity = _activities[index];
                return _OrderedActivityCard(activity: activity);
              },
            ),
          );
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
