import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BRIDGE_PERMISSION, LOCAL_ORIGIN } from '../bridge/BridgeProtocol';
import { NativeBridge } from '../bridge/NativeBridge';

// 此来源的所有请求均由应用响应，资源位于 rawfile/web/。
const MIME_TYPES: Record<string, string> = {
  'html': 'text/html',
  'js': 'application/javascript',
  'mjs': 'application/javascript',
  'json': 'application/json',
  'css': 'text/css',
  'wasm': 'application/wasm',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'woff': 'font/woff',
  'woff2': 'font/woff2',
  'txt': 'text/plain',
  'md': 'text/plain'
};

@Entry
@Component
struct Index {
  private controller: webview.WebviewController = new webview.WebviewController();
  private nativeBridge: NativeBridge = new NativeBridge();

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.nativeBridge.attach(context);
    }
  }

  aboutToDisappear(): void {
    this.nativeBridge.dispose().catch(() => {
      hilog.error(0x0000, 'NativeBridge', '页面关闭时释放原生资源失败');
    });
  }

  private errorResponse(code: number, message: string): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseCode(code);
    response.setReasonMessage(message);
    response.setResponseMimeType('text/plain');
    response.setResponseEncoding('utf-8');
    response.setResponseData(message);
    return response;
  }

  private loadLocalResource(url: string, method: string): WebResourceResponse | null {
    if (url !== LOCAL_ORIGIN && !url.startsWith(LOCAL_ORIGIN + '/')) {
      return null;
    }
    if (method !== 'GET' && method !== 'HEAD') {
      return this.errorResponse(405, 'Method Not Allowed');
    }

    let pathname: string;
    try {
      pathname = decodeURIComponent(url.substring(LOCAL_ORIGIN.length).split(/[?#]/)[0]);
    } catch {
      return this.errorResponse(400, 'Bad Request');
    }
    // 解码后校验，禁止通过相对路径读取 web/ 之外的资源。
    if (/[\\:\u0000]/.test(pathname) || pathname.split('/').includes('..')) {
      return this.errorResponse(403, 'Forbidden');
    }
    const resourcePath = pathname === '' || pathname === '/' ? 'index.html' : pathname.substring(1);
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return this.errorResponse(500, 'Internal Server Error');
    }

    const extension = resourcePath.substring(resourcePath.lastIndexOf('.') + 1).toLowerCase();
    const response = new WebResourceResponse();
    response.setResponseCode(200);
    response.setReasonMessage('OK');
    response.setResponseMimeType(MIME_TYPES[extension] || 'application/octet-stream');
    response.setResponseHeader([{ headerKey: 'Cache-Control', headerValue: 'no-store' }]);
    // 异步读取 JS / WASM 等大文件，避免阻塞页面线程。
    response.setResponseIsReady(false);
    context.resourceManager.getRawFileContent('web/' + resourcePath)
      .then((data: Uint8Array) => {
        const body = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
        response.setResponseData(method === 'HEAD' ? new ArrayBuffer(0) : body);
        response.setResponseIsReady(true);
      })
      .catch((error: BusinessError) => {
        hilog.warn(0x0000, 'LocalWeb', '读取资源失败 %{public}s: %{public}s', resourcePath, error.message);
        // 本地文件不存在时返回 404，不向外网请求该虚拟域名。
        response.setResponseCode(404);
        response.setReasonMessage('Not Found');
        response.setResponseMimeType('text/plain');
        response.setResponseData(method === 'HEAD' ? '' : 'Not Found');
        response.setResponseIsReady(true);
      });
    return response;
  }

  build() {
    Column() {
      Web({ src: LOCAL_ORIGIN + '/index.html', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .javaScriptProxy({
          object: this.nativeBridge,
          name: 'bugaoshanNative',
          methodList: ['invoke'],
          controller: this.controller,
          permission: BRIDGE_PERMISSION
        })
        .onOverrideUrlLoading((request: WebResourceRequest) => {
          const address = request.getRequestUrl();
          return request.isMainFrame() && address !== LOCAL_ORIGIN && !address.startsWith(LOCAL_ORIGIN + '/');
        })
        .onInterceptRequest((event) => {
          if (!event) {
            return null;
          }
          return this.loadLocalResource(event.request.getRequestUrl(), event.request.getRequestMethod());
        })
        .width('100%')
        .height('100%')
    }
    .height('100%')
    .width('100%')
  }
}
