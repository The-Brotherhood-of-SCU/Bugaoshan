import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BridgeError, BridgeRequest, errorResponse, requireObject, successResponse } from './BridgeProtocol';
import { NativeDatabase } from './NativeDatabase';
import { NativeHttp } from './NativeHttp';

interface BridgeInfo {
  version: number;
  capabilities: string[];
}

export class NativeBridge {
  private context?: common.Context;
  private database?: NativeDatabase;
  private http?: NativeHttp;
  private lifecycle: Promise<void> = Promise.resolve();
  private disposed: boolean = false;

  attach(context: common.Context): void {
    this.context = context;
    this.disposed = false;
  }

  // 注册在 javaScriptProxy.methodList；返回 Promise<string>，不能放入没有返回值的 asyncMethodList。
  async invoke(requestJson: string): Promise<string> {
    let request: BridgeRequest;
    try {
      request = requireObject(JSON.parse(requestJson) as Object) as BridgeRequest;
    } catch {
      return errorResponse(new BridgeError('invalid_request', '桥接请求必须是 JSON 对象'));
    }
    try {
      if (request.version !== 1) {
        throw new BridgeError('unsupported_version', '仅支持桥接协议版本 1');
      }
      if (this.disposed || this.context === undefined) {
        throw new BridgeError('bridge_closed', '鸿蒙桥接尚未挂载或页面已关闭');
      }
      if (request.method === 'bridge.info') {
        await this.startSession();
        const info: BridgeInfo = { version: 1, capabilities: ['database', 'http'] };
        return successResponse(info);
      }
      await this.lifecycle;
      const database = this.database;
      const http = this.http;
      if (this.disposed || database === undefined || http === undefined) {
        throw new BridgeError('bridge_not_ready', '请先完成 bridge.info 握手');
      }
      const args = requireObject(request.arguments);
      switch (request.method) {
        case 'database.invoke':
          return successResponse(await database.invoke(args));
        case 'http.request':
          return successResponse(await http.request(args));
        case 'http.close':
          return successResponse(http.close(args));
        default:
          throw new BridgeError('unsupported_method', '不支持的原生桥接方法');
      }
    } catch (error) {
      if (error instanceof BridgeError) {
        return errorResponse(error as BridgeError);
      }
      // 不输出请求 JSON，避免把 Cookie、token 或 SQL 数据写入日志。
      hilog.error(0x0000, 'NativeBridge', '原生桥接调用发生异常');
      return errorResponse(new BridgeError('native_error', '原生桥接调用失败'));
    }
  }

  private startSession(): Promise<void> {
    const result = this.lifecycle.then(async () => {
      // Flutter 页面重新启动时先取消旧请求、回滚未提交事务；数据库文件保留。
      await this.releaseResources();
      const context = this.context;
      if (this.disposed || context === undefined) {
        throw new BridgeError('bridge_closed', '鸿蒙页面已关闭');
      }
      this.database = new NativeDatabase(context);
      this.http = new NativeHttp();
    });
    this.lifecycle = result.then(() => {}, () => {});
    return result;
  }

  private async releaseResources(): Promise<void> {
    const http = this.http;
    const database = this.database;
    this.http = undefined;
    this.database = undefined;
    http?.dispose();
    if (database !== undefined) {
      await database.dispose();
    }
  }

  dispose(): Promise<void> {
    this.disposed = true;
    const result = this.lifecycle.then(() => this.releaseResources());
    this.lifecycle = result.then(() => {}, () => {});
    return result;
  }
}
