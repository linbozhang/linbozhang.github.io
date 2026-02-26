(function() {
  'use strict';

  var STORAGE_KEY = 'mdbook-sidebar-fold';

  function getStoredState() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (e) {
      return {};
    }
  }

  function setStoredState(state) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {}
  }

  function makeKey(link) {
    if (!link) return '';
    return (link.getAttribute('href') || '') + '|' + (link.textContent || '').trim();
  }

  function initSidebarFold() {
    var state = getStoredState();
    var root = document.querySelector('#mdbook-sidebar .chapter, .sidebar .chapter');
    if (!root) return;

    root.querySelectorAll('li.chapter-item').forEach(function(li) {
      var sub = li.querySelector(':scope > ol.section');
      if (!sub) return;

      var wrapper = li.querySelector(':scope > span.chapter-link-wrapper');
      var link = wrapper ? wrapper.querySelector('a') : null;
      var key = makeKey(link);

      // 有记录则按记录；无记录时保持当前 expanded 状态
      if (state.hasOwnProperty(key)) {
        if (state[key] === false) {
          li.classList.remove('expanded');
        } else {
          li.classList.add('expanded');
        }
      }

      // 使用 mdBook 自带的 chapter-fold-toggle 样式，与主题一致
      var toggle = document.createElement('a');
      toggle.setAttribute('href', '#');
      toggle.setAttribute('aria-label', li.classList.contains('expanded') ? '折叠' : '展开');
      toggle.className = 'chapter-fold-toggle';
      var toggleDiv = document.createElement('div');
      toggleDiv.textContent = '\u25B6'; // ▶，expanded 时 CSS 会旋转为 ▼
      toggle.appendChild(toggleDiv);

      toggle.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        li.classList.toggle('expanded');
        state[key] = li.classList.contains('expanded');
        setStoredState(state);
        toggle.setAttribute('aria-label', li.classList.contains('expanded') ? '折叠' : '展开');
      });

      if (wrapper) wrapper.appendChild(toggle);
    });
  }

  function runWhenReady() {
    var root = document.querySelector('.sidebar ol.chapter');
    if (root && root.querySelectorAll('li.chapter-item').length > 0) {
      initSidebarFold();
      return;
    }
    setTimeout(runWhenReady, 50);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', runWhenReady);
  } else {
    runWhenReady();
  }
})();
