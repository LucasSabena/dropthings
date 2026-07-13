# Lazyweb Workflow Notes

Per `AGENTS.md`: before designing or changing product UI, consult Lazyweb
first and record the result or workflow note here.

## 2026-07-13 — Markdown Viewer module (new)

Prompt to Lazyweb: "Native macOS app, Swift/SwiftUI/AppKit. I need a new
module that is a Markdown viewer AND editor with a live, 100%-complete
GFM preview (tables, fenced code with syntax highlighting, nested lists,
task lists, images, strikethrough, autolinks). It must open .md files via
NSOpenPanel and drag-and-drop, edit them, save back, and be summonable
with a global hotkey. The project has zero external SwiftPM dependencies
today and I want to keep it that way. What is the smallest reliable
implementation shape?"

Workflow note (decision recorded in `docs/decisions.md`):

- Apple's `AttributedString(markdown:)` covers CommonMark but **not**
  tables, fenced-code highlighting, or GFM task lists. It is insufficient
  for the 100%-complete requirement.
- `NSAttributedString` from HTML needs a Markdown→HTML parser regardless,
  and Apple's HTML→NSAttributedString is slow on the main thread and
  supports a limited CSS subset.
- Writing a full GFM parser in Swift is out of scope for one module.
- Adding the first external SwiftPM dependency (e.g. swift-markdown-ui,
  cmark-gfm Swift wrapper) would break the project's "zero deps, small
  core" stance and requires a separate architecture decision.
- **Chosen shape**: `WKWebView` preview + `marked.js` (MIT) and
  `highlight.js` (BSD-3-Clause) bundled as SwiftPM resources under
  `MarkdownViewer/Resources/`. Editor is a plain `NSTextView` in an
  `NSViewRepresentable`. The window is a normal `NSWindow` with a
  split editor/preview, switchable to editor-only or preview-only.
  No TCC permission required (file access comes from `NSOpenPanel` /
  drag-and-drop, which grant scoped access).
- Licenses are compatible and tracked in `open-source-references.md`.
  Both JS files are vendored as-is from jsDelivr CDN.

Result: build proceeds with the WKWebView + vendored JS approach. Audit
lives in `docs/audits/markdown-viewer.md`.

## 2026-07-13 — Markdown Viewer reliability pass

Reused the Lazyweb recommendation above because this pass repairs the same
surface rather than changing its rendering architecture. The native document
interaction was checked against that workflow: keep `NSTextView` as the source
editor, synchronize edits before persistence, and expose familiar macOS file
commands instead of adding a custom editor abstraction.

Result: retain the existing `NSTextView` + `WKWebView` split, add standard
Open/Save/Save As/Close shortcuts, native dirty-window protection, explicit
Finder Automation feedback, and one shared Markdown file-type policy.
