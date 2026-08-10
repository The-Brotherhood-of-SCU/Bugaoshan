import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
import 'package:bugaoshan/services/api/payapp_api_service.dart';
import 'package:bugaoshan/services/auth/payapp_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('余额在 30 分钟内复用，到期后重新请求', () async {
    var now = DateTime(2026, 8, 10, 12);
    final fakeApi = _FakePayAppApiService();
    final harness = await _createProvider(fakeApi: fakeApi, now: () => now);
    addTearDown(harness.dispose);

    expect(
      (await harness.provider.ensureBalance(kBalanceTypeElectric)).balance,
      '1',
    );
    now = now.add(const Duration(minutes: 29, seconds: 59));
    expect(
      (await harness.provider.ensureBalance(kBalanceTypeElectric)).balance,
      '1',
    );
    expect(fakeApi.queryCalls, 1);

    now = now.add(const Duration(seconds: 1));
    expect(
      (await harness.provider.ensureBalance(kBalanceTypeElectric)).balance,
      '2',
    );
    expect(fakeApi.queryCalls, 2);
  });

  test('手动刷新清空旧值并绕过缓存', () async {
    final pending = Completer<RoomInfo>();
    final fakeApi = _FakePayAppApiService();
    final harness = await _createProvider(fakeApi: fakeApi);
    addTearDown(harness.dispose);

    await harness.provider.ensureBalance(kBalanceTypeElectric);
    fakeApi.pendingQuery = pending;
    final refresh = harness.provider.refreshBalance(kBalanceTypeElectric);

    final loading = harness.provider.balanceStateFor(kBalanceTypeElectric);
    expect(loading.value, isNull);
    expect(loading.isLoading, isTrue);

    pending.complete(_roomInfo(balance: '99'));
    expect((await refresh).balance, '99');
    expect(harness.provider.electricInfo?.balance, '99');
    expect(fakeApi.queryCalls, 2);
  });

  test('同一余额资源的并发加载会合并成一个请求', () async {
    final pending = Completer<RoomInfo>();
    final fakeApi = _FakePayAppApiService()..pendingQuery = pending;
    final harness = await _createProvider(fakeApi: fakeApi);
    addTearDown(harness.dispose);

    final first = harness.provider.ensureBalance(kBalanceTypeElectric);
    final second = harness.provider.ensureBalance(kBalanceTypeElectric);
    expect(fakeApi.queryCalls, 1);

    pending.complete(_roomInfo(balance: '42'));
    final results = await Future.wait([first, second]);
    expect(results.map((result) => result.balance), ['42', '42']);
  });

  test('查询失败不缓存，下一次可恢复', () async {
    final fakeApi = _FakePayAppApiService()..remainingQueryFailures = 1;
    final harness = await _createProvider(fakeApi: fakeApi);
    addTearDown(harness.dispose);

    await expectLater(
      harness.provider.ensureBalance(kBalanceTypeElectric),
      throwsA(isA<BalanceQueryException>()),
    );
    final failed = harness.provider.balanceStateFor(kBalanceTypeElectric);
    expect(failed.value, isNull);
    expect(failed.error, isA<BalanceQueryException>());

    expect(
      (await harness.provider.ensureBalance(kBalanceTypeElectric)).balance,
      '2',
    );
    expect(
      harness.provider.balanceStateFor(kBalanceTypeElectric).error,
      isNull,
    );
    expect(fakeApi.queryCalls, 2);
  });

  test('删除房间只驱逐该房间缓存，保留当前剩余房间', () async {
    final bindings = [_binding('A'), _binding('B'), _binding('C')];
    final harness = await _createProvider(bindings: bindings, currentIndex: 1);
    addTearDown(harness.dispose);

    await harness.provider.ensureBalance(kBalanceTypeElectric);
    await harness.provider.ensureBalance(kBalanceTypeAc);
    expect(harness.provider.electricInfo, isNotNull);
    expect(harness.provider.acInfo, isNotNull);

    await harness.provider.removeBinding(0);

    expect(harness.provider.currentIndex, 0);
    expect(harness.provider.currentBinding?.roomNo, 'B');
    expect(harness.provider.electricInfo, isNotNull);
    expect(harness.provider.acInfo, isNotNull);
  });

  test('校区、楼栋和单元选项在 Provider 生命周期内缓存', () async {
    final fakeApi = _FakePayAppApiService();
    final harness = await _createProvider(fakeApi: fakeApi);
    addTearDown(harness.dispose);

    await harness.provider.getCampusList();
    await harness.provider.getCampusList();
    await harness.provider.getArchitectureList('jiangAn');
    await harness.provider.getArchitectureList('jiangAn');
    await harness.provider.getUnitList('jiangAn', 'west');
    await harness.provider.getUnitList('jiangAn', 'west');

    expect(fakeApi.campusCalls, 1);
    expect(fakeApi.architectureCalls, 1);
    expect(fakeApi.unitCalls, 1);
    expect(harness.provider.campusState.value, isNotEmpty);
    expect(harness.provider.buildingState('jiangAn').value, isNotEmpty);
    expect(harness.provider.unitState('jiangAn', 'west').value, isNotEmpty);
  });
}

