import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/serivces/ccyl_service.dart';
import 'package:bugaoshan/pages/campus/ccyl/activity_lib_detail_page.dart';

class ActivitiesTab extends StatefulWidget {
  @override
  State<ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<ActivitiesTab> {
  final _searchCtrl = TextEditingController();
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

  Future<void> _loadActivities({bool loadMore = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = getIt<CcylProvider>();
      final page = loadMore ? _pageNum + 1 : 1;
      final results = await provider.service.searchActivities(
        pageNum: page,
        name: _searchCtrl.text,
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

  Future<void> _onSearch() async {
    await _loadActivities();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
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
        Expanded(
          child: _error != null
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
              : ListView.builder(
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
                    return _ActivityCard(activity: activity);
                  },
                ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final CyclActivity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    '${activity.classHour} ${l10n.ccylHours}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (activity.star.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    ...List.generate(
                      int.tryParse(
                            activity.star.substring(activity.star.length - 1),
                          ) ??
                          0,
                      (index) => Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.star,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity.starName ?? activity.star,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: activity.doing
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activity.subscribed
                          ? l10n.ccylSubscribed
                          : (activity.doing
                                ? l10n.ccylAvailable
                                : l10n.ccylCompleted),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: activity.doing ? Colors.green : Colors.orange,
                      ),
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
}
