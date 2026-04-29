import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/services/ccyl_service.dart';

class CreditListPage extends StatefulWidget {
  const CreditListPage({super.key});

  @override
  State<CreditListPage> createState() => _CreditListPageState();
}

class _CreditListPageState extends State<CreditListPage> {
  final _scrollController = ScrollController();
  List<CyclCredit> _credits = [];
  bool _loading = false;
  String? _error;
  int _pageNum = 1;
  bool _hasMore = true;

  bool _selecting = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadCredits();
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
        _loadCredits(loadMore: true);
      }
    }
  }

  Future<void> _loadCredits({bool loadMore = false}) async {
    if (_loading) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = getIt<CcylProvider>();
      final page = loadMore ? _pageNum + 1 : 1;
      final results = await provider.service.getCreditList(pageNum: page);

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _credits.addAll(results);
          _pageNum = page;
        } else {
          _credits = results;
          _pageNum = 1;
          _selectedIds.clear();
          _selecting = false;
        }
        _hasMore = results.length >= 10;
      });
    } catch (e) {
      debugPrint('Credit list load error: $e');
      if (mounted) {
        final hour = DateTime.now().hour;
        setState(() {
          _error = (hour >= 0 && hour < 6)
              ? 'campusNetworkRequired'
              : 'loadFailed';
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

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    if (_credits.isEmpty) return;
    if (_selectedIds.length == _credits.length) {
      setState(() => _selectedIds.clear());
    } else {
      setState(() {
        _selectedIds.clear();
        _selectedIds.addAll(_credits.map((c) => c.creditId));
      });
    }
  }

  Future<void> _showExportDialog() async {
    if (_selectedIds.isEmpty) return;

    final emailController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ccylExportEmail),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(
            hintText: l10n.ccylEmailHint,
            labelText: l10n.ccylEmailAddress,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final text = emailController.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;
    await _exportToEmail(email);
  }

  Future<void> _exportToEmail(String email) async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.loading)));

    try {
      final provider = getIt<CcylProvider>();
      final msg = await provider.service.exportCreditsToEmail(
        _selectedIds.toList(),
        email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() {
        _selecting = false;
        _selectedIds.clear();
      });
    } catch (e) {
      debugPrint('Export error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, double> _statsByType() {
    final stats = <String, double>{};
    for (final c in _credits) {
      stats.update(
        c.scoreTypeName,
        (v) => v + c.classHour,
        ifAbsent: () => c.classHour,
      );
    }
    return stats;
  }

  double get _totalHours =>
      _credits.fold<double>(0, (sum, c) => sum + c.classHour);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _error != null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error == 'campusNetworkRequired'
                      ? l10n.campusNetworkRequired
                      : l10n.loadFailed,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadCredits,
                  child: Text(l10n.loadFailed),
                ),
              ],
            ),
          )
        : _credits.isEmpty && !_loading
        ? Center(child: Text(l10n.noData))
        : RefreshIndicator(
            onRefresh: () => _loadCredits(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount:
                  1 + // selection bar
                  _credits.length +
                  (_hasMore ? 1 : 0) +
                  (_credits.isNotEmpty ? 1 : 0), // stats
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SelectionBar(
                    selecting: _selecting,
                    selectedCount: _selectedIds.length,
                    totalCount: _credits.length,
                    onToggleSelecting: _toggleSelecting,
                    onSelectAll: _selectAll,
                    onExport: _selectedIds.isNotEmpty
                        ? _showExportDialog
                        : null,
                    l10n: l10n,
                  );
                }
                final creditIndex = index - 1;
                if (creditIndex < _credits.length) {
                  final credit = _credits[creditIndex];
                  return _CreditCard(
                    credit: credit,
                    selecting: _selecting,
                    selected: _selectedIds.contains(credit.creditId),
                    onToggle: () => _toggleSelection(credit.creditId),
                  );
                }
                // loading indicator
                final statsIndex = index - 1 - _credits.length;
                if (_hasMore) {
                  if (statsIndex == 0) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return _StatsHeader(
                    totalHours: _totalHours,
                    statsByType: _statsByType(),
                  );
                }
                return _StatsHeader(
                  totalHours: _totalHours,
                  statsByType: _statsByType(),
                );
              },
            ),
          );
  }
}

class _SelectionBar extends StatelessWidget {
  final bool selecting;
  final int selectedCount;
  final int totalCount;
  final VoidCallback onToggleSelecting;
  final VoidCallback onSelectAll;
  final VoidCallback? onExport;
  final AppLocalizations l10n;

  const _SelectionBar({
    required this.selecting,
    required this.selectedCount,
    required this.totalCount,
    required this.onToggleSelecting,
    required this.onSelectAll,
    required this.onExport,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!selecting) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            const Spacer(),
            TextButton.icon(
              onPressed: onToggleSelecting,
              icon: const Icon(Icons.checklist, size: 18),
              label: Text(l10n.ccylSelect),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            TextButton(onPressed: onToggleSelecting, child: Text(l10n.cancel)),
            TextButton(
              onPressed: onSelectAll,
              child: Text(
                selectedCount == totalCount ? l10n.cancel : l10n.ccylSelectAll,
              ),
            ),
            Text(
              '$selectedCount/$totalCount',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onExport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(l10n.ccylExportEmail),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final double totalHours;
  final Map<String, double> statsByType;

  const _StatsHeader({required this.totalHours, required this.statsByType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '总学时: $totalHours',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (statsByType.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...statsByType.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(entry.key, style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        '${entry.value} 学时',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  final CyclCredit credit;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  const _CreditCard({
    required this.credit,
    this.selecting = false,
    this.selected = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: selecting ? onToggle : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selecting) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 12),
                      child: Icon(
                        selected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 22,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      credit.activityName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  Text('${credit.classHour} 学时', style: mutedStyle),
                  const SizedBox(width: 16),
                  const Icon(Icons.category_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(credit.scoreTypeName, style: mutedStyle),
                  const Spacer(),
                  _StatusChip(
                    label: credit.creditStatusName,
                    color: credit.creditStatus == 'C0'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(credit.createTime, style: mutedStyle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 255 * 0.6),
          fontSize: 12,
        ),
      ),
    );
  }
}
