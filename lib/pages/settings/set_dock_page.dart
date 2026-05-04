import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/dock_item_config.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

class SetDockPage extends StatefulWidget {
  const SetDockPage({super.key});

  @override
  State<SetDockPage> createState() => _SetDockPageState();
}

class _SetDockPageState extends State<SetDockPage> {
  late final AppConfigProvider _appConfig;
  late List<String> _visibleIds;
  late final List<DockItemConfig> _allItems;

  @override
  void initState() {
    super.initState();
    _appConfig = getIt<AppConfigProvider>();
    _visibleIds = List<String>.from(_appConfig.visibleDockIds.value);
    _allItems = allDockItems();
  }

  bool _isVisible(String id) => _visibleIds.contains(id);

  void _toggleVisibility(String id) {
    final updated = List<String>.from(_visibleIds);
    if (updated.contains(id)) {
      if (id == dockIdProfile) return; // cannot remove profile
      updated.remove(id);
    } else {
      updated.add(id);
    }
    setState(() => _visibleIds = updated);
    _appConfig.visibleDockIds.value = updated;
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final updated = List<String>.from(_visibleIds);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _visibleIds = updated);
    _appConfig.visibleDockIds.value = updated;
  }

  void _resetToDefault() async {
    final confirm = await showYesNoDialog(
      title: AppLocalizations.of(context)!.dockResetConfirm,
      content: '',
    );
    if (confirm == true) {
      _appConfig.resetDockToDefault();
      setState(
        () => _visibleIds = List<String>.from(_appConfig.visibleDockIds.value),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Items shown in the preview bar (in order)
    final previewItems = _visibleIds
        .map((id) => _allItems.firstWhere((item) => item.id == id))
        .toList();
    final dockerPreview = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dockPreview,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: previewItems
                  .map(
                    (item) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          dockLabel(item.id, l10n),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
    final visibleItems = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _visibleIds.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final id = _visibleIds[index];
        final item = _allItems.firstWhere((i) => i.id == id);
        final isProfile = item.id == dockIdProfile;

        return Card(
          key: ValueKey(item.id),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(item.icon, color: theme.colorScheme.primary),
            title: Text(dockLabel(item.id, l10n)),
            subtitle: isProfile
                ? Text(
                    l10n.cannotDeleteProfile,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: true,
                  onChanged: isProfile
                      ? null
                      : (_) => _toggleVisibility(item.id),
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final hiddenItems = [
      ..._allItems
          .where((item) => !_isVisible(item.id))
          .map(
            (item) => Card(
              key: ValueKey(item.id),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  item.icon,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(dockLabel(item.id, l10n)),
                trailing: Switch(
                  value: false,
                  onChanged: (_) => _toggleVisibility(item.id),
                ),
              ),
            ),
          ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.customDock)),
      body: Column(
        children: [
          // Dock preview
          dockerPreview,
          const Divider(),
          // Items list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Visible items (reorderable)
                visibleItems,
                const Divider(),
                // Hidden items (toggle only)
                ...hiddenItems,
              ],
            ),
          ),
          // Reset button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.resetDock),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
