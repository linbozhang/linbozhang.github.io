# 自定义侧边栏：折叠与滚动

本文说明本仓库 `theme/` 下自定义侧边栏（折叠 + 可滚动）的**需求背景**与**实现方式**，并给出完整代码，便于维护或迁移到其他 mdBook 项目。

---

## 1. 需求背景

### 1.1 问题

- **目录过长**：文档库按「编程语言 / 游戏引擎 / AI」等多级分类组织后，侧边栏 TOC 项很多，一屏展示不全，且层级较深时会出现 `2.1.1.1` 这类章节编号，观感不佳。
- **需要可折叠**：希望有子项的章节（如「Unity」「Shader」「代码生成」）能**折叠/展开**，减少干扰，并**记住用户选择**（刷新或换页后仍生效）。
- **需要可滚动**：侧边栏本身应**限制高度、内部滚动**，避免占满整屏。

### 1.2 目标

1. 侧边栏内**有子章节的项**支持点击折叠/展开，状态持久化到 `localStorage`。
2. 侧边栏容器**最大高度**约一屏，超出部分在侧边栏内滚动，并配上细滚动条样式。
3. 复用 mdBook 默认主题的 **`.expanded` / `.chapter-fold-toggle`** 样式，不破坏原有外观。
4. 通过 **`book.toml` 的 `additional-css` / `additional-js`** 注入，不修改 mdBook 内置主题文件，便于升级。

---

## 2. 实现方式

### 2.1 mdBook 侧边栏机制简述

- 侧栏由 **`toc.js`** 在运行时把目录注入到 **`#mdbook-sidebar`** 内的 **`mdbook-sidebar-scrollbox`** 中。
- 目录 DOM 结构为：**`ol.chapter`** 为根，每项为 **`li.chapter-item`**；有子级时，子级为 **`ol.section`**，且 **`li`** 上有 **`span.chapter-link-wrapper`**（内含链接与可选的折叠图标位）。
- 默认主题通过 **`li.expanded`** 控制是否显示子列表：**`.chapter li:not(.expanded) > ol { display: none; }`**；折叠图标使用 **`.chapter-fold-toggle`**，展开时其内 `div` 旋转 90° 显示为 ▼。
- 我们的方案：在页面加载后，**为每个带 `ol.section` 的 `li.chapter-item` 动态插入 `.chapter-fold-toggle`**，并绑定点击以切换 `expanded`，同时把状态写入 `localStorage`；CSS 只做**高度与滚动条**，不改变折叠逻辑。

### 2.2 文件与配置

| 文件 | 作用 |
|------|------|
| **theme/sidebar.js** | 在侧栏目录上挂折叠逻辑、读写 localStorage、插入折叠按钮。 |
| **theme/sidebar.css** | 侧栏最大高度、内部滚动、滚动条样式。 |
| **book.toml** | 通过 `additional-css`、`additional-js` 引入上述文件。 |

mdBook 构建时会把 `theme/` 下的文件拷到输出目录，并在生成的 HTML 中引用 `theme/sidebar.js` 与 `theme/sidebar.css`。

### 2.3 执行时机

- 目录是构建后由 `toc.js` 注入的，因此自定义脚本需在 **DOM 就绪后** 再查找 **`.sidebar ol.chapter`**。
- 当前做法：若已存在且其下已有 `li.chapter-item`，则直接执行 `initSidebarFold()`；否则 **每 50ms 重试** 一次，直到目录出现（兼容 toc 异步注入）。

---

## 3. 完整代码

### 3.1 theme/sidebar.js

```javascript
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
```

### 3.2 theme/sidebar.css

```css
/* 侧边栏：限制高度并可滚动，避免目录过长占满屏 */
.sidebar .sidebar-scrollbox,
.sidebar mdbook-sidebar-scrollbox {
  max-height: calc(100vh - 8rem);
  overflow-y: auto;
  overflow-x: hidden;
}

.sidebar .sidebar-scrollbox::-webkit-scrollbar,
.sidebar mdbook-sidebar-scrollbox::-webkit-scrollbar {
  width: 6px;
}

.sidebar .sidebar-scrollbox::-webkit-scrollbar-thumb,
.sidebar mdbook-sidebar-scrollbox::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.2);
  border-radius: 3px;
}

.sidebar .sidebar-scrollbox::-webkit-scrollbar-thumb:hover,
.sidebar mdbook-sidebar-scrollbox::-webkit-scrollbar-thumb:hover {
  background: rgba(0, 0, 0, 0.3);
}
```

### 3.3 book.toml 中相关配置

在 `[output.html]` 中增加两行即可：

```toml
[output.html]
default-theme = "light"
no-section-label = true
git-repository-url = "https://github.com/linbozhang/linbozhang.github.io"
additional-css = ["theme/sidebar.css"]
additional-js = ["theme/sidebar.js"]
```

---

## 4. 行为说明

- **折叠键**：以每项的 `href + 标题文本` 拼接为 key，存入 `localStorage` 的 `mdbook-sidebar-fold` 对象；无记录时保持 toc 默认的 `expanded` 状态。
- **折叠图标**：使用 mdBook 自带的 **`.chapter-fold-toggle`**，图标为 Unicode `\u25B6`（▶）；主题 CSS 会在 `li.expanded` 时旋转为 ▼，无需在本项目中再写旋转逻辑。
- **高度**：`max-height: calc(100vh - 8rem)` 为侧栏留出顶部/底部空间；可根据实际布局微调 `8rem`。
- **滚动条**：仅针对 WebKit 做了窄条与圆角，其他浏览器使用默认滚动条。

---

## 5. 使用与扩展

- **关闭章节编号**：若不想显示 `2.1.1.1` 这类编号，在 `book.toml` 的 `[output.html]` 中设置 **`no-section-label = true`**（本仓库已开启）。
- **迁移**：将 `theme/sidebar.js`、`theme/sidebar.css` 拷到新项目 `theme/` 下，并在其 `book.toml` 中加上 `additional-css`、`additional-js` 即可。
- **扩展**：可在 `initSidebarFold()` 中根据当前页 URL 自动展开对应路径的父级（需解析 `ol.chapter` 与链接），或增加「全部展开/全部折叠」按钮，仍复用同一 `localStorage` key。
