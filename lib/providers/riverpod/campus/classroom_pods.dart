import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'classroom_pods.g.dart';

class ClassroomIndexData {
  final List<ClassroomCampus> campuses;
  final List<ClassroomBuilding> buildings;

  const ClassroomIndexData({
    required this.campuses,
    required this.buildings,
  });
}

@riverpod
class ClassroomIndexNotifier extends _$ClassroomIndexNotifier {
  @override
  Future<ClassroomIndexData> build() async {
    final api = ref.watch(zhjwApiServiceBridge);
    final res = await api.fetchClassroomIndex();
    return ClassroomIndexData(
      campuses: res.campuses,
      buildings: res.buildings,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(zhjwApiServiceBridge);
      final res = await api.fetchClassroomIndex();
      return ClassroomIndexData(
        campuses: res.campuses,
        buildings: res.buildings,
      );
    });
  }
}

@riverpod
class ClassroomAvailabilityNotifier extends _$ClassroomAvailabilityNotifier {
  @override
  Future<ClassroomQueryResult> build({
    required String campusNumber,
    required String buildingNumber,
    required String searchDate,
  }) async {
    final api = ref.watch(zhjwApiServiceBridge);
    return api.fetchClassroomAvailability(
      campusNumber: campusNumber,
      buildingNumber: buildingNumber,
      searchDate: searchDate,
    );
  }

  Future<void> refresh({
    required String campusNumber,
    required String buildingNumber,
    required String searchDate,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(zhjwApiServiceBridge);
      return api.fetchClassroomAvailability(
        campusNumber: campusNumber,
        buildingNumber: buildingNumber,
        searchDate: searchDate,
      );
    });
  }
}
