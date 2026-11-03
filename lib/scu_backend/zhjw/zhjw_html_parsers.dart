// 本文件是 `zhjw_api_service.dart` 的 part：存放教务系统 HTML 页面的
// 纯解析函数（与实例状态无关），便于独立阅读与维护。
//
// ⚠️ 不要在此文件引入实例成员依赖（_auth / _request / _checkSessionExpiry）；
// 解析函数只依赖入参与主 library 提供的 import。
part of 'zhjw_api_service.dart';

/// 尝试从 HTML 提取 zNodes 数组。
///
/// 正则未匹配时返回 null（不代表"无方案"，可能是选择页），
/// 匹配成功但 JSON/字段解析失败时抛 [ServiceException]（可诊断错误）。
List<PlanCompletionNode>? _tryParseZNodes(String html) {
  final match = RegExp(
    r'var\s+zNodes\s*=\s*(\[.*?\]);',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) return null;
  return _decodeZNodes(match.group(1)!);
}

/// 解析 zNodes 数组；正则未匹配或解析失败均抛 [ServiceException]。
List<PlanCompletionNode> _parseZNodes(String html) {
  final match = RegExp(
    r'var\s+zNodes\s*=\s*(\[.*?\]);',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) {
    throw const ServiceException('方案修读数据格式异常：未找到 zNodes 数据');
  }
  return _decodeZNodes(match.group(1)!);
}

