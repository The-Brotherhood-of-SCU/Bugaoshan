/**
 * 办事大厅接口抓包脚本（浏览器 Console）
 *
 * 用法：
 *  1. 在浏览器打开并登录 https://service.scu.edu.cn 
 *  2. F12 → Console，粘贴本文件全部内容，回车
 *  3. 常用命令：
 *     __capture.probe()     // 主动探测：自动请求一批已知 GET 接口，保存响应
 *     __capture.start()     // 开始被动捕获：hook fetch/XHR，之后你在页面上正常操作
 *     __capture.stop()      // 停止被动捕获
 *     __capture.dump()      // 导出所有捕获结果（下载 JSON 文件）
 *     __capture.summary()   // 打印已捕获的请求汇总表
 *     __capture.clear()     // 清空已捕获记录
 *
 * 设计说明：
 *  - 主动探测【只包含安全的 GET 接口】，绝不包含 POST 提交类（如 /site/apps/launch），
 *    避免脚本误触发真实请假/事项提交。
 *  - 附件上传、提交等"操作时才触发、URL 未知"的请求，用被动捕获：start() 后去页面
 *    点上传/填表，脚本自动记录。
 *  - 导出文件为 JSON：{collectedAt, base, userAgent, total, requests[]}，
 *    每个 request 含 url/method/status/contentType/ms/response(截断)/json(若可解析)。
 */
