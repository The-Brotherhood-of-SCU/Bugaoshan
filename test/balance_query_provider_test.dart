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

  test(
    'removing an earlier binding preserves selection and clears balances',
    () async {
      final bindings = [_binding('A'), _binding('B'), _binding('C')];
      SharedPreferences.setMockInitialValues({
        'balance_query_binding': jsonEncode(
          bindings.map((binding) => binding.toJson()).toList(),
        ),
        'balance_query_current_room': 1,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      final dbService = DatabaseService.forTesting(db);
      await dbService.ensureBalanceRecordsTableForTesting();
      final getIt = GetIt.instance;
      getIt.registerSingleton<AuthLogger>(AuthLogger());
      final scuAuth = ScuAuth(prefs);
      final wfwAuth = WfwAuth(scuAuth);
      final payAppAuth = PayAppAuth(scuAuth, wfwAuth);
      final appConfig = AppConfigProvider(prefs);
      await appConfig.init();
      addTearDown(getIt.reset);
      final provider = BalanceQueryProvider(
        prefs,
        _FakePayAppApiService(),
        dbService,
        payAppAuth,
        appConfig,
      );

      await provider.queryElectricInfo();
      await provider.queryAcInfo();
      expect(provider.electricInfo, isNotNull);
      expect(provider.acInfo, isNotNull);

      await provider.removeBinding(0);

      expect(provider.currentIndex, 0);
      expect(provider.currentBinding?.roomNo, 'B');
      expect(provider.electricInfo, isNull);
      expect(provider.acInfo, isNull);
      expect(prefs.getInt('balance_query_current_room'), 0);
    },
  );
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

class _FakePayAppApiService implements PayAppApiService {
  @override
  Future<List<CampusItem>> getCampus() async => const [];

  @override
  Future<List<BuildingItem>> getArchitecture(String schoolCode) async =>
      const [];

  @override
  Future<List<UnitItem>> getUnit(String schoolCode, String regCode) async =>
      const [];

  @override
  Future<RoomInfo> queryRoomInfo({
    required String cusNo,
    required int type,
    required String cusName,
  }) async => RoomInfo(
    cusNo: cusNo,
    cusName: cusName,
    roomNo: 'room',
    schoolName: '校区',
    regName: '楼栋',
    unitName: '单元',
    price: '1',
    balance: '10',
  );

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