Future<_ProviderHarness> _createProvider({
  _FakePayAppApiService? fakeApi,
  List<RoomBinding>? bindings,
  int currentIndex = 0,
  DateTime Function()? now,
}) async {
  final getIt = GetIt.instance;
  await getIt.reset();
  final storedBindings = bindings ?? [_binding('A')];
  SharedPreferences.setMockInitialValues({
    'balance_query_binding': jsonEncode(
      storedBindings.map((binding) => binding.toJson()).toList(),
    ),
    'balance_query_current_room': currentIndex,
  });
  final prefs = await SharedPreferences.getInstance();
  final db = await openDatabase(inMemoryDatabasePath, version: 1);
  final dbService = DatabaseService.forTesting(db);
  await dbService.ensureBalanceRecordsTableForTesting();
  getIt.registerSingleton<AuthLogger>(AuthLogger());
  final scuAuth = ScuAuth(prefs);
  final wfwAuth = WfwAuth(scuAuth);
  final payAppAuth = PayAppAuth(scuAuth, wfwAuth);
  final appConfig = AppConfigProvider(prefs);
  await appConfig.init();
  final provider = BalanceQueryProvider(
    prefs,
    fakeApi ?? _FakePayAppApiService(),
    dbService,
    payAppAuth,
    appConfig,
    now: now,
  );
  return _ProviderHarness(provider, db, getIt);
}

class _ProviderHarness {
  const _ProviderHarness(this.provider, this._db, this._getIt);

  final BalanceQueryProvider provider;
  final Database _db;
  final GetIt _getIt;

  Future<void> dispose() async {
    provider.dispose();
    await _db.close();
    await _getIt.reset();
  }
}

RoomBinding _binding(String roomNo) => RoomBinding(
  cusNo: 'cus-$roomNo',
  cusName: 'name-$roomNo',
  schoolCode: 'school',
  schoolName: '校区',
  regCode: 'building',
  regName: '楼栋',
  unitCode: 'unit',
  unitName: '单元',
  roomNo: roomNo,
);

RoomInfo _roomInfo({required String balance}) => RoomInfo(
  cusNo: 'cus',
  cusName: 'name',
  roomNo: 'room',
  schoolName: '校区',
  regName: '楼栋',
  unitName: '单元',
  price: '1',
  balance: balance,
);

class _FakePayAppApiService implements PayAppApiService {
  int queryCalls = 0;
  int campusCalls = 0;
  int architectureCalls = 0;
  int unitCalls = 0;
  int remainingQueryFailures = 0;
  Completer<RoomInfo>? pendingQuery;

  @override
  Future<List<CampusItem>> getCampus() async {
    campusCalls++;
    return [CampusItem(name: '江安', code: 'jiangAn')];
  }

  @override
  Future<List<BuildingItem>> getArchitecture(String schoolCode) async {
    architectureCalls++;
    return [BuildingItem(name: '西园', code: 'west')];
  }

  @override
  Future<List<UnitItem>> getUnit(String schoolCode, String regCode) async {
    unitCalls++;
    return [UnitItem(name: '一单元', code: 'one')];
  }

  @override
  Future<RoomInfo> queryRoomInfo({
    required String cusNo,
    required int type,
    required String cusName,
  }) {
    queryCalls++;
    final pending = pendingQuery;
    if (pending != null) {
      pendingQuery = null;
      return pending.future;
    }
    if (remainingQueryFailures > 0) {
      remainingQueryFailures--;
      return Future<RoomInfo>.error(BalanceQueryException('查询失败'));
    }
    return Future.value(_roomInfo(balance: '$queryCalls'));
  }

  @override
  Future<bool> verificationRoom({
    required String cusNo,
    required int type,
    required String cusName,
    required String schoolCode,
    required String regCode,
    required String unitCode,
    required String roomNo,
  }) async => true;
}
