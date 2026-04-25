import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/services/ccyl_service.dart';
import 'package:photo_view/photo_view.dart';

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
  bool _signedUp = false;
  bool _actionLoading = false;

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
      final result = await provider.service.getActivityDetail(
        widget.activityId,
      );
      if (!mounted) return;
      setState(() {
        _activity = result.activity;
        _activityLib = result.activityLib;
        _signedUp = result.signUp;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Activity detail load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'ccylActivityLoadFailed';
        _loading = false;
      });
    }
  }

  Future<void> _toggleSignUp() async {
    if (_activity == null || _actionLoading) return;

    if (_signedUp) {
      await _cancelSignUp();
    } else {
      await _signUp();
    }
  }

  Future<void> _signUp() async {
    if (_activity == null || _actionLoading) return;
    setState(() => _actionLoading = true);

    try {
      final provider = getIt<CcylProvider>();
      final scoreTypes = await provider.service.getActivityScoreTypes(
        _activity!.activityLibraryId,
      );
      if (!mounted || !_actionLoading) return;

      if (scoreTypes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.ccylNoScoreType),
          ),
        );
        setState(() => _actionLoading = false);
        return;
      }

      final selectedType = await _showScoreTypeDialog(scoreTypes);
      if (selectedType == null || !mounted) {
        setState(() => _actionLoading = false);
        return;
      }

      await provider.service.signUpActivity(
        widget.activityId,
        selectedType.code ?? '',
      );
    } catch (e) {
      debugPrint('Sign up error: $e');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.ccylActionFailed),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _signedUp = true;
      _actionLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.ccylSignUpSuccess)),
    );
  }

  Future<void> _cancelSignUp() async {
    if (_activity == null || _actionLoading) return;
    setState(() => _actionLoading = true);

    try {
      final provider = getIt<CcylProvider>();
      await provider.service.cancelSignUp(widget.activityId);
    } catch (e) {
      debugPrint('Cancel sign up error: $e');
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.ccylActionFailed),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _signedUp = false;
      _actionLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.ccylCancelSuccess)),
    );
  }

  Future<CyclScoreType?> _showScoreTypeDialog(
    List<CyclScoreType> scoreTypes,
  ) async {
    return showDialog<CyclScoreType>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.ccylSelectScoreType),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: scoreTypes.length,
            itemBuilder: (context, index) {
              final type = scoreTypes[index];
              return ListTile(
                title: Text(type.name),
                subtitle: Text(
                  '${AppLocalizations.of(context)!.ccylCurrentValue}: ${type.value}',
                ),
                onTap: () => Navigator.pop(context, type),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ccylActivityDetail)),
      body: _buildBody(l10n),
      bottomNavigationBar: _buildBottomBar(l10n),
    );
  }

  Widget? _buildBottomBar(AppLocalizations l10n) {
    if (_loading || _error != null || _activity == null) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _actionLoading ? null : _toggleSignUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _signedUp
                ? Colors.red.shade100
                : Colors.green.shade100,
            foregroundColor: _signedUp
                ? Colors.red.shade700
                : Colors.green.shade700,
            minimumSize: const Size.fromHeight(48),
          ),
          child: _actionLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _signedUp ? l10n.ccylCancelSignUp : l10n.ccylSignUp,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
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

    return GestureDetector(
      onTap: () => _showFullScreenImage(context, _activity!.poster),
      child: ClipRRect(
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
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(
            imageProvider: NetworkImage(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported, size: 64),
                ),
              );
            },
          ),
        ),
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ccylTimeInfo,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildTimeRangeTile(
              Icons.play_arrow,
              l10n.ccylEnrollTime,
              activity.enrollStartTime,
              activity.enrollEndTime,
            ),
            if (activity.startTime != null)
              const SizedBox(height: 12),
            if (activity.startTime != null)
              _buildTimeRangeTile(
                Icons.schedule,
                l10n.ccylActivityTime,
                activity.startTime,
                activity.endTime,
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

  Widget _buildTimeRangeTile(
    IconData icon,
    String label,
    String? startTime,
    String? endTime,
  ) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label: ', style: mutedStyle),
              const SizedBox(height: 2),
              if (startTime != null && startTime.isNotEmpty)
                Text(
                  startTime,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              if (endTime != null && endTime.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  endTime,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ],
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

  String _getErrorMessage(AppLocalizations l10n, String errorKey) {
    switch (errorKey) {
      case 'ccylActivityLoadFailed':
        return l10n.ccylActivityLoadFailed;
      default:
        return l10n.loadFailed;
    }
  }
}
