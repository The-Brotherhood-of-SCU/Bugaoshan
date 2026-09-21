{{flutter_js}}
{{flutter_build_config}}

// 使用本次构建自带的 CanvasKit；相对 base href 解析，兼容子目录部署。
// 不传 serviceWorkerSettings，ArkWeb 直接加载容器内的最新资源。
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href
  }
});
