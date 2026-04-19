import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/serivces/ccyl_service.dart';
import 'package:bugaoshan/pages/campus/ccyl/activity_detail_page.dart';

class ActivityLibDetailPage extends StatefulWidget {
  final String activityLibraryId;

  const ActivityLibDetailPage({super.key, required this.activityLibraryId});

  @override
  State<ActivityLibDetailPage> createState() => _ActivityLibDetailPageState();
}

class _ActivityLibDetailPageState extends State<ActivityLibDetailPage> {
  bool _loading = true;
  String? _error;
  CyclActivityLib? _activityLib;
  List<CyclActivity> _activities = [];
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = getIt<CcylProvider>();
      final result = await provider.service.getActivityLibDetail(
        widget.activityLibraryId,
      );
      if (!mounted) return;
      setState(() {
        _activityLib = result.activityLib;
        _activities = result.activities;
        _subscribed = result.subscribed;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Activity lib detail load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'ccylActivityLoadFailed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ccylActivitySeries)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getErrorMessage(l10n, _error!),
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: Text(l10n.loadFailed)),
          ],
        ),
      );
    }

    if (_activityLib == null) {
      return Center(child: Text(l10n.noData));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(l10n),
          const SizedBox(height: 16),
          _buildInfoSection(l10n),
          const SizedBox(height: 16),
          _buildContactSection(l10n),
          const SizedBox(height: 24),
          _buildActivitiesSection(l10n),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final lib = _activityLib!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lib.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_subscribed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.ccylSubscribed,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(lib.orgName),
                const SizedBox(width: 16),
                if (lib.levelName != null)
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
                      lib.levelName!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            if (lib.describe != null && lib.describe!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                lib.describe!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(AppLocalizations l10n) {
    final lib = _activityLib!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ccylActivityInfo,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.star,
              l10n.ccylStarLevel,
              lib.starName ?? lib.star,
            ),
            if (lib.qualityName != null)
              _buildInfoRow(
                Icons.emoji_events,
                l10n.ccylQuality,
                lib.qualityName!,
              ),
            if (lib.scoreTypeNames != null)
              _buildInfoRow(
                Icons.school,
                l10n.ccylScoreType,
                lib.scoreTypeNames!,
              ),
            _buildInfoRow(Icons.schedule, l10n.ccylHours, '${lib.classHour}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(AppLocalizations l10n) {
    final lib = _activityLib!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ccylContactInfo,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, l10n.ccylLiablePerson, lib.liablePer),
            _buildInfoRow(
              Icons.phone,
              l10n.ccylLiablePhone,
              lib.liablePerPhone,
            ),
            if (lib.liableTer.isNotEmpty) ...[
              const Divider(),
              _buildInfoRow(
                Icons.person_outline,
                l10n.ccylLiableTeacher,
                lib.liableTer,
              ),
              _buildInfoRow(
                Icons.phone_outlined,
                l10n.ccylLiableTeacherPhone,
                lib.liableTerPhone,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ccylActivities,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_activities.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  l10n.noData,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          ...List.generate(_activities.length, (index) {
            final activity = _activities[index];
            return _ActivityCard(activity: activity, index: index + 1);
          }),
      ],
    );
  }

  String _getErrorMessage(AppLocalizations l10n, String errorKey) {
    switch (errorKey) {
      case 'ccylActivityLoadFailed':
        return l10n.ccylActivityLoadFailed;
      default:
        return l10n.loadFailed;
    }
  }
}

class _ActivityCard extends StatelessWidget {
  final CyclActivity activity;
  final int index;

  const _ActivityCard({required this.activity, required this.index});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ActivityDetailPage(activityId: activity.activityId ?? ''),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      activity.activityName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: activity.status == 'A03'
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activity.statusName ?? activity.status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: activity.status == 'A03'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (activity.startTime != null)
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activity.startTime} - ${activity.endTime ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              if (activity.activityAddress != null &&
                  activity.activityAddress!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.activityAddress!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${l10n.ccylQuota}: ${activity.quota}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (activity.mobile != null &&
                      activity.mobile!.isNotEmpty) ...[
                    const Spacer(),
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity.mobile!,
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
