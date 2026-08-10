import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
import 'package:bugaoshan/widgets/common/loading_widgets.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'widgets/balance_list.dart';
import 'widgets/bind_room_dialog.dart';

/// 电费查询入口。
///
/// 页面只负责渲染认证和 [BalanceQueryProvider] 的当前快照；余额、绑定选项
/// 的缓存、加载和错误状态均由 Provider 管理。
class BalanceQueryPage extends StatelessWidget {
  const BalanceQueryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = getIt<BalanceQueryProvider>();
    final auth = getIt<ScuAuthProvider>();
    return ListenableBuilder(
      listenable: Listenable.merge([provider, auth]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.balanceQuery),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.balanceQuerySettings,
                onPressed: () => _showSettingsSheet(context),
              ),
              if (provider.bindings.isNotEmpty)
                PopupMenuButton<int>(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: l10n.switchRoom,
                  onSelected: (index) =>
                      _onRoomSelected(context, provider, auth, index),
                  itemBuilder: (context) =>
                      _roomMenuItems(context, provider, l10n),
                ),
            ],
          ),
          body: _buildBody(context, provider, auth, l10n),
        );
      },
    );
  }

  List<PopupMenuEntry<int>> _roomMenuItems(
    BuildContext context,
    BalanceQueryProvider provider,
    AppLocalizations l10n,
  ) => [
    ...provider.bindings.asMap().entries.map((entry) {
      final index = entry.key;
      final binding = entry.value;
      return PopupMenuItem<int>(
        value: index,
        child: Row(
          children: [
            if (index == provider.currentIndex)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              )
            else
              const SizedBox(width: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                binding.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(context, provider, index);
              },
              tooltip: l10n.deleteRoom,
            ),
          ],
        ),
      );
    }),
    PopupMenuItem<int>(
      value: -1,
      child: Row(
        children: [
          Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(l10n.bindNewRoom),
        ],
      ),
    ),
  ];

  void _onRoomSelected(
    BuildContext context,
    BalanceQueryProvider provider,
    ScuAuthProvider auth,
    int index,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loginRequired)));
      return;
    }
    if (index == -1) {
      _showBindDialog(context, provider);
    } else if (index < 0) {
      _showDeleteConfirmDialog(context, provider, -(index + 2));
    } else {
      _switchBinding(context, provider, index);
    }
  }

  Future<void> _switchBinding(
    BuildContext context,
    BalanceQueryProvider provider,
    int index,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await provider.switchBinding(index);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is BalanceQueryException ? e.message : l10n.networkError,
          ),
        ),
      );
    }
  }

  void _showSettingsSheet(BuildContext context) {
    final appConfig = getIt<AppConfigProvider>();
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                l10n.balanceQuerySettings,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListenableBuilder(
              listenable: appConfig.autoSampleBalanceOnLogin,
              builder: (_, _) => SwitchListTile(
                title: Text(l10n.autoSampleBalanceOnLogin),
                subtitle: Text(l10n.autoSampleBalanceOnLoginDesc),
                value: appConfig.autoSampleBalanceOnLogin.value,
                onChanged: (v) => appConfig.autoSampleBalanceOnLogin.value = v,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BalanceQueryProvider provider,
    ScuAuthProvider auth,
    AppLocalizations l10n,
  ) {
    if (auth.isAutoLoggingIn) return const AutoLoginLoadingWidget();
    if (!auth.isLoggedIn) return const LoginRequiredWidget();

    if (provider.bindings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.balanceQueryNoBinding,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showBindDialog(context, provider),
                icon: const Icon(Icons.add),
                label: Text(l10n.bindRoom),
              ),
            ],
          ),
        ),
      );
    }

    return BalanceList(provider: provider);
  }

  Future<void> _showBindDialog(
    BuildContext context,
    BalanceQueryProvider provider,
  ) async {
    final result = await showDialog<RoomBinding>(
      context: context,
      builder: (context) => BindRoomDialog(provider: provider),
    );
    if (result != null) await provider.addBinding(result);
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    BalanceQueryProvider provider,
    int index,
  ) async {
    if (index < 0 || index >= provider.bindings.length) return;
    final binding = provider.bindings[index];
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRoom),
        content: Text('${l10n.deleteRoom}?\n${binding.displayName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.removeBinding(index);
  }
}
