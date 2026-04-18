import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/serivces/ccyl_service.dart';

class MyActivitiesTab extends StatefulWidget {
  @override
  State<MyActivitiesTab> createState() => _MyActivitiesTabState();
}

class _MyActivitiesTabState extends State<MyActivitiesTab> {
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
      final results = await provider.service.getMyActivities(pageNum: page);

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
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
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
                return _MyActivityCard(activity: activity);
              },
            ),
          );
  }
}

class _MyActivityCard extends StatelessWidget {
  final CyclActivity activity;

  const _MyActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.activityName,
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
              ],
            ),
            const SizedBox(height: 8),
            if (activity.startTime != null && activity.endTime != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${activity.startTime} - ${activity.endTime}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (activity.activityAddress != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity.activityAddress!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${activity.classHour} ${l10n.ccylHours}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(activity.statusName),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activity.statusName ?? activity.status,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? statusName) {
    if (statusName == null) return Colors.grey.shade100;
    switch (statusName) {
      case '报名中':
        return Colors.blue.shade100;
      case '进行中':
        return Colors.green.shade100;
      case '已结束':
        return Colors.grey.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
