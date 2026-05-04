import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/balance_query_service.dart';
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
