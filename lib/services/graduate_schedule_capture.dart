/// WebView 课表抓取：注入钩子脚本 + 捕获结果解析。
///
/// ## 为什么用这个方案
///
/// 研究生课表页（`ehall.scu.edu.cn/gsapp/sys/wdkbapp/*default/index.do#/xskcb`）
/// 是 SPA：服务器返回的 HTML 只是空壳，课程数据由页面自己的 JS 去请求 `.do`
/// 接口拿到后再画出来。所以「抓 HTML 再解析」拿不到数据，而接口地址又需要
/// 开发者工具去查。
///
/// 这里换个思路：在页面脚本执行**之前**把 `XMLHttpRequest` / `fetch` 换掉，
/// 页面自己去请求时顺手把响应体记下来。这样连接口地址都不必预先知道。
///
/// 钩子只**读取**返回体，不改写任何请求、不碰 cookie、不发新请求。
library;

import 'dart:convert';

/// 捕获结果存放的全局变量名（JS 侧写入，Dart 侧轮询读取）。
const String kGraduateCaptureGlobal = '__bugaoshanGsCapture';

/// 注入时机：文档开始（必须早于页面自己的脚本）。
///
/// 只记录 URL 命中 [kGraduateCaptureUrlPattern] 且响应体是 JSON 的响应，
/// 相同 URL + 相同长度视为重复，避免切周次时把同一份数据记多遍。
const String kGraduateScheduleCaptureScript = r'''
(function () {
  if (window.__bugaoshanGsHook) return;
  window.__bugaoshanGsHook = true;

  var store = (window.__bugaoshanGsCapture = []);
  var MAX_BODY = 2000000;
  var KEEP = /\.do(\?|$)/i;

  function record(url, text) {
    if (typeof text !== "string" || text.length === 0) return;
    if (text.length > MAX_BODY) return;
    var head = text.replace(/^\s+/, "").charAt(0);
    if (head !== "{" && head !== "[") return;
    try { JSON.parse(text); } catch (e) { return; }
    for (var i = 0; i < store.length; i++) {
      if (store[i].url === url && store[i].len === text.length) return;
    }
    store.push({ url: String(url), len: text.length, body: text });
  }

  var origOpen = XMLHttpRequest.prototype.open;
  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (method, url) {
    try { this.__bgsUrl = String(url); } catch (e) {}
    return origOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    var xhr = this;
    var url = xhr.__bgsUrl || "";
    if (KEEP.test(url)) {
      xhr.addEventListener("load", function () {
        try {
          var rt = xhr.responseType;
          if (rt === "" || rt === "text") record(url, xhr.responseText);
        } catch (e) {}
      });
    }
    return origSend.apply(this, arguments);
  };

  var origFetch = window.fetch;
  if (typeof origFetch === "function") {
    window.fetch = function (input, init) {
      var url = typeof input === "string" ? input : ((input && input.url) || "");
      var result = origFetch.apply(this, arguments);
      if (KEEP.test(url)) {
        try {
          result.then(function (res) {
            try {
              res.clone().text().then(function (t) { record(url, t); }, function () {});
            } catch (e) {}
          }, function () {});
        } catch (e) {}
      }
      return result;
    };
  }
})();
''';

/// 轮询表达式：返回捕获数组的 JSON 文本。
const String kGraduateScheduleCaptureQuery =
    'JSON.stringify(window.$kGraduateCaptureGlobal || [])';

/// 只记录命中这个模式的请求（研教务的数据接口都是 `.do`）。
final RegExp kGraduateCaptureUrlPattern = RegExp(
  r'\.do(\?|$)',
  caseSensitive: false,
);

/// 一条被捕获的数据响应。
class GraduateCaptureEntry {
  const GraduateCaptureEntry({required this.url, required this.body});

  /// 数据接口地址（含 query，可能含会话参数，展示前应脱敏）。
  final String url;

  /// 响应体原文。
  final String body;
}

/// 解析 Dart 侧轮询拿到的捕获数组 JSON。
///
/// 结构非法（未注入脚本、页面未产生数据、被清空等）时返回空列表，
/// 调用方据此显示「等待中」而不是报错。
List<GraduateCaptureEntry> graduateCaptureEntriesFrom(String? storeJson) {
  if (storeJson == null || storeJson.isEmpty) return const [];

  final Object? decoded;
  try {
    decoded = jsonDecode(storeJson);
  } catch (_) {
    return const [];
  }
  if (decoded is! List) return const [];

  final entries = <GraduateCaptureEntry>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final body = item['body'];
    if (body is! String || body.isEmpty) continue;
    entries.add(
      GraduateCaptureEntry(url: item['url']?.toString() ?? '', body: body),
    );
  }
  return entries;
}

/// 只取响应体原文，供解析器消费。
List<String> graduateCaptureBodiesFrom(String? storeJson) =>
    graduateCaptureEntriesFrom(storeJson).map((e) => e.body).toList();

/// 抹掉 URL 里的会话参数值，只保留参数名（展示给用户看时用）。
String redactCaptureUrl(String url) {
  return url.replaceAllMapped(
    RegExp(
      r'((?:token|ticket|access_token|jsessionid|sessionid)=)[^&#]*',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}<已隐藏>',
  );
}
