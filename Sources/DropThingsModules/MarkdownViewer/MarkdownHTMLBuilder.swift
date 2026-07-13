import Foundation
import AppKit
import WebKit
import DropThingsCore

/// Builds the static HTML shell loaded into the preview's `WKWebView` and
/// the JSON-encoded payload used to push new Markdown from Swift into JS.
///
/// The shell loads `marked.min.js` and `highlight.min.js` (vendored under
/// `MarkdownViewer/Resources/`) relative to the bundle URL passed as
/// `baseURL` to `WKWebView.loadHTMLString(_:baseURL:)`. A small bridge
/// exposes `window.dropthings.render(md)` and `window.dropthings.setTheme(name)`.
enum MarkdownHTMLBuilder {

    /// Locate the directory that contains the vendored JS so it can be used
    /// as the WKWebView's `baseURL`. Returns nil only if the bundle is
    /// malformed — the preview will fall back to an inline error view.
    static func resourcesBaseURL() -> URL? {
        if let url = Bundle.module.url(forResource: "marked.min", withExtension: "js") {
            return url.deletingLastPathComponent()
        }
        if let url = Bundle.module.url(forResource: "marked.min", withExtension: "js", subdirectory: "MarkdownViewer/Resources") {
            return url.deletingLastPathComponent()
        }
        if let url = Bundle.module.url(forResource: "marked.min", withExtension: "js", subdirectory: "Resources") {
            return url.deletingLastPathComponent()
        }
        return nil
    }

    /// The HTML document loaded once per preview instance. Markdown content
    /// is pushed later via `evaluateJavaScript` so the webview does not
    /// reload on every keystroke.
    static func shellHTML(theme: MarkdownTheme, fontSize: Int) -> String {
        let themeName = theme == .dark ? "dark" : "light"
        return """
        <!DOCTYPE html>
        <html lang="en" data-theme="\(themeName)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(baseCSS(fontSize: fontSize))
        \(highlightCSS())
        </style>
        <script src="marked.min.js"></script>
        <script src="highlight.min.js"></script>
        </head>
        <body>
        <div id="root"><div class="dt-empty">No content</div></div>
        <script>
        \(bridgeJS())
        </script>
        </body>
        </html>
        """
    }

    /// JSON-encode a Markdown string for safe embedding in a JS call.
    /// Falls back to an empty-document payload if encoding fails.
    static func renderCall(for markdown: String) -> String {
        guard let data = try? JSONEncoder().encode(markdown),
              let json = String(data: data, encoding: .utf8) else {
            return "window.dropthings && window.dropthings.render('');"
        }
        return "window.dropthings && window.dropthings.render(\(json));"
    }

    static func setThemeCall(_ theme: MarkdownTheme) -> String {
        let name = theme == .dark ? "dark" : "light"
        return "window.dropthings && window.dropthings.setTheme('\(name)');"
    }

    // MARK: - Bridge JS

    private static func bridgeJS() -> String {
        return """
        (function () {
          if (typeof marked === 'undefined') {
            document.getElementById('root').innerHTML =
              '<div class="dt-error">Markdown engine failed to load.</div>';
            return;
          }
          marked.setOptions({
            gfm: true,
            breaks: false,
            headerIds: false,
            mangle: false,
            highlight: function (code, lang) {
              if (typeof hljs === 'undefined') return code;
              try {
                if (lang && hljs.getLanguage(lang)) {
                  return hljs.highlight(code, { language: lang }).value;
                }
                return hljs.highlightAuto(code).value;
              } catch (e) {
                return code;
              }
            }
          });
          var root = document.getElementById('root');
          function render(md) {
            if (!md) {
              root.innerHTML = '<div class="dt-empty">Nothing to preview yet</div>';
              return;
            }
            try {
              root.innerHTML = marked.parse(md);
              // Anchor links open in the default browser, not the webview.
              root.querySelectorAll('a[href^="http"]').forEach(function (a) {
                a.target = '_blank';
                a.rel = 'noopener';
              });
            } catch (e) {
              root.innerHTML = '<div class="dt-error">Render error: ' + e.message + '</div>';
            }
          }
          function setTheme(name) {
            document.documentElement.setAttribute('data-theme', name);
          }
          window.dropthings = { render: render, setTheme: setTheme };
        })();
        """
    }

    // MARK: - CSS

