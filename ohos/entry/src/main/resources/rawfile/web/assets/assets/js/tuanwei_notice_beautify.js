(function () {
  var css = document.createElement('style');
  css.textContent = `
    /* ── Hide site chrome ── */
    .Top, .Tops, .log, .retrieval,
    .naver, .nav,
    .flexslider, #banner_tabs, .slides, .flex-direction-nav, #bannerCtrl,
    .sidenav,
    footer, .footer, .Foot, .foot, .banq, .yq,
    .old_version { display: none !important; }

    body { margin: 0 !important; padding: 0 !important; min-width: 0 !important; width: auto !important; overflow-x: hidden !important; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif !important; background: #f2f2f2 !important; }

    #bg, #bg2 { background: none !important; width: auto !important; min-width: 0 !important; margin: 0 !important; padding: 0 !important; }
    .web { max-width: 640px !important; margin: 0 auto !important; padding: 0 !important; width: auto !important; min-width: 0 !important; float: none !important; }
    .innerbox { padding: 0 !important; width: 100% !important; max-width: none !important; min-width: 0 !important; float: none !important; }

    /* ── List page ── */
    .innerbox > ul {
      list-style: none !important;
      margin: 8px 16px !important;
      padding: 0 !important;
      background: #fff !important;
      border-radius: 12px !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
      overflow: hidden !important;
    }
    .innerbox > ul li {
      padding: 0 !important;
      height: auto !important;
    }
    .innerbox > ul li + li { border-top: 1px solid #eee !important; }
    .innerbox > ul li {
      display: flex !important;
      align-items: flex-start !important;
    }
    .innerbox > ul li a {
      display: flex !important;
      align-items: flex-start !important;
      padding: 14px 16px !important;
      text-decoration: none !important;
      color: #222 !important;
      height: auto !important;
      white-space: normal !important;
      flex: 1 !important;
      min-width: 0 !important;
    }
    .innerbox > ul li .date-box {
      flex-shrink: 0 !important;
      text-align: center !important;
      padding: 6px 10px !important;
      margin-right: 14px !important;
      background: #f5f5f5 !important;
      border-radius: 8px !important;
      line-height: 1.3 !important;
    }
    .innerbox > ul li .date-box .day {
      display: block !important;
      margin: 0 !important;
      font-size: 16px !important;
      font-weight: bold !important;
      color: #d32f2f !important;
    }
    .innerbox > ul li .date-box .ym {
      display: block !important;
      margin: 0 !important;
      font-size: 12px !important;
      color: #999 !important;
    }
    .innerbox > ul li time { display: none !important; }
    .innerbox > ul li .notice-title {
      font-size: 16px !important;
      line-height: 1.6 !important;
      font-weight: 500 !important;
      color: #333 !important;
      word-break: break-all !important;
      overflow-wrap: break-word !important;
    }

    /* ── Pagination ── */
    .pb_sys_common {
      margin: 16px !important;
      display: flex !important;
      align-items: center !important;
      justify-content: center !important;
      flex-wrap: wrap !important;
      gap: 4px !important;
    }
    .p_pages {
      display: inline-flex !important;
      align-items: center !important;
      gap: 4px !important;
      flex-wrap: wrap !important;
      justify-content: center !important;
    }
    .p_pages .p_fun_d, .p_pages .p_no_d, .p_pages .p_no a, .p_pages .p_fun a,
    .p_pages .p_first_d, .p_pages .p_prev_d, .p_pages .p_next a, .p_pages .p_last a,
    .p_pages .p_dot, .p_pages .p_t {
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
    .p_pages .p_no a {
      background: #fff !important;
      color: #333 !important;
      border: 1px solid #e0e0e0 !important;
    }
    .p_pages .p_no a:hover { background: #f5f5f5 !important; }
    .p_pages .p_no_d {
      background: #d32f2f !important;
      color: #fff !important;
      border: 1px solid #d32f2f !important;
      cursor: default !important;
    }
    .p_pages .p_first_d, .p_pages .p_prev_d {
      background: #f5f5f5 !important;
      color: #bbb !important;
      border: 1px solid #e0e0e0 !important;
      cursor: default !important;
    }
    .p_pages .p_next a, .p_pages .p_last a {
      background: #fff !important;
      color: #333 !important;
      border: 1px solid #e0e0e0 !important;
    }
    .p_pages .p_dot { color: #999 !important; cursor: default !important; min-width: 20px !important; }
    .p_t {
      color: #999 !important;
      font-size: 13px !important;
      margin-right: 8px !important;
      white-space: nowrap !important;
    }

    /* ── Detail page ── */
    .innerbox form {
      max-width: 640px !important;
      margin: 0 auto !important;
      padding: 0 !important;
    }
    .innerbox form h3 {
      font-size: 20px !important;
      font-weight: bold !important;
      line-height: 1.4 !important;
      margin: 8px 16px 0 !important;
      padding: 16px 16px 12px !important;
      background: #fff !important;
      border-radius: 12px 12px 0 0 !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
      color: #333 !important;
      text-align: left !important;
    }
    .time {
      margin: 0 16px !important;
      padding: 0 !important;
      font-size: 13px !important;
      color: #999 !important;
      background: #fff !important;
    }
    article[id^="vsb_content"] {
      margin: 0 16px 8px !important;
      padding: 16px !important;
      background: #fff !important;
      border-radius: 0 0 12px 12px !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
      font-size: 16px !important;
      line-height: 1.8 !important;
      color: #333 !important;
      overflow-wrap: break-word !important;
      word-break: break-all !important;
    }
    article[id^="vsb_content"] p {
      margin: 0 0 12px !important;
    }
    .v_news_content {
      font-size: 16px !important;
      line-height: 1.8 !important;
      color: #333 !important;
      overflow-wrap: break-word !important;
      word-break: break-all !important;
    }
    .v_news_content p {
      margin: 0 0 12px !important;
    }
    .innerbox form .page { display: none !important; }
    img { max-width: 100% !important; height: auto !important; float: none !important; display: block !important; margin: 0 auto !important; }
    table { width: 100% !important; max-width: 100% !important; border-collapse: collapse !important; }
    td, th { border: 1px solid #ddd !important; padding: 8px !important; font-size: 14px !important; }

    /* ── Hide misc ── */
    #div_vote_id, .seek { display: none !important; }
    .fjxz {
      padding: 12px 16px !important;
      margin: 0 16px 8px !important;
      background: #fff !important;
      border-radius: 0 0 12px 12px !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
      counter-reset: fjxz-counter !important;
      list-style: none !important;
    }
    .fjxz li {
      margin: 0 !important;
      padding: 4px 0 !important;
      font-size: 14px !important;
      color: #666 !important;
      counter-increment: fjxz-counter !important;
      line-height: 1.6 !important;
    }
    .fjxz li::before {
      content: counter(fjxz-counter) '. ' !important;
      color: #999 !important;
    }
    .fjxz a {
      display: inline !important;
      padding: 0 !important;
      margin: 0 !important;
      background: none !important;
      color: #666 !important;
      border-radius: 0 !important;
      text-decoration: none !important;
      font-size: 14px !important;
      font-weight: normal !important;
    }
    a[href*="download.jsp"] {
      display: inline !important;
      padding: 0 !important;
      margin: 0 !important;
      background: none !important;
      color: #666 !important;
      border-radius: 0 !important;
      text-decoration: none !important;
      font-size: 14px !important;
    }

    /* ── Dark mode ── */
    @media (prefers-color-scheme: dark) {
      body { background: #121212 !important; color: #e0e0e0 !important; }
      h1, h2, h3, h4, h5, h6 { color: #e0e0e0 !important; }
      a { color: #82b1ff !important; }
      td, th { border-color: #333 !important; color: #e0e0e0 !important; background: transparent !important; }
      p, span, strong, em, u, s, time { color: #e0e0e0 !important; background: transparent !important; }
      .innerbox > ul { background: #1e1e1e !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
      .innerbox > ul li + li { border-top-color: #333 !important; }
      .innerbox > ul li a { color: #e0e0e0 !important; }
      .innerbox > ul li .date-box { background: #2a2a2a !important; }
      .innerbox > ul li .date-box .day { color: #ef5350 !important; }
      .innerbox > ul li .notice-title { color: #e0e0e0 !important; }
      .innerbox form h3 { background: #1e1e1e !important; color: #e0e0e0 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
      .time { background: #1e1e1e !important; border-bottom-color: #333 !important; }
      article[id^="vsb_content"] { background: #1e1e1e !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
      .v_news_content { color: #e0e0e0 !important; }
      .p_pages .p_no a { background: #2a2a2a !important; color: #e0e0e0 !important; border-color: #444 !important; }
      .p_pages .p_no a:hover { background: #333 !important; }
      .p_pages .p_no_d { background: #ef5350 !important; border-color: #ef5350 !important; }
      .p_pages .p_first_d, .p_pages .p_prev_d { background: #333 !important; color: #666 !important; border-color: #444 !important; }
      .p_pages .p_next a, .p_pages .p_last a { background: #2a2a2a !important; color: #e0e0e0 !important; border-color: #444 !important; }
      .p_t, .p_dot { color: #666 !important; }
      .fjxz { background: #1e1e1e !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
    }
  `;
  document.head.appendChild(css);

  // ── Force layout reset via JS (override site CSS including !important) ──
  function forceStyle(el, props) {
    if (!el) return;
    for (var k in props) {
      el.style.setProperty(k, props[k], 'important');
    }
  }
  forceStyle(document.body, { 'min-width': '0', width: 'auto', 'max-width': '640px', margin: '0 auto', 'overflow-x': 'hidden' });
  forceStyle(document.getElementById('bg'), { 'min-width': '0', width: 'auto', margin: '0', padding: '0', background: 'none' });
  forceStyle(document.getElementById('bg2'), { 'min-width': '0', width: 'auto', margin: '0', padding: '0', background: 'none' });
  forceStyle(document.querySelector('.web'), { 'min-width': '0', width: 'auto', 'max-width': '640px', margin: '0 auto', padding: '0', float: 'none' });
  forceStyle(document.querySelector('.innerbox'), { 'min-width': '0', width: '100%', 'max-width': 'none', float: 'none', padding: '0' });

  // ── Restructure list items: parse date from <time> into date-box badge ──
  document.querySelectorAll('.innerbox > ul li').forEach(function (li) {
    var time = li.querySelector('time');
    var a = li.querySelector('a');
    if (!time || !a) return;
    var dateText = time.textContent.trim(); // e.g., "2026年05月20日"
    var match = dateText.match(/(\d{4})年(\d{2})月(\d{2})日/);
    var day = match ? match[3] : '';
    var ym = match ? match[1] + '-' + match[2] : dateText;
    var title = a.textContent.trim();
    var href = a.getAttribute('href') || '';

    var dateBox = document.createElement('div');
    dateBox.className = 'date-box';
    dateBox.innerHTML = '<p class="day">' + day + '</p><p class="ym">' + ym + '</p>';

    var titleSpan = document.createElement('span');
    titleSpan.className = 'notice-title';
    titleSpan.textContent = title;

    var newA = document.createElement('a');
    newA.href = href;
    newA.appendChild(dateBox);
    newA.appendChild(titleSpan);

    li.innerHTML = '';
    li.appendChild(newA);
  });

  // Handle links: external links → ask Flutter to open in browser.
  var host = location.hostname;
  document.querySelectorAll('a').forEach(function (a) {
    a.removeAttribute('target');
    a.addEventListener('click', function (e) {
      var href = a.getAttribute('href');
      if (!href || href === '#' || href.indexOf('javascript:') === 0) return;
      if (href.startsWith('/')) return;
      try {
        var url = new URL(href, location.href);
        if (url.hostname !== host) {
          e.preventDefault();
          e.stopPropagation();
          window.flutter_inappwebview.callHandler('OpenExternalLink', url.href);
        }
      } catch (err) { }
    }, true);
  });

  // Remove prev/next article links.
  var form = document.querySelector('.innerbox form');
  if (form) {
    form.querySelectorAll('p').forEach(function (p) {
      var text = p.textContent.trim();
      if (text.indexOf('上一条') === 0 || text.indexOf('下一条') === 0) {
        p.style.display = 'none';
      }
    });
  }

  // Clean up attachment list: remove "附件【" prefix, "】已下载X次" suffix, add .fjxz class.
  var vsb = document.querySelector('article[id^="vsb_content"]');
  if (vsb) {
    var sib = vsb.nextElementSibling;
    while (sib && sib.tagName !== 'UL') sib = sib.nextElementSibling;
    if (sib && sib.tagName === 'UL') {
      sib.className = 'fjxz';
      sib.removeAttribute('style');
      // Remove bottom border-radius from content when attachments follow
      vsb.style.borderRadius = '0';
      vsb.style.marginBottom = '0';
      sib.querySelectorAll('li').forEach(function (li) {
        var a = li.querySelector('a');
        if (!a) return;
        var newLi = document.createElement('li');
        newLi.appendChild(a.cloneNode(true));
        li.parentNode.replaceChild(newLi, li);
      });
    }
  }

  // Fix content images: reset parent span margin, center, add click to preview.
  document.querySelectorAll('article[id^="vsb_content"] img, .v_news_content img').forEach(function (img) {
    var parent = img.parentElement;
    if (parent && parent.tagName === 'SPAN') {
      parent.style.margin = '0';
      parent.style.display = 'block';
      parent.style.width = 'auto';
      parent.style.textAlign = 'center';
    }
    img.style.float = 'none';
    img.style.display = 'inline-block';
    img.style.margin = '0 auto';
    img.style.maxWidth = '100%';
    img.style.height = 'auto';
    img.style.cursor = 'pointer';
    img.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var src = img.getAttribute('src') || '';
      if (src && src.indexOf('/') === 0) src = window.location.origin + src;
      window.flutter_inappwebview.callHandler('OpenImage', src);
    });
  });

  // Extract download attachment links, style them, and send to Flutter.
  var items = [];
  var seen = {};

  function addAttachment(href, name) {
    if (!href || !name) return;
    href = href.replace(/&amp;/g, '&');
    if (href.startsWith('/')) href = window.location.origin + href;
    if (href.indexOf('download.jsp') !== -1 || href.indexOf('downloadAttach') !== -1 ||
        /\.(docx?|xlsx?|pptx?|pdf|zip|rar|7z|txt|csv|rtf)$/i.test(name) ||
        /\.(docx?|xlsx?|pptx?|pdf|zip|rar|7z|txt|csv|rtf)$/i.test(href)) {
      if (seen[href]) return;
      seen[href] = true;
      items.push({ url: href, name: btoa(unescape(encodeURIComponent(name))) });
    }
  }

  document.querySelectorAll('a[href*="download.jsp"], a[href*="downloadAttach"]').forEach(function (a) {
    var href = a.getAttribute('href');
    var name = a.textContent.trim();
    addAttachment(href, name);
  });

  var extReg = /\.(docx?|xlsx?|pptx?|pdf|zip|rar|7z|txt|csv|rtf)$/i;
  document.querySelectorAll('a').forEach(function (a) {
    var href = a.getAttribute('href');
    if (!href || seen[href]) return;
    var name = a.textContent.trim();
    if (extReg.test(name)) {
      addAttachment(href, name);
    }
  });

  if (items.length > 0) {
    window.flutter_inappwebview.callHandler('AttachmentsChannel', JSON.stringify(items));
  }

  // Intercept attachment link clicks → hand off to Flutter download.
  document.querySelectorAll('a[href*="download.jsp"], a[href*="downloadAttach"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var href = a.getAttribute('href');
      if (!href) return;
      href = href.replace(/&amp;/g, '&');
      if (href.startsWith('/')) href = window.location.origin + href;
      var name = a.textContent.trim();
      window.flutter_inappwebview.callHandler('DownloadAttachment', href, name);
    }, true);
  });
})();
