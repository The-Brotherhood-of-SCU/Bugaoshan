import { url } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { BridgeError, WireBytes, decodeBytes, encodeBytes, requireObject } from './BridgeProtocol';

interface ClientArguments {
  clientId: string;
}

interface HttpArguments extends ClientArguments {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: WireBytes;
  followRedirects?: boolean;
  maxRedirects?: number;
  persistentConnection?: boolean;
  timeoutMs?: number;
}

interface HttpResponse {
  statusCode: number;
  headers: Record<string, string[]>;
  body: WireBytes;
  isRedirect: boolean;
  reasonPhrase?: string;
}

function createSession(): rcp.Session {
  // 不配置 cookies / CookieRepository，也不使用 WebCookieManager 的 Cookie。
  return rcp.createSession({
    cacheControl: { noCache: true, noStore: true },
    requestConfiguration: {
      transfer: { autoRedirect: false },
      tracing: { verbose: false }
    }
  });
}

function closeSession(session: rcp.Session): void {
  try {
    session.close();
  } catch (error) {
    hilog.warn(0x0000, 'NativeHttp', '关闭会话失败，错误码 %{public}d', (error as BusinessError).code);
  }
}

class HttpOperation {
  readonly session: rcp.Session;
  request?: rcp.Request;
  cancellation?: BridgeError;
  rejectCancellation?: (error: BridgeError) => void;

  constructor(session: rcp.Session) {
    this.session = session;
  }

  cancel(error: BridgeError): void {
    if (this.cancellation !== undefined) {
      return;
    }
    this.cancellation = error;
    this.rejectCancellation?.(error);
    if (this.request !== undefined) {
      try {
        this.session.cancel(this.request);
      } catch (failure) {
        hilog.warn(0x0000, 'NativeHttp', '取消请求失败，错误码 %{public}d', (failure as BusinessError).code);
      }
    }
  }

  checkCancellation(): void {
    const failure = this.cancellation;
    if (failure !== undefined) {
      throw failure;
    }
  }
}

class HttpClient {
  readonly session: rcp.Session = createSession();
  readonly operations: Set<HttpOperation> = new Set<HttpOperation>();

  close(): void {
    for (const operation of this.operations) {
      operation.cancel(new BridgeError('http_closed', 'HTTP 客户端已关闭'));
    }
    closeSession(this.session);
  }
}

function parseTarget(address: string, base?: string): url.URL {
  let target: url.URL;
  try {
    target = new url.URL(address, base);
  } catch {
    throw new BridgeError('http_invalid_request', 'HTTP 地址无效');
  }
  // 当前认证与业务接口均使用川大域名，教务系统需要 HTTP。
  const hostname = target.hostname.toLowerCase();
  const isCampusHost = hostname === 'scu.edu.cn' || hostname.endsWith('.scu.edu.cn');
  const isHttp = target.protocol === 'http:' || target.protocol === 'https:';
  const defaultPort = target.protocol === 'https:' ? '443' : '80';
  if (!isHttp || !isCampusHost || target.username !== '' || target.password !== '' ||
    (target.port !== '' && target.port !== defaultPort)) {
    throw new BridgeError('http_forbidden', '原生网络桥接只允许访问川大业务域名的 HTTP/HTTPS 默认端口');
  }
  return target;
}