(() => {
  'use strict';

  const BASE = location.origin; // 当前域，应为 https://service.scu.edu.cn
  const APP_IDS = [350, 337, 356, 357]; // 350 离校请假 / 337 返校报备 / 356 暑假离校 / 357 留校登记

  const MAX_RESPONSE = 300_000; // 单个响应保存上限（字节），超出截断

  const state = {
    capturing: false,
    requests: [],
  };

  const log = (...a) => console.log('[capture]', ...a);
  const warn = (...a) => console.warn('[capture]', ...a);

  /** 摘要化请求体：FormData 只列字段名，超长文本截断 */
  function bodySummary(body) {
    if (body == null) return undefined;
    if (body instanceof FormData) {
      const keys = [];
      for (const k of body.keys()) keys.push(k);
      return `[FormData keys: ${keys.join(', ')}]`;
    }
    if (typeof body === 'string') {
      return body.length > 50_000 ? `${body.slice(0, 50_000)}...[truncated]` : body;
    }
    return String(body);
  }

  /** 记录一条请求（含响应文本与解析后的 json） */
  function record(rec) {
    if (rec.status == null && !rec.error) return;
    state.requests.push(rec);
  }

  function parseMaybe(text) {
    try {
      return { json: JSON.parse(text), parseError: null };
    } catch (e) {
      return { json: null, parseError: String(e) };
    }
  }

  // ─────────────────── 主动探测 ───────────────────
  const probes = [];

  // 我的申请列表（status: 1 进行中 / 0 草稿 / 3 已完成）
  for (const s of [1, 0, 3]) {
    probes.push({
      name: `inst-list status=${s}`,
      url: `${BASE}/site/process/inst-list?p=1&page_size=20&status=${s}&keyword=&time_lower=&time_upper=&y=&task_name=`,
    });
  }

  // 各事项：表单 schema / 流程信息 / 流程变量 / 发起人部门
  for (const id of APP_IDS) {
    probes.push({
      name: `start-data app=${id}`,
      url: `${BASE}/site/form/start-data?app_id=${id}&node_id=&userview=1&agent_uid=&starter_depart_id=`,
    });
    probes.push({ name: `start-info app=${id}`, url: `${BASE}/site/process/start-info?app_id=${id}` });
    probes.push({ name: `variables app=${id}`, url: `${BASE}/site/process/variables?app_id=${id}` });
    probes.push({ name: `select-department app=${id}`, url: `${BASE}/site/user/select-department?app_id=${id}` });
  }

  async function probe() {
    const before = state.requests.length;
    for (const p of probes) {
      const t0 = performance.now();
      try {
        const resp = await fetch(p.url, {
          credentials: 'same-origin',
          headers: {
            Accept: 'application/json, text/plain, */*',
            'X-Requested-With': 'XMLHttpRequest',
          },
        });
        const text = await resp.text();
        const { json, parseError } = parseMaybe(text);
        const truncated = text.length > MAX_RESPONSE ? `${text.slice(0, MAX_RESPONSE)}\n...[truncated]` : text;
        record({
          name: p.name,
          url: p.url,
          method: 'GET',
          status: resp.status,
          contentType: resp.headers.get('content-type'),
          ms: Math.round(performance.now() - t0),
          response: truncated,
          json,
          parseError,
        });
        log(`${p.name} -> ${resp.status} ${text.length}B`);
      } catch (e) {
        record({ name: p.name, url: p.url, method: 'GET', error: String(e) });
        warn(`${p.name} failed: ${e}`);
      }
    }
    log(`probe done, +${state.requests.length - before} records`);
  }

  // ─────────────────── 被动捕获 ───────────────────
  function hookFetch() {
    const orig = window.fetch;
    if (orig.__captureHooked) return;
    window.fetch = async function (...args) {
      const [input, init = {}] = args;
      const url = typeof input === 'string' ? input : input instanceof Request ? input.url : String(input);
      const method = (init.method || (input instanceof Request ? input.method : 'GET') || 'GET').toUpperCase();
      const body = bodySummary(init.body);
      const t0 = performance.now();
      try {
        const resp = await orig.apply(this, args);
        if (state.capturing) {
          let text = '';
          try { text = await resp.clone().text(); } catch (_) {}
          const { json, parseError } = parseMaybe(text);
          const truncated = text.length > MAX_RESPONSE ? `${text.slice(0, MAX_RESPONSE)}\n...[truncated]` : text;
          record({
            name: 'passive',
            url,
            method,
            body,
            status: resp.status,
            contentType: resp.headers.get('content-type'),
            ms: Math.round(performance.now() - t0),
            response: truncated,
            json,
            parseError,
          });
        }
        return resp;
      } catch (e) {
        if (state.capturing) record({ name: 'passive', url, method, body, error: String(e) });
        throw e;
      }
    };
    Object.defineProperty(window.fetch, '__captureHooked', { value: true });
    log('fetch hooked');
  }

  function hookXhr() {
    const origOpen = XMLHttpRequest.prototype.open;
    const origSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function (method, url, ...rest) {
      this.__cap = { method: (method || 'GET').toUpperCase(), url: String(url) };
      return origOpen.call(this, method, url, ...rest);
    };
    XMLHttpRequest.prototype.send = function (body) {
      const cap = this.__cap || {};
      const t0 = performance.now();
      this.addEventListener('loadend', () => {
        if (!state.capturing) return;
        const text = this.responseText || '';
        const { json, parseError } = parseMaybe(text);
        const truncated = text.length > MAX_RESPONSE ? `${text.slice(0, MAX_RESPONSE)}\n...[truncated]` : text;
        record({
          name: 'passive',
          url: cap.url,
          method: cap.method,
          body: bodySummary(body),
          status: this.status,
          contentType: this.getResponseHeader('content-type'),
          ms: Math.round(performance.now() - t0),
          response: truncated,
          json,
          parseError,
        });
      });
      return origSend.call(this, body);
    };
    log('xhr hooked');
  }

  // ─────────────────── 导出 ───────────────────
  function dump() {
    const payload = {
      collectedAt: new Date().toISOString(),
      base: BASE,
      userAgent: navigator.userAgent,
      total: state.requests.length,
      requests: state.requests,
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `service_capture_${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
    log(`dumped ${state.requests.length} records`);
  }

  function summary() {
    const byName = {};
    for (const r of state.requests) {
      const key = r.name || 'passive';
      byName[key] = (byName[key] || 0) + 1;
    }
    console.table(byName);
    log(`total ${state.requests.length} records`);
  }

  // ─────────────────── 对外 API ───────────────────
  const API = {
    probe,
    start() {
      state.capturing = true;
      hookFetch();
      hookXhr();
      log('passive capture started —— 现在去页面上操作（上传附件 / 填表 / 提交等），完成后执行 __capture.stop()');
    },
    stop() {
      state.capturing = false;
      log(`passive capture stopped, ${state.requests.length} records`);
    },
    clear() {
      state.requests = [];
      log('cleared');
    },
    dump,
    summary,
    get results() {
      return state.requests;
    },
  };
  window.__capture = API;
  log('ready. 命令: __capture.probe() / .start() / .stop() / .dump() / .summary() / .clear()');
})();
