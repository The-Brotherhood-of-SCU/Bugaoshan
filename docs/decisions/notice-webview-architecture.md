# 通知公告技术选型

日期: 2026-05-17

## 背景

校园模块需要展示多个来源的通知公告，包括教务处（jwc.scu.edu.cn）和学工部（xgb.scu.edu.cn）。两套页面风格不同，且均为服务端渲染的 HTML 页面。

## 方案对比

### 方案 A：HTML 解析渲染（JWC 当前方案）

教务处通知采用此方案：

- 使用 HTTP 客户端请求 HTML，解析 DOM 提取标题、发布时间、正文等内容
- 将 HTML 正文转换为 Flutter widget 树进行渲染

**缺点：**

- **维护成本高**：官网 HTML 结构无规范，每个页面需单独编写解析逻辑
- **渲染不一致**：HTML → Flutter widget 的转换难以完美覆盖所有样式，表格、图片、特殊排版经常出现偏差
- **脆弱**：官网 HTML 结构调整会导致解析代码失效，需反复适配

### 方案 B：WebView + JS 注入（学工部当前方案）

学工部通知采用此方案：

- 直接通过 WebView 加载官网页面
- 注入 JavaScript 脚本适配深色模式、移动端布局
- 通过 `WebView` 拦截下载请求，由 Flutter 端接管文件下载

**优点：**

- **免解析**：直接展示官网页面，无需关心 HTML 结构变化
- **渲染保真**：保留官网原始样式，深色模式通过 JS 脚本注入 CSS 变量适配
- **下载可靠**：WebView 环境下等同于真实浏览器请求，绕过服务端反爬风控
- **维护成本低**：官网改版只需调整注入的 JS 适配脚本

但用户体验会稍差，动画、响应速度会慢一点。

### JS 注入实现

在每个页面加载完成后 (`onLoadStop`)，Flutter 端执行注入脚本 (`evaluateJavascript`)，核心工作：

**1. 样式重置与移动端适配**
```js
// 清除官网原有样式，从头注入
document.querySelectorAll('link[rel="stylesheet"], style').forEach(el => el.remove());
// 注入自定义 CSS — 隐藏无关元素、卡片化列表、响应式图片
var css = document.createElement('style');
css.textContent = `
  .header, .footer, .left-menu { display: none !important; }
  .news-list { background: #fff; border-radius: 12px; margin: 8px 16px; ... }
  img { max-width: 100%; height: auto; }
  ...
`;
document.head.appendChild(css);
```

**2. 深色模式** — 通过 `@media (prefers-color-scheme: dark)` 查询系统主题，覆盖背景色、文字色、卡片色为深色系：
```css
@media (prefers-color-scheme: dark) {
  body { background: #121212; color: #e0e0e0; }
  .news-list { background: #1e1e1e; }
  ...
}
```

**3. 附件提取** — 扫描页面中的下载链接 (`a[href*="download.jsp"]`)，通过 `flutter_inappwebview.callHandler` 将 URL 和文件名传给 Flutter 端，Flutter 用 `DownloadManager` 接管下载：
```js
var items = [];
document.querySelectorAll('a[href*="download.jsp"]').forEach(function(a) {
  items.push({ url: ..., name: btoa(name) });
  a.style.cssText = '...'; // 美化下载按钮样式
});
window.flutter_inappwebview.callHandler('AttachmentsChannel', JSON.stringify(items));
```

**4. DOM Ready 通知** — JS 执行完毕后通过 `callHandler('DOMReady')` 通知 Flutter 移除 loading 状态，确保页面完全渲染后才显示：
```js
// dom_ready.js — 双重 requestAnimationFrame 确保布局稳定后通知
requestAnimationFrame(() => {
  requestAnimationFrame(() => {
    window.flutter_inappwebview.callHandler('DOMReady');
  });
});
```

## 结论

| 维度 | HTML 解析（JWC） | WebView（学工部） |
|------|-----------------|-------------------|
| 开发成本 | 高 | 低 |
| 维护成本 | 高（结构脆弱） | 低（只需维护 JS 脚本） |
| 渲染一致性 | 差 | 好 |
| 下载可靠性 | 低（易触发风控） | 高 |
| 性能 | 好（原生组件） | 中等（WebView 开销） |


后续新增通知来源统一采用 **WebView + JS 注入** 方案。
