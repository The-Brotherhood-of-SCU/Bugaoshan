import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/balance_query_service.dart';

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.loginRequired)),
                  );
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
                Text(
                  l10n.loginRequired,
                  textAlign: TextAlign.center,
                ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.loginRequired)),
                    );
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

    return _BalanceList(provider: _provider);
  }

  Future<void> _showBindDialog() async {
    final result = await showDialog<RoomBinding>(
      context: context,
      builder: (context) => _BindRoomDialog(provider: _provider),
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

class _BalanceList extends StatefulWidget {
  final BalanceQueryProvider provider;

  const _BalanceList({required this.provider});

  @override
  State<_BalanceList> createState() => _BalanceListState();
}

class _BalanceListState extends State<_BalanceList> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final binding = widget.provider.currentBinding;

    if (binding == null) {
      return Center(child: Text(l10n.balanceQueryNoBinding));
    }

    final balanceKey =
        '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}';

    return RefreshIndicator(
      onRefresh: () async {
        await widget.provider.queryElectricInfo();
        await widget.provider.queryAcInfo();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(
            key: ValueKey('electric_$balanceKey'),
            provider: widget.provider,
            balanceType: 2,
            icon: Icons.electric_bolt,
            iconColor: Colors.amber,
            title: l10n.electricityFee,
            unit: '元',
            onRefresh: () => widget.provider.queryElectricInfo(),
            binding: binding,
          ),
          const SizedBox(height: 12),
          _BalanceCard(
            key: ValueKey('ac_$balanceKey'),
            provider: widget.provider,
            balanceType: 1,
            icon: Icons.ac_unit,
            iconColor: Colors.lightBlue,
            title: l10n.acFee,
            unit: '元',
            onRefresh: () => widget.provider.queryAcInfo(),
            binding: binding,
          ),
        ],
      ),
    );
  }
}

class _ElectricityTab extends StatefulWidget {
  final BalanceQueryProvider provider;

  const _ElectricityTab({required this.provider});

  @override
  State<_ElectricityTab> createState() => _ElectricityTabState();
}

class _ElectricityTabState extends State<_ElectricityTab> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final binding = widget.provider.currentBinding;

    if (binding == null) {
      return Center(child: Text(l10n.balanceQueryNoBinding));
    }

    return _BalanceCard(
      key: ValueKey(
        '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}',
      ),
      provider: widget.provider,
      balanceType: 2,
      icon: Icons.electric_bolt,
      iconColor: Colors.amber,
      title: l10n.electricityFee,
      unit: '元',
      onRefresh: () => widget.provider.queryElectricInfo(),
      binding: binding,
    );
  }
}

class _AcTab extends StatefulWidget {
  final BalanceQueryProvider provider;

  const _AcTab({required this.provider});

  @override
  State<_AcTab> createState() => _AcTabState();
}

class _AcTabState extends State<_AcTab> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final binding = widget.provider.currentBinding;

    if (binding == null) {
      return Center(child: Text(l10n.balanceQueryNoBinding));
    }

    return _BalanceCard(
      key: ValueKey(
        '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}',
      ),
      provider: widget.provider,
      balanceType: 1,
      icon: Icons.ac_unit,
      iconColor: Colors.lightBlue,
      title: l10n.acFee,
      unit: '元',
      onRefresh: () => widget.provider.queryAcInfo(),
      binding: binding,
    );
  }
}

class _BalanceCard extends StatefulWidget {
  final BalanceQueryProvider provider;
  final int balanceType;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String unit;
  final Future<RoomInfo> Function() onRefresh;
  final RoomBinding binding;

