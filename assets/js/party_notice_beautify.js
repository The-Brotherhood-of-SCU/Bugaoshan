(function () {
  // Remove all existing stylesheets and style tags for a clean slate.
  document.querySelectorAll('link[rel="stylesheet"], style').forEach(function (el) { el.remove(); });

  var css = document.createElement('style');
  css.textContent = `
    .header, .M_header, .picture, .left-menu, .location-bar,
    .footer, .door, .link { display: none !important; }
    .listContent { width: 100% !important; padding: 0 !important; margin: 0 !important; }
    .main-box { width: 100% !important; max-width: 640px !important; float: none !important; margin: 0 auto !important; }
    .main-box ul { padding: 0 !important; margin: 0 !important; }
    .news-list {
      background: #fff !important;
      border-radius: 12px !important;
      margin: 8px 16px !important;
      padding: 0 !important;
      list-style: none !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
    }
    .news-list a {
      display: block !important;
      padding: 14px 16px !important;
      text-decoration: none !important;
    }
    .news-list .news-box { }
    .news-list .title { font-size: 16px !important; line-height: 1.5 !important; font-weight: 500 !important; }
    .news-list .title a { color: #333 !important; }
    .news-list .content { font-size: 14px !important; color: #888 !important; margin-top: 4px !important; }
    .date-box {
      display: inline-flex !important;
      align-items: baseline !important;
      gap: 4px !important;
      margin-top: 8px !important;
      padding: 2px 8px !important;
      background: #f5f5f5 !important;
      border-radius: 4px !important;
      font-size: 12px !important;
      color: #999 !important;
    }
    .date-box .date { font-size: 12px !important; font-weight: bold !important; color: #d32f2f !important; }
    .year-month { font-size: 12px !important; color: #999 !important; }
    .page { padding: 16px !important; text-align: center !important; }
    .pb_sys_common {
      display: flex !important;
      align-items: center !important;
      justify-content: center !important;
      flex-wrap: wrap !important;
      gap: 4px !important;
      margin-top: 16px !important;
    }
    .p_pages {
      display: inline-flex !important;
      align-items: center !important;
      gap: 4px !important;
      flex-wrap: wrap !important;
      justify-content: center !important;
    }
    .p_pages .p_fun_d, .p_pages .p_no_d, .p_pages .p_no a, .p_pages .p_fun a, .p_pages .p_dot, .p_pages .p_t {
      display: inline-flex !important;
      align-items: center !important;
      justify-content: center !important;
      min-width: 32px !important;
      height: 32px !important;
      padding: 0 6px !important;
      border-radius: 6px !important;
      font-size: 13px !important;
      text-decoration: none !important;
      box-sizing: border-box !important;
    }
    .p_pages .p_no a, .p_pages .p_fun a {
      background: #fff !important;
      color: #333 !important;
      border: 1px solid #e0e0e0 !important;
    }
    .p_pages .p_no a:hover, .p_pages .p_fun a:hover {
      background: #f5f5f5 !important;
    }
    .p_pages .p_no_d, .p_pages .p_fun_d {
      background: #d32f2f !important;
      color: #fff !important;
      border: 1px solid #d32f2f !important;
      cursor: default !important;
    }
    .p_pages .p_dot {
      color: #999 !important;
      cursor: default !important;
      min-width: 20px !important;
    }
    .p_pages .p_t {
      color: #999 !important;
      font-size: 13px !important;
      margin-left: 4px !important;
      cursor: default !important;
    }
    .p_pages input.p_goto_input {
      width: 48px !important;
      height: 32px !important;
      padding: 0 4px !important;
      border: 1px solid #e0e0e0 !important;
      border-radius: 6px !important;
      text-align: center !important;
      font-size: 13px !important;
      outline: none !important;
      box-sizing: border-box !important;
    }
    .p_pages a.p_goto {
      display: inline-flex !important;
      align-items: center !important;
      justify-content: center !important;
      height: 32px !important;
      padding: 0 10px !important;
      background: #fff !important;
      color: #333 !important;
      border: 1px solid #e0e0e0 !important;
      border-radius: 6px !important;
      font-size: 13px !important;
      text-decoration: none !important;
      cursor: pointer !important;
      box-sizing: border-box !important;
    }
    .pb_sys_common .p_t {
      color: #999 !important;
      font-size: 13px !important;
      cursor: default !important;
    }
    .pb_sys_common .p_goto { display: inline-flex !important; align-items: center !important; gap: 2px !important; }
    .pb_sys_common .p_goto a {
      display: inline-flex !important;
      align-items: center !important;
      justify-content: center !important;
      height: 32px !important;
      padding: 0 10px !important;
      background: #fff !important;
      color: #333 !important;
      border: 1px solid #e0e0e0 !important;
      border-radius: 6px !important;
      font-size: 13px !important;
      text-decoration: none !important;
      cursor: pointer !important;
      box-sizing: border-box !important;
    }
    body { margin: 0 !important; padding: 0 !important; font-family: -apple-system, BlinkMacSystemFont, sans-serif !important; background: #f2f2f2 !important; }

    @media (prefers-color-scheme: dark) {
      body { background: #121212 !important; color: #e0e0e0 !important; }
      h1, h2, h3, h4, h5, h6 { color: #e0e0e0 !important; }
      a { color: #82b1ff !important; }
      td, th { border-color: #333 !important; color: #e0e0e0 !important; background: transparent !important; }
      p, span, strong, em, u, s { color: #e0e0e0 !important; background: transparent !important; }
      input, select, textarea { background: #333 !important; color: #e0e0e0 !important; border-color: #555 !important; }
      .news-list { background: #1e1e1e !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
      .news-list .title a { color: #e0e0e0 !important; }
      .news-list .content { color: #999 !important; }
      .date-box { background: #2a2a2a !important; }
      .date-box .date { color: #ef5350 !important; }
      .year-month { color: #999 !important; }
      .detail-title, .article-title, h1 { border-bottom-color: #333 !important; }
      .p_pages .p_no a, .p_pages .p_fun a { background: #2a2a2a !important; color: #e0e0e0 !important; border-color: #444 !important; }
      .p_pages .p_no a:hover, .p_pages .p_fun a:hover { background: #333 !important; }
      .p_pages .p_no_d, .p_pages .p_fun_d { background: #ef5350 !important; border-color: #ef5350 !important; }
      .p_pages .p_t, .p_pages .p_dot { color: #999 !important; }
      .p_pages input.p_goto_input { background: #333 !important; color: #e0e0e0 !important; border-color: #555 !important; }
      .p_pages a.p_goto { background: #2a2a2a !important; color: #e0e0e0 !important; border-color: #444 !important; }
      .pb_sys_common .p_goto a { background: #2a2a2a !important; color: #e0e0e0 !important; border-color: #444 !important; }
    }

    /* detail page */
    .detail-title, .article-title, h1 {
      font-size: 22px !important;
      font-weight: bold !important;
      line-height: 1.4 !important;
      padding: 16px 16px 12px !important;
      margin: 0 !important;
      border-bottom: 1px solid #ddd !important;
    }
    .v_news_content, .content, .article-content {
      padding: 16px !important;
      font-size: 16px !important;
      line-height: 1.8 !important;
    }
    img { max-width: 100% !important; height: auto !important; }
    table { width: 100% !important; max-width: 100% !important; border-collapse: collapse !important; }
  `;
  document.head.appendChild(css);

  // Extract download attachment links and send to Flutter.
  var items = [];
  document.querySelectorAll('a[href*="download.jsp"]').forEach(function(a) {
    var href = a.getAttribute('href');
    href = href.replace(/&amp;/g, '&');
    if (href.startsWith('/')) href = window.location.origin + href;
    var name = a.textContent.trim();
    items.push({url: href, name: btoa(unescape(encodeURIComponent(name)))});
    a.style.display = 'none';
  });
  if (items.length > 0) {
    AttachmentsChannel.postMessage(JSON.stringify(items));
  }
})();
