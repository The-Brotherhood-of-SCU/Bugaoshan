import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/classroom/classroom_detail_page.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';
import 'package:bugaoshan/utils/session_expiry_handler.dart';

enum _ViewMode { campus, building, room }

class ClassroomPage extends StatefulWidget {
  const ClassroomPage({super.key});

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  late final ScuAuthService _authService;

  List<ClassroomCampus> _campuses = [];
  List<ClassroomBuilding> _allBuildings = [];
  ClassroomQueryResult? _queryResult;
  ClassroomCampus? _selectedCampus;
  ClassroomBuilding? _selectedBuilding;

  _ViewMode _viewMode = _ViewMode.campus;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _authService = getIt<ScuAuthProvider>().service;
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _authService.fetchClassroomIndex();
      if (!mounted) return;
      setState(() {
        _campuses = result.campuses;
        _allBuildings = result.buildings;
        _isLoading = false;
        _isInitialLoad = false;
      });
    } on ScuLoginException catch (e) {
      if (!mounted) return;
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(getIt<ScuAuthProvider>());
      }
      setState(() {
        _error = e.sessionExpired ? 'sessionExpired' : 'loadFailed';
        _isLoading = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      debugPrint('Classroom index load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'loadFailed';
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  Future<void> _queryBuilding(ClassroomBuilding building) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedBuilding = building;
      _viewMode = _ViewMode.room;
      _error = null;
    });
    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      _queryResult = await _authService.fetchClassroomAvailability(
        campusNumber: building.campusNumber,
        buildingNumber: building.teachingBuildingNumber,
        searchDate: dateStr,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } on ScuLoginException catch (e) {
      if (!mounted) return;
      if (e.sessionExpired) {
        await SessionExpiryHandler.handle(getIt<ScuAuthProvider>());
      }
      setState(() {
        _error = e.sessionExpired ? 'sessionExpired' : 'loadFailed';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Classroom query error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'loadFailed';
        _isLoading = false;
      });
    }
  }

  List<ClassroomBuilding> get _filteredBuildings {
    if (_selectedCampus == null) return [];
    return _allBuildings
        .where((b) => b.campusNumber == _selectedCampus!.campusNumber)
        .toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      if (_selectedBuilding != null) {
        _queryBuilding(_selectedBuilding!);
      }
    }
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDate = today;
    });
    if (_selectedBuilding != null) {
      _queryBuilding(_selectedBuilding!);
    }
  }

  void _goBack() {
    setState(() {
      switch (_viewMode) {
        case _ViewMode.room:
          _viewMode = _ViewMode.building;
          _selectedBuilding = null;
          _queryResult = null;
          _error = null;
          break;
        case _ViewMode.building:
          _viewMode = _ViewMode.campus;
          _selectedCampus = null;
          _error = null;
          break;
        case _ViewMode.campus:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.classroomQuery),
        leading: _viewMode != _ViewMode.campus
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
      ),
      body: _buildContent(l10n),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_isInitialLoad && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _campuses.isEmpty) {
      return _buildErrorWidget(l10n, _loadIndex);
    }

    switch (_viewMode) {
      case _ViewMode.campus:
        return _buildCampusView(l10n);
      case _ViewMode.building:
        return _buildBuildingList(l10n);
      case _ViewMode.room:
        return _buildRoomView(l10n);
    }
  }

  Widget _buildCampusView(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.selectCampus,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _campuses.length,
            itemBuilder: (context, index) {
              final campus = _campuses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.location_city_outlined),
                  title: Text('${campus.campusName}校区'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      _selectedCampus = campus;
                      _viewMode = _ViewMode.building;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingList(AppLocalizations l10n) {
    final buildings = _filteredBuildings;

    if (buildings.isEmpty) {
      return Center(
        child: Text(
          l10n.noData,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.selectBuilding,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: buildings.length,
            itemBuilder: (context, index) {
              final building = buildings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(building.teachingBuildingName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _queryBuilding(building),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoomView(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(l10n, () => _queryBuilding(_selectedBuilding!));
    }

    if (_queryResult == null) return const SizedBox.shrink();

    final rooms = _queryResult!.classrooms;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBuilding!.teachingBuildingName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_queryResult!.jxzc > 0)
                      Text(
                        l10n.classroomTeachingWeek(_queryResult!.jxzc),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${rooms.length} ${l10n.seats == "座" ? "间教室" : "rooms"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 18),
                label: Text(_formatDate(_selectedDate)),
                onPressed: _pickDate,
              ),
              if (!_isToday) ...[
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(l10n.today),
                  onPressed: _goToToday,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: Text(
                    l10n.noData,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return _buildRoomCard(room, l10n);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomCard(ClassroomInfo room, AppLocalizations l10n) {
    final statusMap = _queryResult!.periodStatusMap(room.classroomNumber);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassroomDetailPage(
                campus: _selectedCampus!,
                building: _selectedBuilding!,
                room: room,
                timeSlots: _queryResult!.slotsFor(room.classroomNumber),
                queryDate: _queryResult!.date,
                teachingWeek: _queryResult!.jxzc,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.classroomName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${room.placeNum} ${l10n.seats}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(12, (i) {
                    final period = i + 1;
                    final status =
                        statusMap[period] ?? ClassroomPeriodStatus.free;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Tooltip(
                        message: _periodTooltip(period, status, l10n),
                        child: Icon(
                          _getPeriodIcon(status),
                          color: _getPeriodColor(status),
                          size: 18,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(AppLocalizations l10n, VoidCallback onRetry) {
    return Center(
      child: GestureDetector(
        onTap: onRetry,
        child: SizedBox(
          width: 220,
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
                _error == 'sessionExpired'
                    ? l10n.sessionExpired
                    : l10n.loadFailed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _periodTooltip(
    int period,
    ClassroomPeriodStatus status,
    AppLocalizations l10n,
  ) {
    final label = _getPeriodStatusText(status, l10n);
    return '$period - $label';
  }

  String _getPeriodStatusText(
    ClassroomPeriodStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case ClassroomPeriodStatus.free:
        return l10n.free;
      case ClassroomPeriodStatus.inClass:
        return l10n.inClass;
      case ClassroomPeriodStatus.exam:
        return l10n.classroomPeriodExam;
      case ClassroomPeriodStatus.experiment:
        return l10n.classroomPeriodExperiment;
      case ClassroomPeriodStatus.borrowed:
        return l10n.borrowed;
    }
  }

  IconData _getPeriodIcon(ClassroomPeriodStatus status) {
    switch (status) {
      case ClassroomPeriodStatus.free:
        return Icons.check_circle_outline;
      case ClassroomPeriodStatus.inClass:
        return Icons.school;
      case ClassroomPeriodStatus.exam:
        return Icons.assignment;
      case ClassroomPeriodStatus.experiment:
        return Icons.science;
      case ClassroomPeriodStatus.borrowed:
        return Icons.lock_outline;
    }
  }

  Color _getPeriodColor(ClassroomPeriodStatus status) {
    switch (status) {
      case ClassroomPeriodStatus.free:
        return Colors.green;
      case ClassroomPeriodStatus.inClass:
        return Colors.red;
      case ClassroomPeriodStatus.exam:
        return Colors.orange;
      case ClassroomPeriodStatus.experiment:
        return Colors.purple;
      case ClassroomPeriodStatus.borrowed:
        return Colors.amber;
    }
  }
}