function readHeaders(value: Record<string, string>): Record<string, string> {
  requireObject(value);
  const headers: Record<string, string> = {};
  for (const name of Object.keys(value)) {
    const content = value[name];
    if (!/^[!#$%&'*+.^_\x60|~0-9A-Za-z-]+$/.test(name) ||
      typeof content !== 'string' || /[\r\n\u0000]/.test(content)) {
      throw new BridgeError('http_invalid_request', 'HTTP 请求头无效');
    }
    const normalized = name.toLowerCase();
    // 由网络库根据实际目标及正文计算这两个传输字段。
    if (normalized !== 'host' && normalized !== 'content-length') {
      headers[normalized] = content;
    }
  }
  return headers;
}

function responseHeaders(response: rcp.Response): Record<string, string[]> {
  const result: Record<string, string[]> = {};
  for (const name of Object.keys(response.headers)) {
    const value = response.headers[name];
    if (value === undefined) {
      continue;
    }
    const values: string[] = typeof value === 'string' ? [value] : value;
    const key = name.toLowerCase();
    const previous = result[key];
    // Set-Cookie 保留各原始字段；Expires 内的逗号不是字段分隔符。
    result[key] = previous === undefined ? values.slice() : previous.concat(values);
  }
  return result;
}

function omitHeaders(headers: Record<string, string>, names: string[]): Record<string, string> {
  const result: Record<string, string> = {};
  for (const name of Object.keys(headers)) {
    if (!names.includes(name)) {
      result[name] = headers[name];
    }
  }
  return result;
}

export class NativeHttp {
  private clients: Map<string, HttpClient> = new Map<string, HttpClient>();
  private closedClients: Set<string> = new Set<string>();
  private disposed: boolean = false;

  private clientId(value: Object): string {
    const args = requireObject(value) as ClientArguments;
    if (typeof args.clientId !== 'string' || args.clientId.length === 0 || args.clientId.length > 128) {
      throw new BridgeError('http_invalid_request', 'clientId 无效');
    }
    return args.clientId;
  }

  async request(value: Object): Promise<Object> {
    const id = this.clientId(value);
    if (this.disposed || this.closedClients.has(id)) {
      throw new BridgeError('http_closed', 'HTTP 客户端已关闭');
    }
    const args = value as HttpArguments;
    if (typeof args.url !== 'string' || typeof args.method !== 'string' ||
      !/^(GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS)$/.test(args.method)) {
      throw new BridgeError('http_invalid_request', 'HTTP 方法或地址无效');
    }
    const target = parseTarget(args.url);
    const headers = readHeaders(args.headers);
    const body = decodeBytes(args.body);
    const timeout = args.timeoutMs ?? 15000;
    const maxRedirects = args.maxRedirects ?? 5;
    if (!Number.isInteger(timeout) || timeout <= 0 || timeout > 120000 ||
      !Number.isInteger(maxRedirects) || maxRedirects < 0 || maxRedirects > 50) {
      throw new BridgeError('http_invalid_request', 'HTTP 超时或重定向次数无效');
    }
    let client = this.clients.get(id);
    if (client === undefined) {
      client = new HttpClient();
      this.clients.set(id, client);
    }
    // 禁用连接复用的请求使用独立 session，结束时不会影响同 clientId 的其他请求。
    const session = args.persistentConnection === false ? createSession() : client.session;
    const operation = new HttpOperation(session);
    client.operations.add(operation);
    const cancellation = new Promise<HttpResponse>((_resolve, reject) => {
      operation.rejectCancellation = (error: BridgeError): void => reject(error);
    });
    const timer = setTimeout(() => {
      // 只记录方法、域名、请求 ID 和时限，避免输出 URL 参数、Cookie 或登录正文。
      hilog.warn(0x0000, 'NativeHttp', '%{public}s %{public}s 请求超时，requestId=%{public}s，timeoutMs=%{public}d',
        args.method, target.hostname, operation.request?.id ?? '-', timeout);
      operation.cancel(new BridgeError('http_timeout', '原生 HTTP 请求超时'));
    }, timeout);
    try {
      return await Promise.race([
        this.fetch(args, target, headers, body, maxRedirects, timeout, operation),
        cancellation
      ]);
    } catch (error) {
      operation.checkCancellation();
      if (error instanceof BridgeError) {
        throw error as BridgeError;
      }
      const code = (error as BusinessError).code;
      hilog.warn(0x0000, 'NativeHttp', '%{public}s %{public}s 请求失败，requestId=%{public}s，code=%{public}d',
        args.method, target.hostname, operation.request?.id ?? '-', code);
      if (code === 1007900028) {
        throw new BridgeError('http_timeout', '原生 HTTP 请求超时');
      }
      if (code === 1007900401 || code === 401) {
        throw new BridgeError('http_invalid_request', '原生网络请求参数无效');
      }
      // 不记录 URL、请求头和正文，也不在原生层额外重试。
      throw new BridgeError('http_transport', '原生 HTTP 传输失败，错误码 ' + code);
    } finally {
      clearTimeout(timer);
      operation.rejectCancellation = undefined;
      client.operations.delete(operation);
      if (args.persistentConnection === false) {
        closeSession(session);
      }
    }
  }

  private async fetch(
    args: HttpArguments,
    target: url.URL,
    headers: Record<string, string>,
    body: Uint8Array,
    maxRedirects: number,
    timeout: number,
    operation: HttpOperation
  ): Promise<HttpResponse> {
    let current = target;
    let method = args.method;
    let content = body;
    for (let hop = 0; ; hop++) {
      operation.checkCancellation();
      const buffer = content.buffer.slice(content.byteOffset, content.byteOffset + content.byteLength) as ArrayBuffer;
      const nativeHeaders: rcp.RequestHeaders = {};
      for (const name of Object.keys(headers)) {
        nativeHeaders[name] = headers[name];
      }
      const request = new rcp.Request(current.href, method, nativeHeaders,
        content.length === 0 && (method === 'GET' || method === 'HEAD') ? undefined : buffer);
      request.configuration = {
        transfer: { autoRedirect: false, timeout: { connectMs: timeout, transferMs: timeout } }
      };
      operation.request = request;
      const response = await operation.session.fetch(request);
      operation.checkCancellation();
      const returnedHeaders = responseHeaders(response);
      const location = returnedHeaders['location'];
      const isRedirect = [301, 302, 303, 307, 308].includes(response.statusCode);
      if (args.followRedirects !== true || !isRedirect || location === undefined || location.length === 0) {
        const bytes = response.body === undefined ? new Uint8Array(0) : new Uint8Array(response.body);
        return {
          statusCode: response.statusCode,
          headers: returnedHeaders,
          body: encodeBytes(bytes),
          isRedirect: isRedirect,
          reasonPhrase: response.reasonPhrase
        };
      }
      if (hop >= maxRedirects) {
        throw new BridgeError('http_redirect_limit', 'HTTP 重定向次数超过上限');
      }
      // 关闭 RCP 自动跳转，每一跳重新限制目标，防止跳出可访问域名。
      const next = parseTarget(location[0], current.href);
      if (next.origin !== current.origin) {
        headers = omitHeaders(headers, ['authorization', 'proxy-authorization', 'cookie']);
      }
      if (current.protocol === 'https:' && next.protocol === 'http:') {
        headers = omitHeaders(headers, ['referer']);
      }
      if ((response.statusCode === 303 && method !== 'HEAD') ||
        ((response.statusCode === 301 || response.statusCode === 302) && method === 'POST')) {
        method = 'GET';
        content = new Uint8Array(0);
        headers = omitHeaders(headers, ['content-type', 'content-encoding']);
      }
      current = next;
    }
  }

  close(value: Object): Object | null {
    const id = this.clientId(value);
    this.closedClients.add(id);
    this.clients.get(id)?.close();
    this.clients.delete(id);
    return null;
  }

  dispose(): void {
    this.disposed = true;
    for (const client of this.clients.values()) {
      client.close();
    }
    this.clients.clear();
    this.closedClients.clear();
  }
}