  const _BalanceCard({
    super.key,
    required this.provider,
    required this.balanceType,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.unit,
    required this.onRefresh,
    required this.binding,
  });

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _isLoading = false;
  String? _error;
  RoomInfo? _localInfo; // 本地持有数据，不依赖父级传入

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onSwitchCompleted);
    _loadBalance();
  }

  @override
  void didUpdateWidget(_BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey =
        '${oldWidget.binding.schoolCode}_${oldWidget.binding.regCode}_${oldWidget.binding.unitCode}_${oldWidget.binding.roomNo}';
    final newKey =
        '${widget.binding.schoolCode}_${widget.binding.regCode}_${widget.binding.unitCode}_${widget.binding.roomNo}';
    if (oldKey != newKey) {
      _localInfo = null;
      _loadBalance();
    }
  }

  void _onSwitchCompleted() {
    if (_localInfo == null && !_isLoading && !widget.provider.isSwitching) {
      _loadBalance();
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onSwitchCompleted);
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (_localInfo != null) return;

    if (widget.provider.isSwitching) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final info = await widget.onRefresh();
      if (mounted) {
        setState(() {
          _localInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Balance load error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forceRefresh() async {
    setState(() {
      _localInfo = null;
    });
    await _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.binding.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _forceRefresh,
                  ),
              ],
            ),
            const Divider(height: 32),
            AnimatedSize(
              duration: appConfigService.cardSizeAnimationDuration.value,
              curve: appCurve,
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : _localInfo == null
                  ? Center(child: Text(l10n.loading))
                  : Column(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(
                                l10n.balance,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _localInfo!.balance,
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              Text(
                                widget.unit,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _infoRow(l10n.roomNumber, _localInfo!.roomNo),
                        _infoRow(l10n.pricePerUnit, '${_localInfo!.price} 元/度'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _BindRoomDialog extends StatefulWidget {
  final BalanceQueryProvider provider;

  const _BindRoomDialog({required this.provider});

  @override
  State<_BindRoomDialog> createState() => _BindRoomDialogState();
}

class _BindRoomDialogState extends State<_BindRoomDialog> {
  int _step = 0;
  bool _isLoading = false;
  String? _error;

  List<CampusItem> _campuses = [];
  CampusItem? _selectedCampus;

  List<BuildingItem> _buildings = [];
  BuildingItem? _selectedBuilding;

  List<UnitItem> _units = [];
  UnitItem? _selectedUnit;
  bool _hasUnits = true;

  final _roomNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCampuses();
  }

  Future<void> _loadCampuses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _campuses = await widget.provider.getCampusList();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Load campuses error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadBuildings() async {
    if (_selectedCampus == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _buildings = [];
      _selectedBuilding = null;
      _units = [];
      _selectedUnit = null;
      _hasUnits = true;
    });

    try {
      _buildings = await widget.provider.getArchitectureList(
        _selectedCampus!.code,
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Load buildings error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadUnits() async {
    if (_selectedCampus == null || _selectedBuilding == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _units = [];
      _selectedUnit = null;
      _hasUnits = true;
    });

    try {
      _units = await widget.provider.getUnitList(
        _selectedCampus!.code,
        _selectedBuilding!.code,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_units.isEmpty) {
            _hasUnits = false;
            if (_step >= 2) {
              _step = 3;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Load units error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _verifyAndBind() async {
    if (_selectedCampus == null ||
        _selectedBuilding == null ||
        (_hasUnits && _selectedUnit == null) ||
        _roomNoController.text.isEmpty) {
      return;
    }

    final auth = getIt<ScuAuthProvider>();
    final cusNo = auth.userNumber ?? '';
    final cusName = auth.userRealname ?? '';

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final unitCode = _hasUnits ? _selectedUnit!.code : '';
    final unitName = _hasUnits ? _selectedUnit!.name : '';

    try {
      final success = await widget.provider.verifyRoom(
        cusNo,
        1,
        cusName,
        _selectedCampus!.code,
        _selectedBuilding!.code,
        unitCode,
        _roomNoController.text,
      );

      if (success && mounted) {
        final binding = RoomBinding(
          cusNo: cusNo,
          cusName: cusName,
          schoolCode: _selectedCampus!.code,
          schoolName: _selectedCampus!.name,
          regCode: _selectedBuilding!.code,
          regName: _selectedBuilding!.name,
          unitCode: unitCode,
          unitName: unitName,
          roomNo: _roomNoController.text,
        );
        Navigator.pop(context, binding);
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '验证失败，请检查信息是否正确';
        });
      }
    } catch (e) {
      debugPrint('Verify error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _roomNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    l10n.bindRoom,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildStepIndicator(l10n),
              const SizedBox(height: 16),
              Flexible(
                child: AnimatedSize(
                  duration: appConfigService.cardSizeAnimationDuration.value,
                  curve: appCurve,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [_buildStepContent(l10n)],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _step--),
                      child: Text(l10n.back),
                    )
                  else
                    const SizedBox(),
                  if (_step < (_hasUnits ? 3 : 2))
                    FilledButton(
                      onPressed: _canProceed() && !_isLoading
                          ? () => setState(() => _step++)
                          : null,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.next),
                    )
                  else
                    FilledButton(
                      onPressed: _canSubmit() && !_isLoading
                          ? _verifyAndBind
                          : null,
                      child: Text(l10n.confirm),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(AppLocalizations l10n) {
    final hasUnits = _hasUnits;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepCircle(0, Icons.location_on, l10n.stepCampus),
          _stepLine(0),
          _stepCircle(1, Icons.business, l10n.stepBuilding),
          _stepLine(1),
          if (hasUnits) ...[
            _stepCircle(2, Icons.home, l10n.stepUnit),
            _stepLine(2),
          ],
          _stepCircle(hasUnits ? 3 : 2, Icons.edit, l10n.stepInfo),
        ],
      ),
    );
  }

  int _effectiveStep(int displayStep) {
    return _hasUnits
        ? displayStep
        : (displayStep < 2 ? displayStep : displayStep + 1);
  }

  Widget _stepCircle(int step, IconData icon, String label) {
    final effectiveStep = _effectiveStep(step);
    final isActive = _step >= effectiveStep;

    return Flexible(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(int afterStep) {
    final isActive = _step > _effectiveStep(afterStep);
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildStepContent(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return _buildCampusSelector(l10n);
      case 1:
        return _buildBuildingSelector(l10n);
      case 2:
        return _hasUnits ? _buildUnitSelector(l10n) : _buildInfoInput(l10n);
      case 3:
        return _buildInfoInput(l10n);
      default:
        return const SizedBox();
    }
  }

  Widget _buildCampusSelector(AppLocalizations l10n) {
    if (_isLoading && _campuses.isEmpty) {
      return placeholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.selectCampus, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ..._campuses.map(
          (campus) => RadioListTile<CampusItem>(
            title: Text(campus.name),
            value: campus,
            groupValue: _selectedCampus,
            onChanged: (value) {
              setState(() {
                _selectedCampus = value;
                _step = 1;
              });
              _loadBuildings();
            },
          ),
        ),
      ],
    );
  }

  Widget placeholder() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildBuildingSelector(AppLocalizations l10n) {
    if (_isLoading && _buildings.isEmpty) {
      return placeholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectBuilding,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ..._buildings.map(
          (building) => RadioListTile<BuildingItem>(
            title: Text(building.name),
            value: building,
            groupValue: _selectedBuilding,
            onChanged: (value) {
              setState(() {
                _selectedBuilding = value;
                _step = 2;
              });
              _loadUnits();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelector(AppLocalizations l10n) {
    if (_isLoading && _units.isEmpty) {
      return placeholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.selectUnit, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ..._units.map(
          (unit) => RadioListTile<UnitItem>(
            title: Text(unit.name),
            value: unit,
            groupValue: _selectedUnit,
            onChanged: (value) {
              setState(() {
                _selectedUnit = value;
                _step = _hasUnits ? 3 : 2;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoInput(AppLocalizations l10n) {
    final auth = getIt<ScuAuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.inputBindingInfo,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (auth.userRealname != null && auth.userNumber != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [Text('${auth.userRealname} (${auth.userNumber})')],
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _roomNoController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.roomNumber,
            hintText: l10n.roomNumberHint,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _selectedCampus != null;
      case 1:
        return _selectedBuilding != null;
      case 2:
        return _hasUnits && _selectedUnit != null;
      default:
        return false;
    }
  }

  bool _canSubmit() {
    return _selectedCampus != null &&
        _selectedBuilding != null &&
        (_hasUnits ? _selectedUnit != null : true) &&
        _roomNoController.text.isNotEmpty;
  }
}
