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
  late List<DockItemConfig> _items;

  @override
  void initState() {
    super.initState();
    _appConfig = getIt<AppConfigProvider>();
    _items = List<DockItemConfig>.from(_appConfig.dockItems.value);
  }

  void _updateItems(List<DockItemConfig> items) {
    setState(() => _items = items);
    _appConfig.dockItems.value = items;
  }

  void _toggleVisibility(int index) {
    final item = _items[index];
    final updated = List<DockItemConfig>.from(_items);
    updated[index] = item.copyWith(isVisible: !item.isVisible);
    _updateItems(updated);
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final updated = List<DockItemConfig>.from(_items);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    // Reassign sort orders
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(sortOrder: i);
    }
    _updateItems(updated);
  }

  void _resetToDefault() async {
    final confirm = await showYesNoDialog(
      title: AppLocalizations.of(context)!.dockResetConfirm,
      content: '',
    );
    if (confirm == true) {
      _appConfig.resetDockToDefault();
      setState(() => _items = List<DockItemConfig>.from(_appConfig.dockItems.value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.customDock)),
      body: Column(
        children: [
          // Dock preview
          Container(
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
                    children: _items
                        .where((item) => item.isVisible)
                        .map((item) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(item.icon, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  _localizeLabel(l10n, item.labelKey),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Drag reorder list
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  key: ValueKey(item.id),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(item.icon, color: theme.colorScheme.primary),
                    title: Text(_localizeLabel(l10n, item.labelKey)),
                    subtitle: item.isDeletable
                        ? null
                        : Text(
                            l10n.cannotDeleteProfile,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.isDeletable)
                          Switch(
                            value: item.isVisible,
                            onChanged: (_) => _toggleVisibility(index),
                          )
                        else
                          Icon(
                            Icons.lock_outline,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        const SizedBox(width: 8),
                        if (item.isDeletable)
                          const Icon(Icons.drag_handle)
                        else
                          const SizedBox(width: 24),
                      ],
                    ),
                  ),
                );
              },
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

  String _localizeLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      dockIdCourse => l10n.course,
      dockIdCampus => l10n.campus,
      dockIdProfile => l10n.profile,
      _ => key,
    };
  }
}
