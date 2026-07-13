import SwiftUI
import AppKit
import WebKit
import Combine

/// Live Markdown preview backed by `WKWebView`. The HTML shell (which pulls
/// in `marked.min.js` and `highlight.min.js` from the bundle) is loaded once;
/// subsequent Markdown edits are pushed via `evaluateJavaScript` so the
/// webview never reloads and stays smooth while typing.
///
/// External links open in the default browser via the navigation delegate.
struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String
    let theme: MarkdownTheme
    let fontSize: Int

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        let webView = MarkdownPreviewWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isInspectable = false
        webView.underPageBackgroundColor = .clear
        context.coordinator.webView = webView
        context.coordinator.currentTheme = theme
        context.coordinator.currentFontSize = fontSize
        context.coordinator.pendingMarkdown = markdown

        let html = MarkdownHTMLBuilder.shellHTML(theme: theme, fontSize: fontSize)
        let baseURL = MarkdownHTMLBuilder.resourcesBaseURL()
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coord = context.coordinator
        let themeOrFontChanged = coord.currentTheme != theme || coord.currentFontSize != fontSize
        if themeOrFontChanged {
            coord.currentTheme = theme
            coord.currentFontSize = fontSize
            coord.pendingMarkdown = markdown
            let html = MarkdownHTMLBuilder.shellHTML(theme: theme, fontSize: fontSize)
            let baseURL = MarkdownHTMLBuilder.resourcesBaseURL()
            webView.loadHTMLString(html, baseURL: baseURL)
            return
        }
        coord.pendingMarkdown = markdown
        webView.evaluateJavaScript(MarkdownHTMLBuilder.renderCall(for: markdown))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        var currentTheme: MarkdownTheme = .auto
        var currentFontSize: Int = 14
        var pendingMarkdown: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let pending = pendingMarkdown {
                webView.evaluateJavaScript(MarkdownHTMLBuilder.renderCall(for: pending))
            }
        }

        /// Open external links in the default browser, never inside the
        /// preview webview itself.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     handler: @escaping (WKWebView?) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            handler(nil)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme?.hasPrefix("http") == true {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

/// Subclass that draws a transparent background so the webview shows the
/// CSS-controlled `--bg` color directly.
private final class MarkdownPreviewWebView: WKWebView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}
