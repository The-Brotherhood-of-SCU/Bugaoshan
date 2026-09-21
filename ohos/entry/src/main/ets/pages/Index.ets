import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { text } from '@kit.ArkGraphics2D';
import { fileIo } from '@kit.CoreFileKit';
import { BRIDGE_PERMISSION, LOCAL_ORIGIN } from '../bridge/BridgeProtocol';
import { NativeBridge } from '../bridge/NativeBridge';
import { NativeViewport } from '../bridge/NativeViewport';

// Flutter 3.44 CanvasKit 的默认字体请求；升级引擎时需核对 canvaskit/fonts.dart。
// 沿用 Roboto 注册名，实际提供 HarmonyOS Sans SC，复用引擎已有的字体加载。
const FLUTTER_DEFAULT_FONT_URL: string =
  'https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2';

interface SystemFontResource {
  data: ArrayBuffer;
  mimeType: string;
}

function harmonyChineseFontPriority(path: string): number {
  const name = path.substring(path.lastIndexOf('/') + 1).replace(/[\s_-]/g, '').toLowerCase();
  if (!/^harmonyossanssc.*\.(ttf|otf)$/.test(name) || /italic|oblique/.test(name)) {
    return -1;
  }
  // 无字重后缀的系统字体及 Regular 优先，其他字重仅在读取失败时尝试。
  return /^harmonyossanssc(regular)?\.(ttf|otf)$/.test(name) ? 0 : 1;
}

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
  private nativeViewport: NativeViewport = new NativeViewport(this.controller);
  private nativeBridge: NativeBridge = new NativeBridge();
  private systemFont?: Promise<SystemFontResource>;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.nativeViewport.attach(context);
      this.nativeBridge.attach(context, this.nativeViewport);
    }
  }

  aboutToDisappear(): void {
    this.systemFont = undefined;
    this.nativeViewport.dispose();
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
    if (url.split(/[?#]/)[0] === FLUTTER_DEFAULT_FONT_URL) {
      return this.loadSystemFont(method);
    }
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

  private loadSystemFont(method: string): WebResourceResponse {
    const response = new WebResourceResponse();
    // URL 属于 Google，但响应由容器提供；浏览器仍会进行跨来源检查。
    response.setResponseHeader([
      { headerKey: 'Access-Control-Allow-Origin', headerValue: LOCAL_ORIGIN },
      { headerKey: 'Cache-Control', headerValue: 'no-store' }
    ]);
    if (method !== 'GET' && method !== 'HEAD') {
      response.setResponseCode(405);
      response.setReasonMessage('Method Not Allowed');
      response.setResponseData('Method Not Allowed');
      return response;
    }
    response.setResponseIsReady(false);
    if (this.systemFont === undefined) {
      // 同一容器实例内复用查询和读取结果，包括并发请求。
      this.systemFont = this.readSystemFont();
    }
    this.systemFont.then((font: SystemFontResource) => {
      response.setResponseCode(200);
      response.setReasonMessage('OK');
      response.setResponseMimeType(font.mimeType);
      response.setResponseData(method === 'HEAD' ? new ArrayBuffer(0) : font.data);
      response.setResponseIsReady(true);
    }).catch((error: BusinessError) => {
      this.systemFont = undefined;
      hilog.error(0x0000, 'SystemFont', '加载 HarmonyOS Sans SC 失败: %{public}s', error.message);
      // 结束这条启动请求，避免失败后又等待 Google；后续缺字仍走引擎的回退机制。
      response.setResponseCode(503);
      response.setReasonMessage('Service Unavailable');
      response.setResponseMimeType('text/plain');
      response.setResponseData(method === 'HEAD' ? '' : 'System font unavailable');
      response.setResponseIsReady(true);
    });
    return response;
  }

  private async readSystemFont(): Promise<SystemFontResource> {
    const startedAt = Date.now();
    // 最低 API 23：只查询配置中的文件路径，避免解析全部字体描述符及可变字体轴。
    const paths = text.getFontPathsByType(text.SystemFontType.GENERIC)
      .filter((path: string) => harmonyChineseFontPriority(path) >= 0);
    // 优先常规字重；只加载一份字体，避免把多个字重都放到首屏之前。
    paths.sort((left: string, right: string) => {
      return harmonyChineseFontPriority(left) - harmonyChineseFontPriority(right) || left.localeCompare(right);
    });
    for (const path of paths) {
      try {
        const resource = await this.readFontFile(path);
        hilog.info(0x0000, 'SystemFont', '已读取 %{public}s: %{public}d 字节, %{public}d ms',
          path, resource.data.byteLength, Date.now() - startedAt);
        return resource;
      } catch (error) {
        hilog.warn(0x0000, 'SystemFont', '读取字体 %{public}s 失败: %{public}s',
          path, (error as BusinessError).message);
      }
    }
    throw new Error('No readable HarmonyOS Sans SC system font found');
  }

  private async readFontFile(path: string): Promise<SystemFontResource> {
    // 路径仅来自系统字体路径接口，不接受网页传入的任意文件路径。
    const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = await fileIo.stat(file.fd);
      if (stat.size < 12) {
        throw new Error('System font file is empty or incomplete');
      }
      const data = new ArrayBuffer(stat.size);
      let offset = await fileIo.read(file.fd, data);
      while (offset < data.byteLength) {
        const remainder = new ArrayBuffer(data.byteLength - offset);
        const count = await fileIo.read(file.fd, remainder);
        if (count <= 0) {
          throw new Error('Unexpected end of system font file');
        }
        new Uint8Array(data).set(new Uint8Array(remainder, 0, count), offset);
        offset += count;
      }
      const signature = new DataView(data).getUint32(0);
      // CanvasKit 此加载入口不能选择 TTC 中的字体索引，避免静默使用集合里的错误字形。
      if (signature !== 0x00010000 && signature !== 0x74727565 && signature !== 0x4F54544F) {
        throw new Error('System font must be a standalone TTF or OTF');
      }
      return { data: data, mimeType: signature === 0x4F54544F ? 'font/otf' : 'font/ttf' };
    } finally {
      await fileIo.close(file);
    }
  }

  build() {
    Column() {
      Web({ src: LOCAL_ORIGIN + '/index.html', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        // 键盘交由 Web 缩小内容区；安全区扩展只针对系统栏和挖孔。
        .keyboardAvoidMode(WebKeyboardAvoidMode.RESIZE_CONTENT)
        .onPageBegin(() => this.nativeViewport.onPageBegin())
        .onPageEnd(() => this.nativeViewport.onPageEnd())
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
        .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP,
          SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    }
    .height('100%')
    .width('100%')
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP,
      SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }
}