List<PlanCompletionNode> _decodeZNodes(String jsonStr) {
  try {
    final List<dynamic> list = jsonDecode(jsonStr);
    return list
        .map((e) => PlanCompletionNode.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    throw ServiceException('方案修读数据解析失败：$e');
  }
}

/// 提取方案名（单方案场景，来自 index 页 echarts 雷达图 legend）。
///
/// 页面 JS 形如 `legend: { data: ['某某培养方案'], ... }`。
/// 提取不到时返回空串，由 UI 兜底显示通用名称。
String _extractPlanName(String html) {
  final match = RegExp(
    r"""data:\s*\[\s*'([^']+)'\s*\]""",
    dotAll: true,
  ).firstMatch(html);
  if (match == null) return '';
  final name = match.group(1)!.trim();
  return name.length > 60 ? name.substring(0, 60) : name;
}

/// 从方案选择页提取 `getPyfaIndex/<方案ID>` 入口。
///
/// 教务系统多方案选择页的入口形态（真机抓包确认）：
/// - 按钮：`<button ... title="方案名(方案ID)" onclick="getPyfaIndex('ID');...">`，
///   onclick 中方案 ID 可能带 `&#39;` HTML 实体；
/// - 链接：`<a href="...getPyfaIndex/123...">方案名</a>`（兜底兼容）。
///
/// 返回去重后的入口列表；方案名取自 title 属性或链接文本，无名称时
/// 用 `方案<ID>` 兜底，保证多方案用户至少能看到可区分的名称。
List<_PlanLink> _extractPlanLinks(String html) {
  final links = <_PlanLink>[];
  final seen = <String>{};

  void addPlan(String id, String name) {
    if (!seen.add(id)) return;
    final trimmed = name.trim();
    links.add(
      _PlanLink(
        id: id,
        name: trimmed.isNotEmpty ? trimmed : '方案$id',
        path: '/student/integratedQuery/planCompletion/getPyfaIndex/$id',
      ),
    );
  }

  // 1) 按钮形态：onclick="getPyfaIndex('ID');" + title="方案名(ID)"
  //    真机抓包确认 onclick 里的引号是 &#39; HTML 实体,需显式处理。
  final buttonRe = RegExp(
    r'''onclick=["'][^"']*getPyfaIndex\(\s*(?:&#39;|&quot;|['"])?(\d+)(?:&#39;|&quot;|['"])?\s*\)''',
    dotAll: true,
  );
  for (final m in buttonRe.allMatches(html)) {
    final id = m.group(1)!;
    // 按钮的 title 属性含方案名（如 广播电视编导培养方案(10692)）
    final tagStart = html.lastIndexOf('<button', m.start);
    final tagEnd = html.indexOf('>', m.start);
    if (tagStart >= 0 && tagEnd > tagStart) {
      final tag = html.substring(tagStart, tagEnd);
      final titleMatch = RegExp(r'''title=["']([^"']*)["']''').firstMatch(tag);
      if (titleMatch != null) {
        // title 形如 方案名(10692)，去掉尾部 (ID)
        var name = titleMatch.group(1)!.trim();
        name = name.replaceFirst(RegExp(r'\(\d+\)\s*$'), '').trim();
        addPlan(id, name);
        continue;
      }
    }
    addPlan(id, '方案$id');
  }

  // 2) 链接形态：<a href="...getPyfaIndex/123...">名称</a>
  if (links.isEmpty) {
    final anchorRe = RegExp(
      r"""<a[^>]*href=["'][^"']*getPyfaIndex/(\d+)[^"']*["'][^>]*>(.*?)</a>""",
      dotAll: true,
    );
    for (final m in anchorRe.allMatches(html)) {
      final id = m.group(1)!;
      final rawName = m
          .group(2)!
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
      addPlan(id, rawName);
    }
  }

  // 3) 兜底：非按钮/链接形态（如 JS 字符串）也提取 ID
  if (links.isEmpty) {
    final bareRe = RegExp(r'getPyfaIndex/(\d+)');
    for (final m in bareRe.allMatches(html)) {
      addPlan(m.group(1)!, '方案${m.group(1)}');
    }
  }
  return links;
}

/// 用正则从考表 HTML 中提取考试卡片信息。
List<ExamInfo> _parseExamCards(String html) {
  final cards = <ExamInfo>[];
  final blocks = RegExp(
    r'<div class="widget-box widget-color-\w+(?: collapsed)?">(.*?)'
    r'</div>\s*</div>\s*</div>\s*</div>',
    dotAll: true,
  ).allMatches(html);

  for (final block in blocks) {
    final blockText = block.group(1)!;

    String? firstMatch(RegExp re) {
      final m = re.firstMatch(blockText);
      return m?.group(1)?.trim();
    }

    final courseName =
        (firstMatch(
          RegExp(
            r'<h5 class="widget-title smaller">\s*(.*?)\s*</h5>',
            dotAll: true,
          ),
        )?.replaceAll(RegExp(r'\s*（已结束）'), '').trim()) ??
        '未知';
    final weekNum = firstMatch(RegExp(r'(\d+)周')) ?? '';
    final date = firstMatch(RegExp(r'(\d{4}-\d{2}-\d{2})\s*&nbsp;')) ?? '未知';
    final weekday = firstMatch(RegExp(r'(星期[一二三四五六日])')) ?? '未知';
    final timeRange =
        firstMatch(RegExp(r'&nbsp;(\d{2}:\d{2}-\d{2}:\d{2})')) ?? '未知';
    final locationRaw = firstMatch(RegExp(r'地点:&nbsp;(.+?)</br>')) ?? '未知';
    final location = locationRaw.replaceAll('&nbsp;', ' ');
    final seatNumber = firstMatch(RegExp(r'座位号:&nbsp;(\d+)')) ?? '未知';
    final ticketNumber = firstMatch(RegExp(r'准考证号:&nbsp;(.*?)</br>')) ?? '';
    final tip = firstMatch(RegExp(r'考试提示信息：&nbsp;(.*?)</span>')) ?? '无';

    cards.add(
      ExamInfo(
        courseName: courseName,
        week: weekNum.isNotEmpty ? '第 $weekNum 周' : '未知',
        date: date,
        weekday: weekday,
        timeRange: timeRange,
        location: location,
        seatNumber: seatNumber,
        ticketNumber: ticketNumber,
        tip: tip,
      ),
    );
  }

  return cards;
}

/// 方案选择页链接的解析结果。
class _PlanLink {
  final String id;
  final String name;
  final String path;

  const _PlanLink({required this.id, required this.name, required this.path});
}
