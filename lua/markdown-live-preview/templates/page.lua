--- HTML preview page generator for markdown-live-preview.
--- Returns a complete HTML page with GitHub-flavored styling,
--- WebSocket client, marked.js rendering, highlight.js, mermaid, and scroll sync.

local M = {}

--- Generate the full HTML preview page.
---@param config table plugin config
---@return string html
function M.generate(config)
  local theme_class = ''
  if config.theme == 'light' then
    theme_class = 'light'
  elseif config.theme == 'dark' then
    theme_class = 'dark'
  end

  local scroll_sync_js = config.scroll_sync ~= false and 'true' or 'false'

  local parts = {}
  local function add(s)
    parts[#parts + 1] = s
  end

  -- DOCTYPE + head
  add([[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Markdown Preview</title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📝</text></svg>">
<link rel="stylesheet" href="/assets/github.min.css" id="hljs-theme-light">
<link rel="stylesheet" href="/assets/github-dark.min.css" id="hljs-theme-dark" disabled>
<style>]])

  -- CSS
  add([[
:root {
  --color-fg: #1f2328;
  --color-fg-muted: #656d76;
  --color-fg-subtle: #6e7781;
  --color-bg: #ffffff;
  --color-bg-secondary: #f6f8fa;
  --color-border: #d0d7de;
  --color-border-muted: #d8dee4;
  --color-link: #0969da;
  --color-blockquote-border: #d0d7de;
  --color-code-bg: #eff1f3;
  --color-pre-bg: #f6f8fa;
  --color-table-border: #d0d7de;
  --color-table-row: #f6f8fa;
  --color-btn-bg: #24292f;
  --color-btn-fg: #ffffff;
  --color-note: #0969da;
  --color-tip: #1a7f37;
  --color-important: #8250df;
  --color-warning: #9a6700;
  --color-caution: #cf222e;
}
@media (prefers-color-scheme: dark) {
  :root:not(.light) {
    --color-fg: #e6edf3;
    --color-fg-muted: #8b949e;
    --color-fg-subtle: #6e7681;
    --color-bg: #0d1117;
    --color-bg-secondary: #161b22;
    --color-border: #30363d;
    --color-border-muted: #21262d;
    --color-link: #58a6ff;
    --color-blockquote-border: #3b434b;
    --color-code-bg: #282e37;
    --color-pre-bg: #161b22;
    --color-table-border: #30363d;
    --color-table-row: #161b22;
    --color-btn-bg: #f0f6fc;
    --color-btn-fg: #0d1117;
    --color-note: #58a6ff;
    --color-tip: #3fb950;
    --color-important: #a371f7;
    --color-warning: #d29922;
    --color-caution: #f85149;
  }
}
.dark {
  --color-fg: #e6edf3;
  --color-fg-muted: #8b949e;
  --color-fg-subtle: #6e7681;
  --color-bg: #0d1117;
  --color-bg-secondary: #161b22;
  --color-border: #30363d;
  --color-border-muted: #21262d;
  --color-link: #58a6ff;
  --color-blockquote-border: #3b434b;
  --color-code-bg: #282e37;
  --color-pre-bg: #161b22;
  --color-table-border: #30363d;
  --color-table-row: #161b22;
  --color-btn-bg: #f0f6fc;
  --color-btn-fg: #0d1117;
  --color-note: #58a6ff;
  --color-tip: #3fb950;
  --color-important: #a371f7;
  --color-warning: #d29922;
  --color-caution: #f85149;
}
.light {
  --color-fg: #1f2328;
  --color-fg-muted: #656d76;
  --color-fg-subtle: #6e7781;
  --color-bg: #ffffff;
  --color-bg-secondary: #f6f8fa;
  --color-border: #d0d7de;
  --color-border-muted: #d8dee4;
  --color-link: #0969da;
  --color-blockquote-border: #d0d7de;
  --color-code-bg: #eff1f3;
  --color-pre-bg: #f6f8fa;
  --color-table-border: #d0d7de;
  --color-table-row: #f6f8fa;
  --color-btn-bg: #24292f;
  --color-btn-fg: #ffffff;
  --color-note: #0969da;
  --color-tip: #1a7f37;
  --color-important: #8250df;
  --color-warning: #9a6700;
  --color-caution: #cf222e;
}

*, *::before, *::after { box-sizing: border-box; }
html { font-size: 16px; -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji';
  font-size: 16px;
  line-height: 1.5;
  color: var(--color-fg);
  background-color: var(--color-bg);
  margin: 0;
  padding: 32px 16px;
  word-wrap: break-word;
  scroll-behavior: smooth;
}

#theme-toggle {
  position: fixed;
  top: 16px;
  right: 16px;
  z-index: 1000;
  background: var(--color-btn-bg);
  color: var(--color-btn-fg);
  border: none;
  border-radius: 50%;
  width: 36px;
  height: 36px;
  font-size: 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24);
  transition: opacity 0.2s;
  opacity: 0.6;
  line-height: 1;
  padding: 0;
}
#theme-toggle:hover { opacity: 1; }

#status {
  position: fixed;
  bottom: 16px;
  right: 16px;
  z-index: 1000;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #da3633;
  transition: background 0.3s;
}
#status.connected { background: #3fb950; }

.markdown-body {
  max-width: 900px;
  margin: 0 auto;
}

/* Headings */
.markdown-body h1, .markdown-body h2, .markdown-body h3,
.markdown-body h4, .markdown-body h5, .markdown-body h6 {
  margin-top: 24px;
  margin-bottom: 16px;
  font-weight: 600;
  line-height: 1.25;
}
.markdown-body h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid var(--color-border); }
.markdown-body h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid var(--color-border); }
.markdown-body h3 { font-size: 1.25em; }
.markdown-body h4 { font-size: 1em; }
.markdown-body h5 { font-size: 0.875em; }
.markdown-body h6 { font-size: 0.85em; color: var(--color-fg-muted); }

