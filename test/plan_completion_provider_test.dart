import 'dart:async';

import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
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

  test(
    'summary stats only count root-level modules (pId=-1) matching school hierarchy',
    () {
      // 模拟真实场景：根级模块（pId=-1）包括 001 大类和 002 课程组，
      // 子层分类（002 必修/选修/限选）不参与统计。
      //   公共基础课(001, pId=-1, yxxf=25, sfwc=否)
      //   ├─ 必修(002, pId=cat1, yxxf=25, sfwc=否) ← 子层，不计入
      //   选择性思政(002, pId=-1, yxxf=2, sfwc=是)
      //   ├─ 课程A(kch, pId=sub1)
      //   专业课(001, pId=-1, yxxf=10, sfwc=否)
      //   ├─ 限选(002, pId=cat2, yxxf=2, sfwc=否) ← 子层，不计入
      final nodes = <PlanCompletionNode>[
        PlanCompletionNode.fromJson({
          'id': 'cat1',
          'pId': '-1',
          'flagId': 'cat1',
          'flagType': '001',
          'name': '公共基础课',
          'sfwc': '否',
          'yxxf': '25',
          'zsxf': '27',
        }),
        PlanCompletionNode.fromJson({
          'id': 'sub_classify',
          'pId': 'cat1',
          'flagId': 'sub_c',
          'flagType': '002',
          'name': '必修',
          'sfwc': '否',
          'yxxf': '25',
          'zsxf': '27',
        }),
        PlanCompletionNode.fromJson({
          'id': 'sub1',
          'pId': '-1',
          'flagId': 'sub1',
          'flagType': '002',
          'name': '选择性思政必修课（N选1）',
          'sfwc': '是',
          'yxxf': '2',
          'zsxf': '2',
        }),
        PlanCompletionNode.fromJson({
          'id': 'c1',
          'pId': 'sub1',
          'flagId': 'c1',
          'flagType': 'kch',
          'name': '[102620020]改革开放史[2学分,2024-2025学年春](必修,86.0(20250625))',
          'sfwc': '是',
          'yxxf': '0',
          'zsxf': '0',
        }),
        PlanCompletionNode.fromJson({
          'id': 'cat2',
          'pId': '-1',
          'flagId': 'cat2',
          'flagType': '001',
          'name': '专业课',
          'sfwc': '否',
          'yxxf': '10',
          'zsxf': '40',
        }),
        PlanCompletionNode.fromJson({
          'id': 'sub_classify2',
          'pId': 'cat2',
          'flagId': 'sub_c2',
          'flagType': '002',
          'name': '限选',
          'sfwc': '否',
          'yxxf': '2',
          'zsxf': '9',
        }),
      ];

      final childMap = <String, List<PlanCompletionNode>>{};
      for (final n in nodes) {
        if (n.pId != '-1') {
          childMap.putIfAbsent(n.pId, () => []).add(n);
        }
      }

      final stats = computeSummaryStats(nodes);

      // 根级模块 = 3（cat1 + sub1 + cat2），不含子层分类
      expect(stats.moduleCount, 3);
      // 已完成 = 1（选择性思政）
      expect(stats.completedCount, 1);
      // 已获学分 = 根级模块 yxxf 之和（25 + 2 + 10 = 37）
      expect(stats.totalEarned, 37.0);
    },
  );

  test('summary stats with single root-level module', () {
    // 仅一个根级模块
    final nodes = <PlanCompletionNode>[
      PlanCompletionNode.fromJson({
        'id': 'cat1',
        'pId': '-1',
        'flagId': 'cat1',
        'flagType': '001',
        'name': '公共课',
        'sfwc': '是',
        'yxxf': '6',
        'zsxf': '6',
      }),
      PlanCompletionNode.fromJson({
        'id': 'c1',
        'pId': 'cat1',
        'flagId': 'c1',
        'flagType': 'kch',
        'name': '[101]体育[1学分,2023](必修,90)',
        'sfwc': '是',
        'yxxf': '0',
        'zsxf': '0',
      }),
    ];

    final stats = computeSummaryStats(nodes);

    expect(stats.moduleCount, 1);
    expect(stats.completedCount, 1);
    expect(stats.totalEarned, 6.0);
  });
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
