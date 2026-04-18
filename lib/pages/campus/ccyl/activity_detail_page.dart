import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/serivces/ccyl_service.dart';

class ActivityDetailPage extends StatefulWidget {
  final String activityId;

  const ActivityDetailPage({super.key, required this.activityId});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  bool _loading = true;
  String? _error;
  CyclActivity? _activity;
  CyclActivityLib? _activityLib;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = getIt<CcylProvider>();
      final result = await provider.service.getActivityDetail(
        widget.activityId,
      );
      setState(() {
        _activity = result.activity;
        _activityLib = result.activityLib;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ccylActivityDetail)),
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
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: Text(l10n.loadFailed)),
          ],
        ),
      );
    }

    if (_activity == null) {
      return Center(child: Text(l10n.noData));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPoster(l10n),
          const SizedBox(height: 16),
          _buildHeader(l10n),
          const SizedBox(height: 16),
          _buildTimeSection(l10n),
          const SizedBox(height: 16),
          _buildLocationSection(l10n),
          const SizedBox(height: 16),
          _buildInfoSection(l10n),
          if (_activityLib != null) ...[
            const SizedBox(height: 16),
            _buildLibSection(l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildPoster(AppLocalizations l10n) {
    if (_activity!.poster.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        _activity!.poster,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.image_not_supported, size: 48),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final activity = _activity!;
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
                    activity.activityName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activity.status == 'A03'
                        ? Colors.green.shade100
                        : activity.status == 'A05'
                        ? Colors.blue.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activity.statusName ?? activity.status,
                    style: TextStyle(
                      color: activity.status == 'A03'
                          ? Colors.green.shade700
                          : activity.status == 'A05'
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
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
                Text(
                  (_activityLib?.orgName.isNotEmpty == true)
                      ? _activityLib!.orgName
                      : activity.orgName,
                ),
              ],
            ),
            if (activity.describe != null && activity.describe!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                activity.describe!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection(AppLocalizations l10n) {
    final activity = _activity!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ccylTimeInfo,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.play_arrow,
              l10n.ccylEnrollTime,
              '${activity.enrollStartTime} - ${activity.enrollEndTime ?? ''}',
            ),
            if (activity.startTime != null)
              _buildInfoRow(
                Icons.schedule,
                l10n.ccylActivityTime,
                '${activity.startTime} - ${activity.endTime ?? ''}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(AppLocalizations l10n) {
    final activity = _activity!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ccylLocationInfo,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (activity.activityAddress != null &&
                activity.activityAddress!.isNotEmpty)
              _buildInfoRow(
                Icons.location_on,
                l10n.ccylActivityAddress,
                activity.activityAddress!,
              ),
            if (activity.mobile != null && activity.mobile!.isNotEmpty)
              _buildInfoRow(
                Icons.phone,
                l10n.ccylContactPhone,
                activity.mobile!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(AppLocalizations l10n) {
    final activity = _activity!;
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
            _buildInfoRow(Icons.people, l10n.ccylQuota, '${activity.quota}'),
            _buildInfoRow(
              Icons.flag,
              l10n.ccylActivityTarget,
              activity.activityTargetName ?? activity.activityTarget,
            ),
            _buildInfoRow(
              Icons.schedule,
              l10n.ccylHours,
              '${activity.classHour}',
            ),
            Row(
              children: [
                Icon(
                  Icons.login,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.ccylSignIn}: ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  activity.isSignIn == '1'
                      ? l10n.ccylEnabled
                      : l10n.ccylDisabled,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: activity.isSignIn == '1'
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${l10n.ccylSignOut}: ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  activity.isSignOut == '1'
                      ? l10n.ccylEnabled
                      : l10n.ccylDisabled,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: activity.isSignOut == '1'
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibSection(AppLocalizations l10n) {
    final lib = _activityLib!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ccylActivitySeries,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.collections, l10n.ccylSeriesName, lib.name),
            _buildInfoRow(Icons.business, l10n.ccylOrganizer, lib.orgName),
            if (lib.levelName != null)
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
