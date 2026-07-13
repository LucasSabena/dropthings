import SwiftUI
import AppKit
import Combine

/// Plain-text Markdown editor backed by `NSTextView` inside a scroll view.
/// Monospaced font, line wrapping on, ligatures off so Markdown punctuation
/// stays literal. Edits publish back to the binding; external updates
/// (e.g. opening a new file) overwrite the buffer while preserving the
/// selection range when possible.
struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Int
    let showLineNumbers: Bool
    let onChange: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownTextView()
        textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindPanel = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesInspectorBar = false
        textView.usesRuler = showLineNumbers

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor
        scrollView.documentView = textView
        scrollView.contentView.backgroundColor = NSColor.textBackgroundColor

        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.owner = self

        let lineNumberView = showLineNumbers ? LineNumberRulerView(textView: textView) : nil
        if let lineNumberView {
            scrollView.verticalRulerView = lineNumberView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        let newSize = CGFloat(fontSize)
        if let font = textView.font, font.fontName != NSFont.monospacedSystemFont(ofSize: newSize, weight: .regular).fontName || font.pointSize != newSize {
            textView.font = NSFont.monospacedSystemFont(ofSize: newSize, weight: .regular)
        }
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
        let wantRuler = showLineNumbers
        if wantRuler && scrollView.verticalRulerView == nil {
            let ruler = LineNumberRulerView(textView: textView)
            scrollView.verticalRulerView = ruler
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        } else if !wantRuler && scrollView.verticalRulerView != nil {
            scrollView.verticalRulerView = nil
            scrollView.hasVerticalRuler = false
            scrollView.rulersVisible = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var owner: MarkdownEditorView?
        private var lastReported: String?

        init(_ owner: MarkdownEditorView) {
            self.owner = owner
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let owner else { return }
            let new = textView.string
            guard new != lastReported else { return }
            lastReported = new
            DispatchQueue.main.async {
                owner.text = new
                owner.onChange()
            }
        }
    }
}

/// Subclass to opt out of non-essential smart substitutions that mangle
/// Markdown punctuation (curly quotes, em dashes, etc.).
private final class MarkdownTextView: NSTextView {}

/// Minimal vertical ruler that shows line numbers for the visible range.
/// Cheaper than a full gutter view and enough for the "show line numbers"
/// setting.
private final class LineNumberRulerView: NSRulerView {
    private let attr: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: NSColor.secondaryLabelColor
    ]

    init(textView: NSTextView) {
        super.init(scrollView: nil, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 36
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager else { return }
        NSColor.textBackgroundColor.setFill()
        rect.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: rect.maxX - 0.5, y: 0, width: 0.5, height: rect.height).fill()

        let string = textView.string as NSString
        let totalLines = max(1, string.numberOfLines)
        let visibleRect = textView.visibleRect
        let origin = textView.textContainerOrigin

        // Walk line-by-line using the layout manager's glyph layout for each
        // line break in the source string. This stays correct even when soft
        // wrapping is enabled, because we count source lines, not wrapped ones.
        var lineNumber = 1
        var charLocation = 0
        while charLocation <= string.length {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: charLocation, length: 0),
                                                     actualCharacterRange: nil)
            guard glyphRange.length >= 0 else { break }
            let fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let yInScrollView = fragmentRect.origin.y - origin.y
            let yInRuler = yInScrollView - visibleRect.origin.y
            if yInRuler >= rect.minY - 20 && yInRuler <= rect.maxY + 20 {
                let label = String(lineNumber) as NSString
                let size = label.size(withAttributes: attr)
                label.draw(at: NSPoint(x: rect.maxX - size.width - 6, y: yInRuler + 2), withAttributes: attr)
            }
            // Advance to the next source line.
            let usedRange = string.lineRange(for: NSRange(location: charLocation, length: 0))
            let nextStart = NSMaxRange(usedRange)
            if nextStart <= charLocation { break }
            charLocation = nextStart
            lineNumber += 1
            if lineNumber > totalLines + 1 { break }
        }
    }
}

private extension NSString {
    var numberOfLines: Int {
        var count = 1
        var location = 0
        while location < length {
            let range = lineRange(for: NSRange(location: location, length: 0))
            let next = NSMaxRange(range)
            if next <= location { break }
            if next >= length { break }
            count += 1
            location = next
        }
        return count
    }
}
