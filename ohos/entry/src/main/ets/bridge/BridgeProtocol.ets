import { util } from '@kit.ArkTS';

export const LOCAL_ORIGIN: string = 'https://app.bugaoshan.invalid';
// 空 port 表示使用该 HTTPS 域名；页面导航另外限制到 LOCAL_ORIGIN。
export const BRIDGE_PERMISSION: string =
  '{"javascriptProxyPermission":{"urlPermissionList":[' +
  '{"scheme":"https","host":"app.bugaoshan.invalid","port":"","path":"/"}]}}';

export interface BridgeRequest {
  version: number;
  method: string;
  arguments: Object | null;
}

export interface WireBytes {
  $bytes: string;
}

export type SqlWireValue = string | number | boolean | null | WireBytes;

interface ErrorPayload {
  code: string;
  message: string;
  details: Object | null;
}

interface BridgeResponse {
  ok: boolean;
  result?: Object | null;
  error?: ErrorPayload;
}

export class BridgeError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'BridgeError';
    this.code = code;
  }
}

export function successResponse(result: Object | null): string {
  const response: BridgeResponse = { ok: true, result: result };
  return JSON.stringify(response);
}

export function errorResponse(error: BridgeError): string {
  const response: BridgeResponse = {
    ok: false,
    error: { code: error.code, message: error.message, details: null }
  };
  return JSON.stringify(response);
}

export function requireObject(value: Object | null | undefined): Object {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    throw new BridgeError('invalid_request', '桥接参数必须是对象');
  }
  return value;
}

export function encodeBytes(bytes: Uint8Array): WireBytes {
  return { $bytes: bytes.length === 0 ? '' : new util.Base64Helper().encodeToStringSync(bytes) };
}

export function decodeBytes(value: WireBytes): Uint8Array {
  requireObject(value);
  if (typeof value.$bytes !== 'string' || Object.keys(value).length !== 1) {
    throw new BridgeError('invalid_request', '二进制数据必须使用 $bytes 编码');
  }
  if (value.$bytes.length === 0) {
    return new Uint8Array(0);
  }
  try {
    return new util.Base64Helper().decodeSync(value.$bytes);
  } catch {
    throw new BridgeError('invalid_request', '无效的 Base64 数据');
  }
}
