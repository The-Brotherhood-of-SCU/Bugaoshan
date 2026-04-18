import 'package:flutter/material.dart';
import 'package:Bugaoshan/l10n/app_localizations.dart';
import 'package:Bugaoshan/pages/campus/classroom/classroom_detail_page.dart';
import 'package:Bugaoshan/pages/campus/models/building_model.dart';
import 'package:Bugaoshan/pages/campus/models/room_model.dart';
import 'package:Bugaoshan/pages/campus/services/cir_api_service.dart';

class ClassroomPage extends StatefulWidget {
  const ClassroomPage({super.key});

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  final _apiService = CirApiService();
  List<BuildingModel> _buildings = [];
  String? _selectedCampus;
  BuildingModel? _selectedBuilding;
  RoomQueryResult? _roomResult;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _buildings = await _apiService.fetchBuildings();
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      setState(() {
        _error = e is CampusNetworkException
            ? 'campusNetworkRequired'
            : e.toString();
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  Future<void> _queryBuilding(BuildingModel building) async {
    setState(() {
      _isLoading = true;
      _selectedBuilding = building;
      _error = null;
    });
    try {
      _roomResult = await _apiService.fetchRoomData(building.location);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is CampusNetworkException
            ? 'campusNetworkRequired'
            : e.toString();
        _isLoading = false;
      });
    }
  }

  List<BuildingModel> get _filteredBuildings {
    if (_selectedCampus == null) return _buildings;
    return _buildings.where((b) => b.xqh == _selectedCampus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.classroomQuery)),
      body: Column(
        children: [
          _buildCampusFilter(),
          const Divider(height: 1),
          Expanded(child: _buildContent(l10n)),
        ],
      ),
    );
  }

  Widget _buildCampusFilter() {
    final l10n = AppLocalizations.of(context)!;
    final campuses = [
      {'code': '01', 'name': '望江'},
      {'code': '02', 'name': '华西'},
      {'code': '03', 'name': '江安'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectCampus,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.allBuildings),
                selected: _selectedCampus == null,
                onSelected: (_) {
                  setState(() {
                    _selectedCampus = null;
                  });
                },
              ),
              ...campuses.map(
                (c) => FilterChip(
                  label: Text(c['name'] as String),
                  selected: _selectedCampus == c['code'],
                  onSelected: (_) {
                    setState(() {
                      _selectedCampus = c['code'] as String;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_isInitialLoad && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _buildings.isEmpty) {
      return _buildErrorWidget(l10n, _loadBuildings);
    }

    if (_selectedBuilding != null && _roomResult != null && !_isLoading) {
      return _buildRoomList(l10n);
    }

    if (_isLoading && _selectedBuilding != null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _selectedBuilding != null) {
      return _buildErrorWidget(l10n, () => _queryBuilding(_selectedBuilding!));
    }

    return _buildBuildingList(l10n);
  }

  Widget _buildBuildingList(AppLocalizations l10n) {
    final buildings = _filteredBuildings;

    if (buildings.isEmpty) {
      return Center(
        child: Text(
          '该校区暂无教学楼数据',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: buildings.length,
      itemBuilder: (context, index) {
        final building = buildings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: Text(building.name),
            subtitle: Text(building.campusName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _queryBuilding(building),
          ),
        );
      },
    );
  }

  Widget _buildRoomList(AppLocalizations l10n) {
    if (_roomResult == null) return const SizedBox.shrink();

    final rooms = _roomResult!.rooms;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedBuilding = null;
                    _roomResult = null;
                  });
                },
              ),
              Expanded(
                child: Text(
                  _selectedBuilding!.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${rooms.length} 间教室',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassroomDetailPage(
                          building: _selectedBuilding!,
                          room: room,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.roomName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${room.seatCount} ${l10n.seats}',
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(5, (i) {
                              final classInfo = i < room.classUses.length
                                  ? room.classUses[i]
                                  : null;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Tooltip(
                                  message: '第${i + 1}大节',
                                  child: Icon(
                                    _getPeriodIcon(classInfo),
                                    color: _getPeriodColor(classInfo),
                                    size: 24,
                                  ),
                                ),
                              );
                            }),
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
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
                _error == 'campusNetworkRequired'
                    ? l10n.campusNetworkRequired
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

  IconData _getPeriodIcon(ClassUseInfo? classInfo) {
    if (classInfo == null) return Icons.remove_circle_outline;
    if (classInfo.isBorrowed) return Icons.lock_outline;
    if (classInfo.isInUse) return Icons.school;
    return Icons.check_circle_outline;
  }

  Color _getPeriodColor(ClassUseInfo? classInfo) {
    if (classInfo == null) return Colors.grey;
    if (classInfo.isBorrowed) return Colors.orange;
    if (classInfo.isInUse) return Colors.red;
    return Colors.green;
  }
}
