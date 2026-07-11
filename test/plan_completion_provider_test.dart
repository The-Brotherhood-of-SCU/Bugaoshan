import 'dart:async';

import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an old account response cannot overwrite the new completion plan',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = _ControllableZhjwApiService();
      final provider = PlanCompletionProvider(prefs, api);

      final oldRequest = provider.fetchPlanCompletion(forceRefresh: true);
      await provider.clearCache();
      final newRequest = provider.fetchPlanCompletion(forceRefresh: true);

      api.requests[1].complete([_node('new-account')]);
      await newRequest;
      expect(provider.nodes.single.id, 'new-account');

      api.requests[0].complete([_node('old-account')]);
      await oldRequest;

      expect(provider.nodes.single.id, 'new-account');
      expect(prefs.getString('plan_completion_nodes'), contains('new-account'));
      expect(
        prefs.getString('plan_completion_nodes'),
        isNot(contains('old-account')),
      );
    },
  );
}

PlanCompletionNode _node(String id) => PlanCompletionNode.fromJson({
  'id': id,
  'pId': '-1',
  'flagId': id,
  'flagType': '001',
  'name': id,
  'sfwc': '否',
  'yxxf': '0',
  'zsxf': '1',
});

class _ControllableZhjwApiService implements ZhjwApiService {
  final requests = <Completer<List<PlanCompletionNode>>>[];

  @override
  Future<List<PlanCompletionNode>> fetchPlanCompletion() {
    final request = Completer<List<PlanCompletionNode>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
