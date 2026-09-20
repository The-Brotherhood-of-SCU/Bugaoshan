requestAnimationFrame(function () {
  requestAnimationFrame(function () {
    window.flutter_inappwebview.callHandler('DOMReady');
  });
});