/* Paragraphs + text */
.markdown-body p { margin-top: 0; margin-bottom: 16px; }
.markdown-body a { color: var(--color-link); text-decoration: none; }
.markdown-body a:hover { text-decoration: underline; }
.markdown-body strong { font-weight: 600; }
.markdown-body em { font-style: italic; }
.markdown-body del { text-decoration: line-through; }
.markdown-body mark { background: #fff8c5; padding: 0.1em 0.2em; border-radius: 3px; }

/* Code */
.markdown-body code {
  font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace;
  font-size: 85%;
  padding: 0.2em 0.4em;
  margin: 0;
  background-color: var(--color-code-bg);
  border-radius: 6px;
  white-space: break-spaces;
}
.markdown-body pre {
  padding: 16px;
  overflow: auto;
  font-size: 85%;
  line-height: 1.45;
  background-color: var(--color-pre-bg);
  border-radius: 6px;
  margin-bottom: 16px;
  position: relative;
}
.markdown-body pre code {
  padding: 0;
  margin: 0;
  background: transparent;
  border: 0;
  font-size: 100%;
  white-space: pre;
  word-break: normal;
  overflow-wrap: normal;
}

/* Lists */
.markdown-body ul, .markdown-body ol { padding-left: 2em; margin-top: 0; margin-bottom: 16px; }
.markdown-body li { margin-top: 0.25em; }
.markdown-body li + li { margin-top: 0.25em; }
.markdown-body li > p { margin-top: 16px; }
.markdown-body li > ul, .markdown-body li > ol { margin-top: 0; margin-bottom: 0; }
.markdown-body ul ul, .markdown-body ul ol, .markdown-body ol ol, .markdown-body ol ul { margin-top: 0; margin-bottom: 0; }

/* Task lists */
.markdown-body .task-list-item { list-style-type: none; }
.markdown-body .task-list-item input[type="checkbox"] { margin: 0 0.35em 0.25em -1.6em; vertical-align: middle; }

/* Blockquotes */
.markdown-body blockquote {
  margin: 0 0 16px 0;
  padding: 0 1em;
  color: var(--color-fg-muted);
  border-left: 0.25em solid var(--color-blockquote-border);
}

/* Tables */
.markdown-body table {
  border-spacing: 0;
  border-collapse: collapse;
  margin-top: 0;
  margin-bottom: 16px;
  display: block;
  width: max-content;
  max-width: 100%;
  overflow: auto;
}
.markdown-body table th, .markdown-body table td {
  padding: 6px 13px;
  border: 1px solid var(--color-table-border);
}
.markdown-body table th { font-weight: 600; background: var(--color-bg-secondary); }
.markdown-body table tr { background-color: var(--color-bg); border-top: 1px solid var(--color-border-muted); }
.markdown-body table tr:nth-child(2n) { background-color: var(--color-table-row); }

/* Horizontal rules */
.markdown-body hr {
  height: 0.25em;
  padding: 0;
  margin: 24px 0;
  background-color: var(--color-border);
  border: 0;
}

/* Images */
.markdown-body img { max-width: 100%; height: auto; border-radius: 6px; }

/* Mermaid */
.markdown-body .mermaid-diagram { margin: 16px 0; text-align: center; overflow-x: auto; }
.markdown-body .mermaid-diagram svg { max-width: 100%; height: auto; }
.markdown-body .mermaid-error { color: var(--color-caution); font-size: 0.85em; padding: 8px; border: 1px solid var(--color-caution); border-radius: 6px; }

/* GitHub-style alerts */
.markdown-body .markdown-alert { padding: 8px 16px; margin-bottom: 16px; border-left: 0.25em solid; border-radius: 6px; }
.markdown-body .markdown-alert-note { border-color: var(--color-note); }
.markdown-body .markdown-alert-tip { border-color: var(--color-tip); }
.markdown-body .markdown-alert-important { border-color: var(--color-important); }
.markdown-body .markdown-alert-warning { border-color: var(--color-warning); }
.markdown-body .markdown-alert-caution { border-color: var(--color-caution); }
.markdown-body .markdown-alert .markdown-alert-title { font-weight: 600; margin-bottom: 4px; }

/* Misc */
.markdown-body > *:first-child { margin-top: 0 !important; }
.markdown-body > *:last-child { margin-bottom: 0 !important; }
.markdown-body dd { margin-left: 0; padding: 0 16px; }
.markdown-body details { margin-bottom: 16px; }
.markdown-body summary { cursor: pointer; font-weight: 600; }
.markdown-body kbd {
  display: inline-block;
  padding: 3px 5px;
  font: 11px ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace;
  line-height: 10px;
  color: var(--color-fg);
  vertical-align: middle;
  background-color: var(--color-bg-secondary);
  border: solid 1px var(--color-border-muted);
  border-bottom-color: var(--color-border);
  border-radius: 6px;
  box-shadow: inset 0 -1px 0 var(--color-border);
}

/* Scrollbar (Webkit) */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--color-border); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: var(--color-fg-muted); }
]])

  add('</style>')
  add('</head>')

  -- Body
  add('<body class="' .. theme_class .. '">')
  add('<button id="theme-toggle" title="Toggle theme">🌙</button>')
  add('<div id="status"></div>')
  add('<div id="content" class="markdown-body"><p style="color:var(--color-fg-muted)">Connecting…</p></div>')

  -- Scripts
  add('<script src="/assets/marked.min.js"></script>')
  add('<script src="/assets/highlight.min.js"></script>')
  add('<script src="/assets/mermaid.min.js"></script>')

  add('<script>')
  add([[(function() {
  "use strict";

  // ── CDN fallback loader ──
  var cdnFallbacks = [
    { global: "marked",  cdn: "https://cdn.jsdelivr.net/npm/marked/marked.min.js" },
    { global: "hljs",    cdn: "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js" },
    { global: "mermaid", cdn: "https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js" }
  ];

  function loadFallbacks(idx) {
    if (idx >= cdnFallbacks.length) { init(); return; }
    var dep = cdnFallbacks[idx];
    if (window[dep.global]) { loadFallbacks(idx + 1); return; }
    var s = document.createElement("script");
    s.src = dep.cdn;
    s.onload = function() { loadFallbacks(idx + 1); };
    s.onerror = function() { loadFallbacks(idx + 1); };
    document.head.appendChild(s);
  }

  // Check if any deps are missing
  var missing = cdnFallbacks.some(function(d) { return !window[d.global]; });
  if (missing) { loadFallbacks(0); } else { init(); }

  function init() {
    var contentEl   = document.getElementById("content");
    var statusEl    = document.getElementById("status");
    var toggleBtn   = document.getElementById("theme-toggle");
    var scrollSync  = ]] .. scroll_sync_js .. [[;

    // ── Theme ──
    var hljsLight = document.getElementById("hljs-theme-light");
    var hljsDark  = document.getElementById("hljs-theme-dark");

    function isDarkMode() {
      if (document.body.classList.contains("dark")) return true;
      if (document.body.classList.contains("light")) return false;
      return window.matchMedia("(prefers-color-scheme: dark)").matches;
    }

    function applyTheme() {
      var dark = isDarkMode();
      if (hljsLight) hljsLight.disabled = dark;
      if (hljsDark)  hljsDark.disabled = !dark;
      toggleBtn.textContent = dark ? "☀️" : "🌙";
      if (typeof mermaid !== "undefined") {
        try { mermaid.initialize({ startOnLoad: false, theme: dark ? "dark" : "default" }); } catch(e) {}
      }
    }

    var stored = localStorage.getItem("mdp-theme");
    if (stored === "dark") { document.body.className = "dark"; }
    else if (stored === "light") { document.body.className = "light"; }
    applyTheme();

    toggleBtn.addEventListener("click", function() {
      var dark = isDarkMode();
      document.body.className = dark ? "light" : "dark";
      localStorage.setItem("mdp-theme", dark ? "light" : "dark");
      applyTheme();
      // Re-render mermaid with new theme
      if (lastContent) renderMarkdown(lastContent);
    });

    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function() {
      if (!document.body.classList.contains("dark") && !document.body.classList.contains("light")) {
        applyTheme();
        if (lastContent) renderMarkdown(lastContent);
      }
    });

    // ── Mermaid init ──
    if (typeof mermaid !== "undefined") {
      mermaid.initialize({ startOnLoad: false, theme: isDarkMode() ? "dark" : "default" });
    }

    // ── Marked config ──
    if (typeof marked !== "undefined") {
      marked.setOptions({
        gfm: true,
        breaks: false,
        pedantic: false,
        headerIds: true,
        mangle: false
      });
    }

    // ── Rendering ──
    var lastContent = "";
    var mermaidCounter = 0;

    function renderMarkdown(content) {
      if (typeof marked === "undefined") {
        contentEl.innerHTML = "<pre>" + escapeHtml(content) + "</pre>";
        return;
      }

      var scrollTop = window.scrollY;

      contentEl.innerHTML = marked.parse(content);

      // Syntax highlighting
      if (typeof hljs !== "undefined") {
        contentEl.querySelectorAll("pre code").forEach(function(block) {
          if (!block.classList.contains("language-mermaid")) {
            hljs.highlightElement(block);
          }
        });
      }

      // Mermaid diagrams
      renderMermaid();

      // Restore scroll
      window.scrollTo(0, scrollTop);
    }

    function renderMermaid() {
      if (typeof mermaid === "undefined") return;
      var codes = contentEl.querySelectorAll("pre code.language-mermaid");
      codes.forEach(function(code) {
        var pre = code.parentElement;
        var container = document.createElement("div");
        container.className = "mermaid-diagram";
        var id = "mermaid-svg-" + (++mermaidCounter);
        try {
          mermaid.render(id, code.textContent).then(function(result) {
            container.innerHTML = result.svg;
            if (pre.parentElement) pre.parentElement.replaceChild(container, pre);
          }).catch(function(err) {
            container.className = "mermaid-error";
            container.textContent = "Mermaid error: " + err.message;
            if (pre.parentElement) pre.parentElement.replaceChild(container, pre);
          });
        } catch (e) {
          container.className = "mermaid-error";
          container.textContent = "Mermaid error: " + e.message;
          if (pre.parentElement) pre.parentElement.replaceChild(container, pre);
        }
      });
    }

    function escapeHtml(str) {
      return str.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
    }

    // ── Scroll sync ──
    var programmaticScroll = false;
    var scrollTimer = null;

    if (scrollSync) {
      window.addEventListener("scroll", function() {
        if (programmaticScroll) return;
        if (!ws || ws.readyState !== WebSocket.OPEN) return;
        if (scrollTimer) clearTimeout(scrollTimer);
        scrollTimer = setTimeout(function() {
          var maxScroll = document.documentElement.scrollHeight - window.innerHeight;
          var position = maxScroll > 0 ? window.scrollY / maxScroll : 0;
          ws.send(JSON.stringify({ type: "scroll", position: position }));
        }, 50);
      });
    }

    function syncScrollFromServer(position) {
      if (!scrollSync) return;
      programmaticScroll = true;
      var maxScroll = document.documentElement.scrollHeight - window.innerHeight;
      var target = Math.round(position * maxScroll);
      window.scrollTo({ top: target, behavior: "smooth" });
      setTimeout(function() { programmaticScroll = false; }, 300);
    }

    // ── WebSocket ──
    var ws = null;
    var reconnectDelay = 1000;
    var maxReconnectDelay = 30000;

    function connect() {
      var proto = location.protocol === "https:" ? "wss:" : "ws:";
      ws = new WebSocket(proto + "//" + location.host);

      ws.onopen = function() {
        reconnectDelay = 1000;
        statusEl.className = "connected";
      };

      ws.onmessage = function(event) {
        try {
          var msg = JSON.parse(event.data);
          if (msg.type === "content") {
            lastContent = msg.data;
            renderMarkdown(msg.data);
          } else if (msg.type === "scroll") {
            syncScrollFromServer(msg.position);
          } else if (msg.type === "close") {
            ws.close();
            try { window.close(); } catch(e) {}
            document.title = "[Closed] Markdown Preview";
            contentEl.innerHTML = "<p style='color:var(--color-fg-muted);text-align:center;margin-top:4em'>Preview closed by Neovim. You can close this tab.</p>";
          }
        } catch(e) {}
      };

      ws.onclose = function() {
        statusEl.className = "";
        setTimeout(function() {
          reconnectDelay = Math.min(reconnectDelay * 2, maxReconnectDelay);
          connect();
        }, reconnectDelay);
      };

      ws.onerror = function() {
        ws.close();
      };
    }

    connect();
  }
})();]])

  add('</script>')
  add('</body>')
  add('</html>')

  return table.concat(parts, '\n')
end

return M
