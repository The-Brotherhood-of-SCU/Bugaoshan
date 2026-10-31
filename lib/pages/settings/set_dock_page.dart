import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/system_insets.dart';

class SetDockPage extends ConsumerStatefulWidget {
  const SetDockPage({super.key});

  @override
  ConsumerState<SetDockPage> createState() => _SetDockPageState();
}

class _SetDockPageState extends ConsumerState<SetDockPage> {
  late List<String> _visibleIds;

  @override
  void initState() {
    super.initState();
    _visibleIds = List<String>.from(ref.read(visibleDockIdsSettingProvider));
  }

  bool _isVisible(String id) => _visibleIds.contains(id);

  /// 当前学生身份下可见的 dock 项 id（保留 _visibleIds 中的原有顺序）。
  List<String> _visibleIdsForMode(List<CampusItemConfig> availableItems) => [
    for (final id in _visibleIds)
      if (availableItems.any((item) => item.id == id)) id,
  ];

  void _toggleVisibility(String id) {
    final updated = List<String>.from(_visibleIds);
    if (updated.contains(id)) {
      if (id == dockIdProfile) return; // cannot remove profile
      updated.remove(id);
    } else {
      updated.add(id);
    }
    setState(() => _visibleIds = updated);
    ref.read(visibleDockIdsSettingProvider.notifier).update(updated);
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    // 拖拽列表只展示当前身份可见的项，索引基于过滤后列表；
    // 按 id 映射回完整列表，保持不属于当前身份的项不被丢弃。
    final availableItems = allCampusItemsForStudentType(
      ref.read(studentTypeSettingProvider),
    );
    final inMode = _visibleIdsForMode(availableItems);
    if (oldIndex < 0 || oldIndex >= inMode.length) return;
    final id = inMode.removeAt(oldIndex);
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > inMode.length) newIndex = inMode.length;
    inMode.insert(newIndex, id);
    // 不属于当前身份的可见项保留在列表尾部，切回身份时顺序不丢。
    final remaining = _visibleIds.where((x) => !inMode.contains(x)).toList();
    final updated = [...inMode, ...remaining];
    setState(() => _visibleIds = updated);
    ref.read(visibleDockIdsSettingProvider.notifier).update(updated);
  }

  void _resetToDefault() async {
    final confirm = await showYesNoDialog(
      title: AppLocalizations.of(context)!.dockResetConfirm,
      content: '',
    );
    if (confirm == true) {
      ref
          .read(visibleDockIdsSettingProvider.notifier)
          .update(List<String>.from(defaultVisibleDockIds));
      setState(
        () => _visibleIds =
            List<String>.from(ref.read(visibleDockIdsSettingProvider)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final studentType = ref.watch(studentTypeSettingProvider);

    final availableItems = allCampusItemsForStudentType(studentType);
    final inModeIds = _visibleIdsForMode(availableItems);

    // Items shown in the preview bar (in order)
    final previewItems = inModeIds
        .map((id) => campusItemConfigById(id))
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
            height: 64 * MediaQuery.textScalerOf(context).scale(1.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.dockLabel(l10n),
                            maxLines: 1,
                            style: theme.textTheme.labelSmall,
                          ),
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
      itemCount: inModeIds.length,
      onReorderItem: _onReorderItem,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            if (t <= 0.0) return child!;

            // 拖动时只添加柔和阴影和轻微上移，保持与原卡片完全一致的视觉。
            return Transform.translate(
              offset: Offset(0, -2 * t),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppShapes.large),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12 * t),
                      blurRadius: 16 * t,
                      spreadRadius: 0,
                      offset: Offset(0, 8 * t),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final item = campusItemConfigById(inModeIds[index]);
        final isProfile = item.id == dockIdProfile;

        return StyledCard(
          key: ValueKey(item.id),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              item.icon,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              item.dockFullLabel(l10n),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveGlassSwitch(
                  semanticLabel: item.dockFullLabel(l10n),
                  value: _isVisible(item.id),
                  onChanged: isProfile
                      ? null
                      : (_) => _toggleVisibility(item.id),
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    size: 40,
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
      ...availableItems
          .where((item) => !_isVisible(item.id))
          .map(
            (item) => StyledCard(
              key: ValueKey(item.id),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  item.icon,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  item.dockFullLabel(l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: AdaptiveGlassSwitch(
                  semanticLabel: item.dockFullLabel(l10n),
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
              padding: withSystemBottomInset(
                context,
                const EdgeInsets.symmetric(horizontal: 16),
              ),
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