    /// GitHub-flavored base CSS. Compact, theme-aware via `data-theme`.
    /// Fonts and spacing follow system defaults so the preview feels native.
    private static func baseCSS(fontSize: Int) -> String {
        let size = max(12, min(24, fontSize))
        return """
        :root {
          --fg: #1f2328;
          --fg-muted: #656d76;
          --bg: #ffffff;
          --border: #d0d7de;
          --code-bg: #f6f8fa;
          --quote-bar: #d0d7de;
          --link: #0969da;
        }
        [data-theme="dark"] {
          --fg: #e6edf3;
          --fg-muted: #9198a1;
          --bg: #0d1117;
          --border: #30363d;
          --code-bg: #161b22;
          --quote-bar: #30363d;
          --link: #58a6ff;
        }
        html, body {
          margin: 0;
          padding: 16px 20px;
          background: var(--bg);
          color: var(--fg);
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", system-ui, sans-serif;
          font-size: \(size)px;
          line-height: 1.55;
          -webkit-font-smoothing: antialiased;
        }
        #root { max-width: 820px; margin: 0 auto; }
        h1, h2, h3, h4, h5, h6 { margin: 1.4em 0 0.5em; line-height: 1.25; font-weight: 600; }
        h1 { font-size: 1.9em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1.05em; }
        h5, h6 { font-size: 0.95em; color: var(--fg-muted); }
        p { margin: 0.6em 0; }
        a { color: var(--link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        ul, ol { margin: 0.5em 0; padding-left: 1.6em; }
        li { margin: 0.2em 0; }
        li > input[type="checkbox"] { margin-right: 0.4em; }
        code {
          font-family: "SF Mono", Menlo, Monaco, monospace;
          font-size: 0.88em;
          background: var(--code-bg);
          padding: 0.15em 0.35em;
          border-radius: 4px;
        }
        pre {
          background: var(--code-bg);
          padding: 12px 14px;
          border-radius: 8px;
          overflow-x: auto;
          border: 1px solid var(--border);
        }
        pre code {
          background: transparent;
          padding: 0;
          font-size: 0.85em;
          line-height: 1.5;
        }
        blockquote {
          margin: 0.6em 0;
          padding: 0.2em 1em;
          color: var(--fg-muted);
          border-left: 4px solid var(--quote-bar);
        }
        table {
          border-collapse: collapse;
          margin: 0.8em 0;
          display: block;
          overflow-x: auto;
        }
        th, td {
          border: 1px solid var(--border);
          padding: 6px 12px;
        }
        th { background: var(--code-bg); font-weight: 600; }
        tr:nth-child(2n) td { background: var(--code-bg); }
        img { max-width: 100%; border-radius: 8px; }
        hr { border: none; border-top: 1px solid var(--border); margin: 1.4em 0; }
        .dt-empty, .dt-error {
          color: var(--fg-muted);
          padding: 2em 0;
          text-align: center;
        }
        .dt-error { color: #cf222e; }
        [data-theme="dark"] .dt-error { color: #ff7b72; }
        """
    }

    /// Minimal highlight.js token CSS (covers common languages without
    /// shipping a full theme file). Theme-aware via `data-theme`.
    private static func highlightCSS() -> String {
        return """
        .hljs-comment, .hljs-quote { color: #6a737d; font-style: italic; }
        .hljs-keyword, .hljs-selector-tag, .hljs-built_in { color: #cf222e; }
        .hljs-string, .hljs-attr, .hljs-symbol { color: #0a3069; }
        .hljs-number, .hljs-literal { color: #0550ae; }
        .hljs-title, .hljs-name, .hljs-section, .hljs-title.function_ { color: #8250df; }
        .hljs-type, .hljs-class .hljs-title, .hljs-title.class_ { color: #953800; }
        .hljs-tag { color: #116329; }
        .hljs-attribute { color: #0550ae; }
        .hljs-regexp, .hljs-link { color: #0a3069; }
        .hljs-meta { color: #6a737d; }
        .hljs-deletion { color: #82071e; background: #ffebe9; }
        .hljs-addition { color: #116329; background: #dafbe1; }
        [data-theme="dark"] .hljs-comment, [data-theme="dark"] .hljs-quote { color: #9198a1; }
        [data-theme="dark"] .hljs-keyword, [data-theme="dark"] .hljs-selector-tag, [data-theme="dark"] .hljs-built_in { color: #ff7b72; }
        [data-theme="dark"] .hljs-string, [data-theme="dark"] .hljs-attr, [data-theme="dark"] .hljs-symbol { color: #a5d6ff; }
        [data-theme="dark"] .hljs-number, [data-theme="dark"] .hljs-literal { color: #79c0ff; }
        [data-theme="dark"] .hljs-title, [data-theme="dark"] .hljs-name, [data-theme="dark"] .hljs-section { color: #d2a8ff; }
        [data-theme="dark"] .hljs-type, [data-theme="dark"] .hljs-title.class_ { color: #ffa657; }
        [data-theme="dark"] .hljs-tag { color: #7ee787; }
        [data-theme="dark"] .hljs-attribute { color: #79c0ff; }
        [data-theme="dark"] .hljs-meta { color: #9198a1; }
        [data-theme="dark"] .hljs-deletion { color: #ffdcd7; background: #67060c; }
        [data-theme="dark"] .hljs-addition { color: #aff5b4; background: #033a16; }
        """
    }
}
