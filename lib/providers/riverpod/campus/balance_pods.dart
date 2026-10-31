import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/scu_backend/payapp/balance_query_service.dart';

part 'balance_pods.g.dart';

@Riverpod(keepAlive: true)
class BalanceQueryNotifier extends _$BalanceQueryNotifier {
  @override
  bool updateShouldNotify(
    BalanceQueryProvider previous,
    BalanceQueryProvider next,
  ) =>
      true;

  @override
  BalanceQueryProvider build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    final payappApi = ref.watch(payAppApiServiceBridge);
    final db = ref.watch(databaseServiceBridge);
    final payAppAuth = ref.watch(payAppAuthBridge);
    final provider = BalanceQueryProvider(
      prefs,
      payappApi,
      db,
      payAppAuth,
      autoSampleOnLogin: () => ref.read(autoSampleBalanceOnLoginSettingProvider),
    );
    ref.onDispose(provider.dispose);

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }

  List<RoomBinding> get bindings => state.bindings;

  int get currentIndex => state.currentIndex;

  RoomBinding? get currentBinding => state.currentBinding;

  bool get isSwitching => state.isSwitching;

  BalanceResourceState<RoomInfo> balanceStateFor(int balanceType) =>
      state.balanceStateFor(balanceType);

  RoomInfo? balanceInfoFor(int balanceType) =>
      state.balanceInfoFor(balanceType);

  RoomInfo? get electricInfo => state.electricInfo;

  RoomInfo? get acInfo => state.acInfo;

  BalanceResourceState<List<CampusItem>> get campusState => state.campusState;

  BalanceResourceState<List<BuildingItem>> buildingState(String schoolCode) =>
      state.buildingState(schoolCode);

  BalanceResourceState<List<UnitItem>> unitState(
    String schoolCode,
    String regCode,
  ) =>
      state.unitState(schoolCode, regCode);

  BalanceTrendState trendStateFor({
    required int balanceType,
    DateTime? since,
    DateTime? until,
  }) =>
      state.trendStateFor(
        balanceType: balanceType,
        since: since,
        until: until,
      );

  Future<void> addBinding(RoomBinding binding) => state.addBinding(binding);

  Future<void> removeBinding(int index) => state.removeBinding(index);

  Future<void> switchBinding(int index) => state.switchBinding(index);

  Future<RoomInfo> ensureBalance(int balanceType) =>
      state.ensureBalance(balanceType);

  Future<RoomInfo> refreshBalance(int balanceType) =>
      state.refreshBalance(balanceType);

  void ensureCurrentBalances() => state.ensureCurrentBalances();

  Future<RoomInfo> queryElectricInfo() => state.queryElectricInfo();

  Future<RoomInfo> queryAcInfo() => state.queryAcInfo();

  Future<List<CampusItem>> getCampusList() => state.getCampusList();

  Future<List<BuildingItem>> getArchitectureList(String schoolCode) =>
      state.getArchitectureList(schoolCode);

  Future<List<UnitItem>> getUnitList(String schoolCode, String regCode) =>
      state.getUnitList(schoolCode, regCode);

  Future<bool> verifyRoom(
    String cusNo,
    int type,
    String cusName,
    String schoolCode,
    String regCode,
    String unitCode,
    String roomNo,
  ) =>
      state.verifyRoom(
        cusNo,
        type,
        cusName,
        schoolCode,
        regCode,
        unitCode,
        roomNo,
      );

  Future<void> ensureTrend({
    required int balanceType,
    DateTime? since,
    DateTime? until,
    bool force = false,
  }) =>
      state.ensureTrend(
        balanceType: balanceType,
        since: since,
        until: until,
        force: force,
      );
}
