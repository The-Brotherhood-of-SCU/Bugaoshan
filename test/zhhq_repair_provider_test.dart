import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/repair.dart';
import 'package:bugaoshan/providers/zhhq_repair_provider.dart';
import 'package:bugaoshan/services/api/zhhq_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/zhhq_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<AuthLogger>(AuthLogger());
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('loads addresses when sessions ready', () async {
    final api = _ControllableZhhqApi();
    final provider = _readyProvider(api);

    final request = provider.ensureLoaded();
    expect(api.addressRequests, hasLength(1));

    api.completeAddresses([
      const RepairAddress(
        id: 'addr-1',
        areaName: '望江学生区/东苑五栋',
        addressDetail: '主楼315',
        phone: '18500000000',
        areaId: '10005',
        isCommon: true,
      ),
    ]);
    await request;

    expect(provider.state, RepairLoadState.loaded);
    expect(provider.addresses.single.areaId, '10005');
    // 工单列表独立加载，主加载不触发
    expect(api.ticketRequests, isEmpty);
    provider.dispose();
  });

  test('loadTickets fetches dynamic tickets with userId', () async {
    final api = _ControllableZhhqApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeAddresses([
      const RepairAddress(
        id: 'addr-1',
        areaName: '望江学生区/东苑五栋',
        addressDetail: '主楼315',
        phone: '18500000000',
        areaId: '10005',
        isCommon: true,
        userId: 'user-123',
      ),
    ]);
    await initial;

    final load = provider.loadTickets();
    expect(api.ticketRequests, hasLength(1));
    expect(api.lastTicketUserId, 'user-123');
    api.completeTickets([
      RepairTicket(
        id: 't-1',
        areaName: '望江学生区/东苑五栋',
        projectName: '木/床柜类',
        content: '柜门坏了',
        status: '已关闭',
        createTime: 0,
      ),
    ]);
    await load;

    expect(provider.tickets.single.projectName, '木/床柜类');
    expect(provider.tickets.single.statusLabel, '已关闭');
    provider.dispose();
  });

  test(
    'loads addresses even when SCU session not ready (tokenKey gate)',
    () async {
      final api = _ControllableZhhqApi();
      // SCU 未就绪（如冷启动 token 过期），但 tokenKey 已恢复 → 直接走快速路径
      final scuAuth = _FakeScuAuth(AuthState.unknown);
      final zhhqAuth = _FakeZhhqAuth(true);
      final provider = ZhhqRepairProvider(api, zhhqAuth, scuAuth);

      final request = provider.ensureLoaded();
      expect(api.addressRequests, hasLength(1));

      api.completeAddresses(const []);
      await request;
      expect(provider.state, RepairLoadState.loaded);

      // SCU 恢复就绪后不会重复加载（已 loaded）
      scuAuth.setState(AuthState.ready);
      await Future<void>.delayed(Duration.zero);
      expect(api.addressRequests, hasLength(1));
      provider.dispose();
    },
  );

  test('loads via API self-healing when tokenKey not ready yet', () async {
    final api = _ControllableZhhqApi();
    // tokenKey 尚未建立：Provider 仍发起请求，由 API 层 `getClient()` 走认证
    final scuAuth = _FakeScuAuth(AuthState.ready);
    final zhhqAuth = _FakeZhhqAuth(false);
    final provider = ZhhqRepairProvider(api, zhhqAuth, scuAuth);

    final request = provider.ensureLoaded();
    expect(api.addressRequests, hasLength(1));

    api.completeAddresses(const []);
    await request;
    expect(provider.state, RepairLoadState.loaded);
    provider.dispose();
  });

  test('submit ticket refreshes list on success', () async {
    final api = _ControllableZhhqApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeAddresses(const []);
    await initial;

    final submit = provider.submitTicket({'content': '灯坏了'});
    expect(provider.isSubmitting, isTrue);
    expect(api.submitRequests, hasLength(1));

    api.completeSubmit(0);
    await Future<void>.delayed(Duration.zero);
    // 提交成功后刷新地址
    expect(api.addressRequests, hasLength(2));
    api.completeAddresses(const []);

    expect(await submit, isTrue);
    expect(provider.isSubmitting, isFalse);
    provider.dispose();
  });

  test('submit failure exposes server error message', () async {
    final api = _ControllableZhhqApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeAddresses(const []);
    await initial;

    final submit = provider.submitTicket({'content': '灯坏了'});
    api.failSubmit(0, const ServiceException('请选择维修项目'));

    expect(await submit, isFalse);
    expect(provider.isSubmitting, isFalse);
    expect(provider.submitError, '请选择维修项目');
    provider.dispose();
  });

  test('evaluateRepair 后 force 刷新列表能拿到最新状态', () async {
    final api = _ControllableZhhqApi();
    final provider = _readyProvider(api);

    // 加载地址（含 userId，工单列表依赖它）
    final initial = provider.ensureLoaded();
    api.completeAddresses([
      const RepairAddress(
        id: 'addr-1',
        areaName: '望江学生区/东苑五栋',
        addressDetail: '主楼315',
        phone: '18500000000',
        areaId: '10005',
        isCommon: true,
        userId: 'user-123',
      ),
    ]);
    await initial;

    // 首次加载列表（待评价）
    final load = provider.loadTickets();
    api.completeTickets([
      RepairTicket(
        id: 't-1',
        projectName: '电/线路维修类',
        content: '跳闸',
        status: '待评价',
        createTime: 1,
      ),
    ]);
    await load;
    expect(provider.tickets.single.statusLabel, '待评价');

    // 评价成功后 loadTickets(force: true) 重新拉取
    final refresh = provider.loadTickets(force: true);
    expect(api.ticketRequests, hasLength(2));
    api.completeTickets([
      RepairTicket(
        id: 't-1',
        projectName: '电/线路维修类',
        content: '跳闸',
        status: '已评价',
        createTime: 1,
      ),
    ]);
    await refresh;
    expect(provider.tickets.single.statusLabel, '已评价');
    provider.dispose();
  });

  test('evaluateRepair 后列表标记过期，返回列表 force 刷新能拿到最新状态', () async {
    final api = _ControllableZhhqApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeAddresses([
      const RepairAddress(
        id: 'addr-1',
        areaName: '望江学生区/东苑五栋',
        addressDetail: '主楼315',
        phone: '18500000000',
        areaId: '10005',
        isCommon: true,
        userId: 'user-123',
      ),
    ]);
    await initial;

    // 首次加载列表（待评价）
    final load = provider.loadTickets();
    api.completeTickets([
      RepairTicket(
        id: 't-1',
        projectName: '电/线路维修类',
        content: '跳闸',
        status: '待评价',
        createTime: 1,
      ),
    ]);
    await load;
    expect(provider.tickets.single.statusLabel, '待评价');

    // 评价成功：provider 只标记列表过期，不立即发请求
    // （服务端写库后需短暂时间同步，刷新时机由 UI 返回列表后决定）
    await provider.evaluateRepair(
      repairId: 'r-1',
      common: const [
        {'id': '1', 'name': '维修质量', 'weight': '50', 'star': 5},
      ],
    );
    expect(api.ticketRequests, hasLength(1));

    // 返回列表后 force 刷新：重新拉取（第 2 次请求），拿到「已评价」
    final refresh = provider.loadTickets(force: true);
    expect(api.ticketRequests, hasLength(2));
    api.completeTickets([
      RepairTicket(
        id: 't-1',
        projectName: '电/线路维修类',
        content: '跳闸',
        status: '已评价',
        createTime: 1,
      ),
    ]);
    await refresh;
    expect(provider.tickets.single.statusLabel, '已评价');
    provider.dispose();
  });

  test('force 刷新在列表加载进行中时等待并重新拉取（不被吞掉）', () async {
    final api = _ControllableZhhqApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeAddresses([
      const RepairAddress(
        id: 'addr-1',
        areaName: '望江学生区/东苑五栋',
        addressDetail: '主楼315',
        phone: '18500000000',
        areaId: '10005',
        isCommon: true,
        userId: 'user-123',
      ),
    ]);
    await initial;

    // 第一次加载（尚未完成）→ 正在加载中
    final firstLoad = provider.loadTickets();
    expect(api.ticketRequests, hasLength(1));

    // 加载进行中立即 force 刷新：不立即发起新请求（先等待第一个完成）
    var forceDone = false;
    final forceRefresh = provider.loadTickets(force: true).then((_) {
      forceDone = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(api.ticketRequests, hasLength(1));

    // 第一个完成；force 等待后重新拉取（发出第二次请求，拿到最新状态）
    api.completeTickets([
      RepairTicket(
        id: 't-1',
        projectName: '电/线路维修类',
        content: '跳闸',
        status: '待评价',
        createTime: 1,
      ),
    ]);
    await firstLoad;
    await Future<void>.delayed(Duration.zero);
    // force 等待后发起了第二次全新拉取
    expect(api.ticketRequests, hasLength(2));
    api.completeTickets([
      RepairTicket(
        id: 't-1',
        projectName: '电/线路维修类',
        content: '跳闸',
        status: '已评价',
        createTime: 1,
      ),
    ]);
    await forceRefresh;
    expect(forceDone, isTrue);
    expect(provider.tickets.single.statusLabel, '已评价');
    provider.dispose();
  });
}

class _FakeZhhqAuth extends ChangeNotifier implements ZhhqAuth {
  _FakeZhhqAuth(this._ready);

  bool _ready;

  @override
  bool get isReady => _ready;

  void setReady(bool ready) {
    _ready = ready;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScuAuth extends ChangeNotifier implements ScuAuth {
  _FakeScuAuth(this._state);

  AuthState _state;

  @override
  AuthState get state => _state;

  @override
  bool get isReady => _state == AuthState.ready;

  void setState(AuthState state) {
    _state = state;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ZhhqRepairProvider _readyProvider(_ControllableZhhqApi api) {
  return ZhhqRepairProvider(
    api,
    _FakeZhhqAuth(true),
    _FakeScuAuth(AuthState.ready),
  );
}

class _ControllableZhhqApi implements ZhhqApiService {
  final addressRequests = <Completer<List<RepairAddress>>>[];
  final ticketRequests = <Completer<List<RepairTicket>>>[];
  final submitRequests = <Completer<void>>[];
  String? lastTicketUserId;

  @override
  Future<List<RepairAddress>> fetchAddresses() {
    final request = Completer<List<RepairAddress>>();
    addressRequests.add(request);
    return request.future;
  }

  @override
  Future<List<RepairTicket>> fetchDynamicTickets({
    required String userId,
    int page = 1,
    int pageSize = 50,
  }) {
    lastTicketUserId = userId;
    final request = Completer<List<RepairTicket>>();
    ticketRequests.add(request);
    return request.future;
  }

  @override
  Future<void> submitTicket(Map<String, dynamic> payload) {
    final request = Completer<void>();
    submitRequests.add(request);
    return request.future;
  }

  void completeAddresses(List<RepairAddress> addresses) {
    addressRequests.last.complete(addresses);
  }

  void completeTickets(List<RepairTicket> tickets) {
    ticketRequests.last.complete(tickets);
  }

  void completeSubmit(int index) {
    submitRequests[index].complete();
  }

  void failSubmit(int index, Object error) {
    submitRequests[index].completeError(error);
  }

  @override
  Future<void> evaluateRepair({
    required String repairId,
    required List<Map<String, dynamic>> common,
    String content = '',
    List<String> labels = const [],
  }) async {
    // 直接成功（测试不关心评价请求体）
  }

  @override
  Future<void> withdrawRepair({required String id}) async {
    // 直接成功
  }

  @override
  Future<List<String>> fetchBookDates() async => const [];

  @override
  Future<List<String>> fetchBookTimes(String date) async => const [];

  @override
  Future<List<RepairProject>> fetchProjects(String areaId) async => const [];

  @override
  Future<RepairAcceptDept?> fetchAcceptDept({
    required String areaId,
    required String projectId,
  }) async {
    return const RepairAcceptDept(
      deptId: 'dept-1',
      deptName: '维修与通讯服务中心望江校区',
      payName: '无偿',
    );
  }

  @override
  Future<List<RepairAreaNode>> fetchAreaTreeNodes() async => const [];

  @override
  Future<void> saveAddress({
    required String areaId,
    required String areaName,
    required String addressDetail,
    required String phone,
    String userName = '',
    bool isCommon = false,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
