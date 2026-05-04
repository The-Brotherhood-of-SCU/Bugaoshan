import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/balance_query_service.dart';
import 'widgets/balance_list.dart';
import 'widgets/bind_room_dialog.dart';

class BalanceQueryPage extends StatefulWidget {
  const BalanceQueryPage({super.key});

  @override
  State<BalanceQueryPage> createState() => _BalanceQueryPageState();
}

class _BalanceQueryPageState extends State<BalanceQueryPage> {
  late BalanceQueryProvider _provider;
  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _provider = BalanceQueryProvider(getIt());
    _provider.addListener(_onProviderChanged);
    getIt<ScuAuthProvider>().addListener(_onAuthChanged);
    _initProvider();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  void _onAuthChanged() {
    final auth = getIt<ScuAuthProvider>();
    if (auth.isLoggedIn && mounted) {
      _initProvider();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initProvider() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _initError = null;
      });
    }

    final auth = getIt<ScuAuthProvider>();
    if (!auth.isLoggedIn) {
      if (auth.isAutoLoggingIn) return;
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = 'notLoggedIn';
        });
      }
      return;
    }
    try {
      await _provider.getCampusList();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } on BalanceQueryAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.message;
        });
      }
    } catch (e) {
      debugPrint('Balance query init error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = 'networkError';
        });
      }
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    getIt<ScuAuthProvider>().removeListener(_onAuthChanged);
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.balanceQuery),
        actions: [
          if (_provider.bindings.isNotEmpty)
            PopupMenuButton<int>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: l10n.switchRoom,
              onSelected: (index) {
                final auth = getIt<ScuAuthProvider>();
                if (!auth.isLoggedIn) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.loginRequired)));
                  return;
                }
                if (index == -1) {
                  _showBindDialog();
                } else if (index == -2) {
                  _showDeleteAllDialog();
                } else if (index < 0) {
                  _showDeleteConfirmDialog(-(index + 2));
                } else {
                  _provider.switchBinding(index);
                }
              },
              itemBuilder: (context) => [
                ..._provider.bindings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final binding = entry.value;
                  return PopupMenuItem<int>(
                    value: index,
                    child: Row(
                      children: [
                        if (index == _provider.currentIndex)
                          Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          )
                        else
                          const SizedBox(width: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(binding.displayName)),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmDialog(index);
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
              ],
            ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isInitializing) {
      final auth = getIt<ScuAuthProvider>();
      if (auth.isAutoLoggingIn) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.autoLoggingIn),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (_initError != null) {
      if (_initError == 'notLoggedIn') {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.login,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(l10n.loginRequired, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.person),
                  label: Text(l10n.goToLogin),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.loadFailed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initProvider,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_provider.bindings.isEmpty) {
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
                onPressed: () {
                  final auth = getIt<ScuAuthProvider>();
                  if (!auth.isLoggedIn) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.loginRequired)));
                    return;
                  }
                  _showBindDialog();
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.bindRoom),
              ),
            ],
          ),
        ),
      );
    }

    return BalanceList(provider: _provider);
  }

  Future<void> _showBindDialog() async {
    final result = await showDialog<RoomBinding>(
      context: context,
      builder: (context) => BindRoomDialog(provider: _provider),
    );
    if (result != null) {
      await _provider.addBinding(result);
    }
  }

  Future<void> _showDeleteConfirmDialog(int index) async {
    final binding = _provider.bindings[index];
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
    if (confirmed == true) {
      await _provider.removeBinding(index);
    }
  }

  Future<void> _showDeleteAllDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRoom),
        content: Text('${l10n.deleteRoom}?'),
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
    if (confirmed == true) {
      for (int i = _provider.bindings.length - 1; i >= 0; i--) {
        await _provider.removeBinding(i);
      }
    }
  }
}
