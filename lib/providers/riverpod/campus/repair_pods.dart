import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/repair.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/zhhq_repair_provider.dart';

part 'repair_pods.g.dart';

@Riverpod(keepAlive: true)
class RepairNotifier extends _$RepairNotifier {
  @override
  bool updateShouldNotify(
    ZhhqRepairProvider previous,
    ZhhqRepairProvider next,
  ) =>
      true;

  @override
  ZhhqRepairProvider build() {
    final ZhhqRepairProvider provider;
    if (getIt.isRegistered<ZhhqRepairProvider>()) {
      provider = getIt<ZhhqRepairProvider>();
    } else {
      final api = ref.watch(zhhqApiServiceBridge);
      final auth = ref.watch(zhhqAuthBridge);
      final scuAuth = ref.watch(scuAuthBridge);
      final logger = ref.watch(appLoggerBridge);
      provider = ZhhqRepairProvider(api, auth, scuAuth, logger: logger);
      ref.onDispose(provider.dispose);
    }

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }

  Future<void> ensureLoaded() => state.ensureLoaded();

  Future<void> refresh() => state.refresh();

  Future<void> retryAuth() => state.retryAuth();

  Future<void> loadTickets({bool force = false}) =>
      state.loadTickets(force: force);

  Future<RepairTicketDetail> fetchTicketDetail({required String id}) =>
      state.fetchTicketDetail(id: id);

  Future<bool> ifAllowWithdrawRepair({required String id}) =>
      state.ifAllowWithdrawRepair(id: id);

  Future<void> withdrawRepair({required String id}) =>
      state.withdrawRepair(id: id);

  Future<void> evaluateRepair({
    required String repairId,
    required List<Map<String, dynamic>> common,
    String content = '',
    List<String> labels = const [],
  }) =>
      state.evaluateRepair(
        repairId: repairId,
        common: common,
        content: content,
        labels: labels,
      );

  Future<List<RepairEvaluateProject>> fetchEvaluateProjects() =>
      state.fetchEvaluateProjects();

  Future<bool> addAddress({
    required String areaId,
    required String areaName,
    required String addressDetail,
    required String phone,
    String userName = '',
    bool isCommon = false,
  }) =>
      state.addAddress(
        areaId: areaId,
        areaName: areaName,
        addressDetail: addressDetail,
        phone: phone,
        userName: userName,
        isCommon: isCommon,
      );

  Future<String> uploadImage({required File file}) =>
      state.uploadImage(file: file);

  Future<bool> submitTicket(Map<String, dynamic> payload) =>
      state.submitTicket(payload);

  Future<List<String>> fetchBookDates() => state.fetchBookDates();

  Future<List<String>> fetchBookTimes(String date) =>
      state.fetchBookTimes(date);

  Future<List<RepairProject>> fetchProjects(String areaId) =>
      state.fetchProjects(areaId);

  Future<RepairAcceptDept?> fetchAcceptDept({
    required String areaId,
    required String projectId,
  }) =>
      state.fetchAcceptDept(areaId: areaId, projectId: projectId);

  Future<List<RepairAreaNode>> fetchAreaTree() => state.fetchAreaTree();

  void clear() => state.clear();
}
