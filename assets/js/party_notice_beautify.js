(function () {
  var css = document.createElement('style');
  css.textContent = `
    /* ── Hide site chrome ── */
    .header, .nav, .M_header, .picture,
    .left-menu, .location-bar,
    .footer, .footpc, .redLine,
    .footer-box, .footer-logo, .footer-detail, .code-box,
    .link, .logo, .menu-box, .searchBtn, .search_Box,
    .menu-btn, .bread, .logo_M, .M_headerBox { display: none !important; }

    body { margin: 0 !important; padding: 0 !important; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif !important; background: #f2f2f2 !important; }

    .listContent { max-width: 640px !important; margin: 0 auto !important; padding: 0 !important; width: auto !important; }
    .main-box { padding: 0 !important; width: 100% !important; max-width: none !important; }

    /* ── List page: li.news-list ── */
    .main-box > ul {
      list-style: none !important;
      margin: 8px 16px !important;
      padding: 0 !important;
      background: #fff !important;
      border-radius: 12px !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
      overflow: hidden !important;
    }
    li.news-list { padding: 0 !important; height: auto !important; }
    li.news-list + li.news-list { border-top: 1px solid #eee !important; }
    li.news-list a {
      display: flex !important;
      align-items: flex-start !important;
      padding: 14px 16px !important;
      text-decoration: none !important;
      color: #222 !important;
      height: auto !important;
      font-weight: normal !important;
      white-space: normal !important;
    }
    li.news-list .date-box {
      flex-shrink: 0 !important;
      text-align: center !important;
      padding: 6px 10px !important;
      margin-right: 14px !important;
      background: #f5f5f5 !important;
      border-radius: 8px !important;
      line-height: 1.3 !important;
    }
    li.news-list .date-box .date {
      display: block !important;
      margin: 0 !important;
      font-size: 16px !important;
      font-weight: bold !important;
      color: #d32f2f !important;
    }
    li.news-list .date-box .year-month {
      display: block !important;
      margin: 0 !important;
      font-size: 12px !important;
      color: #999 !important;
    }
    li.news-list .news-box {
      flex: 1 !important;
      min-width: 0 !important;
    }
    li.news-list .news-box .title {
      margin: 0 !important;
      font-size: 16px !important;
      line-height: 1.6 !important;
      font-weight: 500 !important;
      color: #333 !important;
      overflow: visible !important;
      height: auto !important;
      max-height: none !important;
      white-space: normal !important;
      word-break: break-all !important;
      overflow-wrap: break-word !important;
    }
    li.news-list .news-box .content {
      display: none !important;
    }

    /* ── Pagination ── */
    .page { margin: 16px !important; text-align: center !important; }
    .pb_sys_common {
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
    .detail {
      max-width: 640px !important;
      margin: 0 auto !important;
      padding: 0 !important;
    }
    .detail-title {
      font-size: 20px !important;
      font-weight: bold !important;
      line-height: 1.4 !important;
      margin: 8px 16px 0 !important;
      padding: 16px 16px 12px !important;
      background: #fff !important;
      border-radius: 12px 12px 0 0 !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
      color: #333 !important;
    }
    .detail-about {
      margin: 0 16px !important;
      padding: 0 16px 12px !important;
      font-size: 13px !important;
      color: #999 !important;
      background: #fff !important;
      border-bottom: 1px solid #eee !important;
    }
    .detail-line { display: none !important; }
    .detail-content {
      margin: 0 16px 8px !important;
      padding: 16px !important;
      background: #fff !important;
      border-radius: 0 0 12px 12px !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1) !important;
    }
    .v_news_content {
      font-size: 16px !important;
      line-height: 1.8 !important;
      color: #333 !important;
    }
    .v_news_content p {
      margin: 0 0 12px !important;
    }
    .detail .page { display: none !important; }
    .turn-page { display: none !important; }

    /* ── Attachment links ── */
    #div_vote_id { display: none !important; }
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
    img { max-width: 100% !important; height: auto !important; float: none !important; display: block !important; margin: 0 auto !important; }
    table { width: 100% !important; max-width: 100% !important; border-collapse: collapse !important; }
    td, th { border: 1px solid #ddd !important; padding: 8px !important; font-size: 14px !important; }

    /* ── Attachment links (download.jsp) ── */
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
      p, span, strong, em, u, s { color: #e0e0e0 !important; background: transparent !important; }
      .main-box > ul { background: #1e1e1e !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
      li.news-list + li.news-list { border-top-color: #333 !important; }
      li.news-list a { color: #e0e0e0 !important; }
      li.news-list .date-box { background: #2a2a2a !important; }
      li.news-list .date-box .date { color: #ef5350 !important; }
      li.news-list .date-box .year-month { color: #999 !important; }
      li.news-list .news-box .title { color: #e0e0e0 !important; }
      .detail-title { background: #1e1e1e !important; color: #e0e0e0 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
      .detail-about { background: #1e1e1e !important; border-bottom-color: #333 !important; }
      .detail-content { background: #1e1e1e !important; box-shadow: 0 1px 3px rgba(0,0,0,0.3) !important; }
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

  // ── Search bar (list page) ──
  var noticeList = document.querySelector('.main-box > ul');
  if (noticeList) {
    var searchWrap = document.createElement('div');
    searchWrap.style.cssText = 'max-width:640px;margin:12px auto;padding:0 16px;display:flex;gap:8px;';
    var input = document.createElement('input');
    input.type = 'text';
    input.placeholder = '搜索通知...';
    input.style.cssText = 'flex:1;box-sizing:border-box;padding:10px 14px;border:1px solid #e0e0e0;border-radius:10px;font-size:15px;outline:none;background:#fff;color:#333;';
    var btn = document.createElement('button');
    btn.textContent = '搜索';
    btn.style.cssText = 'padding:10px 20px;border:none;border-radius:10px;background:#d32f2f;color:#fff;font-size:15px;cursor:pointer;white-space:nowrap;';
    searchWrap.appendChild(input);
    searchWrap.appendChild(btn);
    noticeList.parentNode.insertBefore(searchWrap, noticeList);

    function doSearch() {
      var keyword = input.value.trim();
      if (!keyword) return;
      var encodedKey = btoa(unescape(encodeURIComponent(keyword)));
      var form = document.querySelector('form[name="au2a"]');
      if (form) {
        var showKeyInput = form.querySelector('input[name="showkeycode"]');
        var luceneInput = form.querySelector('input[name="lucenenewssearchkey"]');
        if (showKeyInput) showKeyInput.value = keyword;
        if (luceneInput) luceneInput.value = encodedKey;
        form.submit();
      } else {
        var f = document.createElement('form');
        f.method = 'POST';
        f.action = '/search_list.jsp?wbtreeid=1003';
        var params = {
          lucenenewssearchkey: encodedKey,
          _lucenesearchtype: '1',
          searchScope: '0',
          showkeycode: keyword,
        };
        for (var k in params) {
          var h = document.createElement('input');
          h.type = 'hidden'; h.name = k; h.value = params[k];
          f.appendChild(h);
        }
        document.body.appendChild(f);
        f.submit();
      }
    }

    btn.addEventListener('click', doSearch);
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') doSearch();
    });

    if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
      input.style.background = '#1e1e1e';
      input.style.borderColor = '#444';
      input.style.color = '#e0e0e0';
    }
  }

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

  // Rewrite search results to match news-list structure.
  // Search results page may use a .list or different structure.
  var listDiv = document.querySelector('.list');
  if (listDiv) {
    var sUl = listDiv.querySelector('ul');
    if (sUl) {
      var sLis = sUl.querySelectorAll('li');
      sLis.forEach(function (li) {
        var a = li.querySelector('a');
        var span = li.querySelector('span:not([class])');
        if (!a) return;
        var title = a.textContent.trim();
        var href = a.getAttribute('href') || '';
        var date = span ? span.textContent.trim() : '';
        var dateParts = date.split('-');
        var mmdd = dateParts.length === 3 ? dateParts[1] + '/' + dateParts[2] : date;
        var year = dateParts.length === 3 ? dateParts[0] : '';
        li.className = 'news-list';
        li.innerHTML = '<a href="' + href + '" class="clearfix" style="display:flex;align-items:flex-start;padding:14px 16px;text-decoration:none;color:#222;">' +
          '<div class="date-box" style="flex-shrink:0;text-align:center;padding:6px 10px;margin-right:14px;background:#f5f5f5;border-radius:8px;line-height:1.3;">' +
          '<p class="date" style="display:block;margin:0;font-size:16px;font-weight:bold;color:#d32f2f;">' + mmdd + '</p>' +
          '<p class="year-month" style="display:block;margin:0;font-size:12px;color:#999;">' + year + '</p>' +
          '</div>' +
          '<div class="news-box" style="flex:1;min-width:0;">' +
          '<p class="title" style="margin:0;font-size:16px;line-height:1.6;font-weight:500;color:#333;">' + title + '</p>' +
          '</div>' +
          '</a>';
      });
    }
  }

  // Clean up attachment list: remove "附件【" prefix, "】已下载X次" suffix, add .fjxz class.
  var vsb = document.querySelector('.detail-content');
  if (vsb) {
    var sib = vsb.nextElementSibling;
    while (sib && sib.tagName !== 'UL') sib = sib.nextElementSibling;
    if (sib && sib.tagName === 'UL') {
      sib.className = 'fjxz';
      sib.removeAttribute('style');
      // Remove bottom border-radius from detail-content when attachments follow
      vsb.style.borderRadius = '0 0 0 0';
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
  document.querySelectorAll('#vsb_content img, .v_news_content img').forEach(function (img) {
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

  // download.jsp links
  document.querySelectorAll('a[href*="download.jsp"], a[href*="downloadAttach"]').forEach(function (a) {
    var href = a.getAttribute('href');
    var name = a.textContent.trim();
    addAttachment(href, name);
  });

  // Links with file-extension text
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
