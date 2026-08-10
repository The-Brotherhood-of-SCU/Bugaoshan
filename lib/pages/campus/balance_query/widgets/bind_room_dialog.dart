import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

class BindRoomDialog extends StatefulWidget {
  final BalanceQueryProvider provider;

  const BindRoomDialog({super.key, required this.provider});

  @override
  State<BindRoomDialog> createState() => BindRoomDialogState();
}

class BindRoomDialogState extends State<BindRoomDialog> {
  int _step = 0;
  bool _isVerifying = false;
  String? _verifyError;

  CampusItem? _selectedCampus;

  BuildingItem? _selectedBuilding;

  UnitItem? _selectedUnit;
  bool _hasUnits = true;

  final _roomNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
    _loadCampuses();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCampuses() async {
    try {
      await widget.provider.getCampusList();
    } catch (_) {
      // 错误保留在 Provider 的 campusState 中。
    }
  }

  Future<void> _loadBuildings() async {
    if (_selectedCampus == null) return;

    setState(() {
      _selectedBuilding = null;
      _selectedUnit = null;
      _hasUnits = true;
    });

    try {
      await widget.provider.getArchitectureList(_selectedCampus!.code);
    } catch (_) {
      // 错误保留在 Provider 的 buildingState 中。
    }
  }

  Future<void> _loadUnits() async {
    if (_selectedCampus == null || _selectedBuilding == null) return;

    setState(() {
      _selectedUnit = null;
      _hasUnits = true;
    });

    try {
      final units = await widget.provider.getUnitList(
        _selectedCampus!.code,
        _selectedBuilding!.code,
      );
      if (mounted) {
        setState(() {
          if (units.isEmpty) {
            _hasUnits = false;
            if (_step >= 2) {
              _step = 3;
            }
          }
        });
      }
    } catch (_) {
      // 错误保留在 Provider 的 unitState 中。
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
      _isVerifying = true;
      _verifyError = null;
    });

    final l10n = AppLocalizations.of(context)!;
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
          _isVerifying = false;
          _verifyError = l10n.verifyFailedCheckInfo;
        });
      }
    } catch (e) {
      debugPrint('Verify error: $e');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _verifyError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    _roomNoController.dispose();
    super.dispose();
  }

  bool get _isSelectionLoading {
    if (_step == 0) return widget.provider.campusState.isLoading;
    final campus = _selectedCampus;
    if (campus == null) return false;
    if (_step == 1) return widget.provider.buildingState(campus.code).isLoading;
    if (!_hasUnits) return false;
    final building = _selectedBuilding;
    if (building == null) return false;
    return widget.provider.unitState(campus.code, building.code).isLoading;
  }

  Object? get _selectionError {
    if (_step == 0) return widget.provider.campusState.error;
    final campus = _selectedCampus;
    if (campus == null) return null;
    if (_step == 1) return widget.provider.buildingState(campus.code).error;
    if (!_hasUnits) return null;
    final building = _selectedBuilding;
    if (building == null) return null;
    return widget.provider.unitState(campus.code, building.code).error;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = _isVerifying || _isSelectionLoading;
    final error = _verifyError ?? _selectionError?.toString();

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
              if (error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppShapes.small),
                  ),
                  child: Text(
                    error,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _step--),
                      child: Text(l10n.back),
                    )
                  else
                    const SizedBox(),
                  if (_step < (_hasUnits ? 3 : 2))
                    FilledButton(
                      onPressed: _canProceed() && !isLoading
                          ? () => setState(() => _step++)
                          : null,
                      child: isLoading
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
                      onPressed: _canSubmit() && !isLoading
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
    final state = widget.provider.campusState;
    final campuses = state.value ?? const <CampusItem>[];
    if (state.isLoading && campuses.isEmpty) {
      return placeholder();
    }

    return RadioGroup<CampusItem>(
      groupValue: _selectedCampus,
      onChanged: (value) {
        setState(() {
          _selectedCampus = value;
          _step = 1;
        });
        if (value != null) _loadBuildings();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectCampus,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...campuses.map(
            (campus) => RadioListTile<CampusItem>(
              title: Text(campus.name),
              value: campus,
            ),
          ),
        ],
      ),
    );
  }

  Widget placeholder() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildBuildingSelector(AppLocalizations l10n) {
    final schoolCode = _selectedCampus?.code;
    final state = schoolCode == null
        ? const BalanceResourceState<List<BuildingItem>>()
        : widget.provider.buildingState(schoolCode);
    final buildings = state.value ?? const <BuildingItem>[];
    if (state.isLoading && buildings.isEmpty) {
      return placeholder();
    }

    return RadioGroup<BuildingItem>(
      groupValue: _selectedBuilding,
      onChanged: (value) {
        setState(() {
          _selectedBuilding = value;
          _step = 2;
        });
        if (value != null) _loadUnits();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectBuilding,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...buildings.map(
            (building) => RadioListTile<BuildingItem>(
              title: Text(building.name),
              value: building,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector(AppLocalizations l10n) {
    final schoolCode = _selectedCampus?.code;
    final regCode = _selectedBuilding?.code;
    final state = schoolCode == null || regCode == null
        ? const BalanceResourceState<List<UnitItem>>()
        : widget.provider.unitState(schoolCode, regCode);
    final units = state.value ?? const <UnitItem>[];
    if (state.isLoading && units.isEmpty) {
      return placeholder();
    }

    return RadioGroup<UnitItem>(
      groupValue: _selectedUnit,
      onChanged: (value) {
        setState(() {
          _selectedUnit = value;
          _step = _hasUnits ? 3 : 2;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.selectUnit, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...units.map(
            (unit) =>
                RadioListTile<UnitItem>(title: Text(unit.name), value: unit),
          ),
        ],
      ),
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
              borderRadius: BorderRadius.circular(AppShapes.small),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${auth.userRealname} (${auth.userNumber})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
