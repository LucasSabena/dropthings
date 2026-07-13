import XCTest
@testable import DropThingsModules

/// Smoke tests that confirm the vendored JS resources ship inside the
/// SwiftPM bundle and that the HTML builder produces a loadable shell.
/// These guard against a Package.swift `resources:` regression that would
/// silently leave the preview with no Markdown engine.
final class MarkdownResourcesTests: XCTestCase {

    func testMarkedJSIsPresentInBundle() {
        let url = Bundle.module.url(forResource: "marked.min", withExtension: "js")
        XCTAssertNotNil(url, "marked.min.js must be bundled with the MarkdownViewer module")
        if let url {
            let data = try? Data(contentsOf: url)
            XCTAssertGreaterThan(data?.count ?? 0, 1000, "marked.min.js should be the real minified bundle")
        }
    }

    func testHighlightJSIsPresentInBundle() {
        let url = Bundle.module.url(forResource: "highlight.min", withExtension: "js")
        XCTAssertNotNil(url, "highlight.min.js must be bundled with the MarkdownViewer module")
        if let url {
            let data = try? Data(contentsOf: url)
            XCTAssertGreaterThan(data?.count ?? 0, 1000, "highlight.min.js should be the real minified bundle")
        }
    }

    func testResourcesBaseURLResolvesToDirectoryContainingBothScripts() {
        let baseURL = MarkdownHTMLBuilder.resourcesBaseURL()
        XCTAssertNotNil(baseURL, "resourcesBaseURL must resolve so the WKWebView can load the scripts")
        if let baseURL {
            let marked = URL(fileURLWithPath: "marked.min.js", relativeTo: baseURL)
            let highlight = URL(fileURLWithPath: "highlight.min.js", relativeTo: baseURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: marked.path),
                          "marked.min.js should be reachable from resourcesBaseURL")
            XCTAssertTrue(FileManager.default.fileExists(atPath: highlight.path),
                          "highlight.min.js should be reachable from resourcesBaseURL")
        }
    }

    func testShellHTMLContainsScriptTagsAndBridge() {
        let html = MarkdownHTMLBuilder.shellHTML(theme: .light, fontSize: 14)
        XCTAssertTrue(html.contains("marked.min.js"), "shell HTML must reference marked.min.js")
        XCTAssertTrue(html.contains("highlight.min.js"), "shell HTML must reference highlight.min.js")
        XCTAssertTrue(html.contains("window.dropthings"), "shell HTML must define the bridge")
        XCTAssertTrue(html.contains("data-theme=\"light\""), "shell HTML must set the theme attribute")
    }

    func testShellHTMLDarkThemeUsesDarkAttribute() {
        let html = MarkdownHTMLBuilder.shellHTML(theme: .dark, fontSize: 16)
        XCTAssertTrue(html.contains("data-theme=\"dark\""))
    }

    func testRenderCallSafelyEscapesQuotes() {
        let markdown = "Hello \"world\" and\n```js\nvar x = 'y';\n```"
        let call = MarkdownHTMLBuilder.renderCall(for: markdown)
        XCTAssertTrue(call.hasPrefix("window.dropthings && window.dropthings.render("))
        XCTAssertTrue(call.hasSuffix(");"))
        // The markdown must be JSON-encoded so quotes and newlines are safe.
        XCTAssertFalse(call.contains("Hello \"world\""), "Quotes must be JSON-escaped in the JS payload")
    }

    func testRenderCallForEmptyStringStillCallsRender() {
        let call = MarkdownHTMLBuilder.renderCall(for: "")
        XCTAssertTrue(call.contains("render("))
    }

    func testSetThemeCallEmitsValidJS() {
        XCTAssertEqual(MarkdownHTMLBuilder.setThemeCall(.dark),
                       "window.dropthings && window.dropthings.setTheme('dark');")
        XCTAssertEqual(MarkdownHTMLBuilder.setThemeCall(.light),
                       "window.dropthings && window.dropthings.setTheme('light');")
    }
}
