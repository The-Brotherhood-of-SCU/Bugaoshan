import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_filter.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_phase.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/pages/campus/ccyl/widgets/ccyl_phase_chip.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 弹出活动筛选面板；返回新的筛选条件，取消时返回 null。
Future<CcylActivityFilter?> showCcylActivityFilterSheet(
  BuildContext context, {
  required CcylActivityFilter current,
  required List<CcylLevelOption> levelOptions,
  required List<CyclOrg> orgOptions,
}) {
  return showModalBottomSheet<CcylActivityFilter>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppShapes.largeIncreased),
      ),
    ),
    builder: (_) => _CcylActivityFilterSheet(
      current: current,
      levelOptions: levelOptions,
      orgOptions: orgOptions,
    ),
  );
}

class _CcylActivityFilterSheet extends StatefulWidget {
  final CcylActivityFilter current;
  final List<CcylLevelOption> levelOptions;
  final List<CyclOrg> orgOptions;

  const _CcylActivityFilterSheet({
    required this.current,
    required this.levelOptions,
    required this.orgOptions,
  });

  @override
  State<_CcylActivityFilterSheet> createState() =>
      _CcylActivityFilterSheetState();
}

class _CcylActivityFilterSheetState extends State<_CcylActivityFilterSheet> {
  late Set<CcylActivityPhase> _phases;
  late int _minClassHour;
  late String _level;
  late String _org;

  @override
  void initState() {
    super.initState();
    _phases = {...widget.current.phases};
    _minClassHour = widget.current.minClassHour;
    _level = widget.current.level;
    _org = widget.current.org;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ccylFilter,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(l10n.ccylFilterStatus),
                    _buildPhaseChips(l10n),
                    _buildSectionTitle(l10n.ccylFilterClassHour),
                    _buildMinHourChips(l10n),
                    if (widget.levelOptions.isNotEmpty) ...[
                      _buildSectionTitle(l10n.ccylFilterLevel),
                      _buildLevelChips(l10n),
                    ],
                    if (widget.orgOptions.isNotEmpty) ...[
                      _buildSectionTitle(l10n.ccylFilterOrganizer),
                      _buildOrgSelector(l10n),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _phases.clear();
                        _minClassHour = 0;
                        _level = '';
                        _org = '';
                      });
                    },
                    child: Text(l10n.ccylFilterReset),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        CcylActivityFilter(
                          phases: _phases,
                          minClassHour: _minClassHour,
                          level: _level,
                          org: _org,
                        ),
                      );
                    },
                    child: Text(l10n.ccylFilterApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPhaseChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CcylActivityPhase.values.map((phase) {
        final selected = _phases.contains(phase);
        return FilterChip(
          selected: selected,
          onSelected: (value) {
            setState(() {
              value ? _phases.add(phase) : _phases.remove(phase);
            });
          },
          label: Text(ccylPhaseLabel(l10n, phase)),
        );
      }).toList(),
    );
  }

  Widget _buildMinHourChips(AppLocalizations l10n) {
    const options = [0, 1, 2, 3, 4];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((hours) {
        return ChoiceChip(
          selected: _minClassHour == hours,
          onSelected: (_) => setState(() => _minClassHour = hours),
          label: Text(
            hours == 0
                ? l10n.ccylFilterUnlimited
                : l10n.ccylFilterMinHoursValue(hours),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLevelChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          selected: _level.isEmpty,
          onSelected: (_) => setState(() => _level = ''),
          label: Text(l10n.ccylFilterUnlimited),
        ),
        ...widget.levelOptions.map(
          (option) => ChoiceChip(
            selected: _level == option.code,
            onSelected: (_) => setState(() => _level = option.code),
            label: Text(option.name),
          ),
        ),
      ],
    );
  }

  Widget _buildOrgSelector(AppLocalizations l10n) {
    final selectedName = _orgNameOf(_org) ?? _org;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShapes.small),
      ),
      title: Text(
        _org.isEmpty ? l10n.ccylFilterUnlimited : selectedName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _pickOrg,
    );
  }

  String? _orgNameOf(String orgNo) {
    for (final org in widget.orgOptions) {
      if (org.orgNo == orgNo) return org.orgName;
    }
    return null;
  }

  Future<void> _pickOrg() async {
    final selected = await showDialog<CyclOrg>(
      context: context,
      builder: (_) =>
          _CcylOrgPickerDialog(orgs: widget.orgOptions, selectedOrgNo: _org),
    );
    if (selected == null) return;
    setState(() => _org = selected.orgNo);
  }
}

/// 主办方选择弹窗：列表可能很长，带关键字过滤。
class _CcylOrgPickerDialog extends StatefulWidget {
  final List<CyclOrg> orgs;
  final String selectedOrgNo;

  const _CcylOrgPickerDialog({required this.orgs, required this.selectedOrgNo});

  @override
  State<_CcylOrgPickerDialog> createState() => _CcylOrgPickerDialogState();
}

class _CcylOrgPickerDialogState extends State<_CcylOrgPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _keyword.isEmpty
        ? widget.orgs
        : widget.orgs
              .where(
                (org) =>
                    org.orgName.toLowerCase().contains(_keyword) ||
                    org.orgNo.contains(_keyword),
              )
              .toList();

    return AlertDialog(
      title: Text(l10n.ccylFilterChooseOrganizer),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.ccylFilterSearchOrganizer,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _keyword = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(l10n.ccylFilterNoOrganizer))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final org = filtered[index];
                        return ListTile(
                          dense: true,
                          selected: org.orgNo == widget.selectedOrgNo,
                          title: Text(
                            org.orgName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, org),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
