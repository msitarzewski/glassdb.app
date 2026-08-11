//
//  HighlightedTextEditor.swift
//  glassdb
//
//  UITextView wrapper for syntax-highlighted SQL editing on visionOS.
//

import SwiftUI

/// Pure gutter geometry shared by the AppKit and UIKit line-number editors so
/// both platforms (and tests) agree on the digit-count-driven width formula.
enum EditorGutterMetrics {
    static let plainInset: CGFloat = 12
    static let numberPadding: CGFloat = 8
    static let textGap: CGFloat = 6

    /// Width of the number gutter: enough monospaced digits for the current
    /// line count (minimum two digits) plus symmetric number padding.
    static func width(lineCount: Int, digitWidth: CGFloat) -> CGFloat {
        let digits = max(2, String(max(1, lineCount)).count)
        return ceil(CGFloat(digits) * digitWidth) + numberPadding * 2
    }
}

extension EnvironmentValues {
    /// Identity of the SQL document being edited. The Mac editor claims
    /// keyboard focus the first time it appears for a given token, so a
    /// document created from the File menu is ready to type into. Only the
    /// query editor sets it, so opening a table never pulls focus out of the
    /// sidebar.
    @Entry var sqlEditorFocusToken: UUID?
}

#if canImport(UIKit)
import UIKit

struct HighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 14
    var showLineNumbers = false
    var selection: Binding<NSRange>?
    var isActive = true

    init(
        text: Binding<String>,
        fontSize: CGFloat = 14,
        showLineNumbers: Bool = false,
        selection: Binding<NSRange>? = nil,
        isActive: Bool = true
    ) {
        _text = text
        self.fontSize = fontSize
        self.showLineNumbers = showLineNumbers
        self.selection = selection
        self.isActive = isActive
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = LineNumberTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.keyboardType = .asciiCapable
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .label
        textView.lineNumbersEnabled = showLineNumbers
        textView.lineNumberFontSize = fontSize

        // Apply initial highlighting
        if !text.isEmpty {
            let selected = textView.selectedRange
            textView.attributedText = SQLHighlighter.highlight(text, fontSize: fontSize)
            textView.selectedRange = selected
        }

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        textView.isEditable = isActive
        if !isActive, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
        if let lineNumberTextView = textView as? LineNumberTextView {
            lineNumberTextView.lineNumbersEnabled = showLineNumbers
            lineNumberTextView.lineNumberFontSize = fontSize
        }

        // Only update if text changed externally (e.g. pendingQuery injection)
        if textView.text != text {
            let selected = textView.selectedRange
            textView.attributedText = SQLHighlighter.highlight(text, fontSize: fontSize)
            // Clamp selection to valid range after text replacement
            let maxLen = textView.attributedText.length
            let clampedLoc = min(selected.location, maxLen)
            let clampedLen = min(selected.length, maxLen - clampedLoc)
            textView.selectedRange = NSRange(location: clampedLoc, length: clampedLen)
        }
        if let requestedSelection = selection?.wrappedValue,
           requestedSelection != textView.selectedRange {
            let maxLength = textView.attributedText.length
            let location = min(requestedSelection.location, maxLength)
            textView.selectedRange = NSRange(
                location: location,
                length: min(requestedSelection.length, maxLength - location)
            )
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightedTextEditor

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let plainText = textView.text ?? ""
            parent.text = plainText

            // Re-highlight, preserving cursor position
            let selected = textView.selectedRange
            textView.attributedText = SQLHighlighter.highlight(
                plainText, fontSize: parent.fontSize
            )
            textView.selectedRange = selected
            parent.selection?.wrappedValue = selected
            (textView as? LineNumberTextView)?.setNeedsDisplay()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection?.wrappedValue = textView.selectedRange
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            (scrollView as? LineNumberTextView)?.setNeedsDisplay()
        }
    }
}

/// Draws logical line numbers in the text view's existing scroll coordinate
/// space, keeping the gutter aligned without a second synchronized scroll view.
private final class LineNumberTextView: UITextView {
    private var lineCount = 1
    /// Width of the number gutter; text begins `textGap` points after it.
    private var gutterWidth: CGFloat = 0
    private static let plainInset = EditorGutterMetrics.plainInset
    private static let numberPadding = EditorGutterMetrics.numberPadding
    private static let textGap = EditorGutterMetrics.textGap

    var lineNumbersEnabled = false {
        didSet {
            updateTextInset()
            setNeedsDisplay()
        }
    }

    var lineNumberFontSize: CGFloat = 14 {
        didSet {
            updateTextInset()
            setNeedsDisplay()
        }
    }

    private var numberFont: UIFont {
        .monospacedDigitSystemFont(ofSize: max(10, lineNumberFontSize - 2), weight: .regular)
    }

    override var text: String! {
        didSet {
            refreshLineCount()
            setNeedsDisplay()
        }
    }

    override var attributedText: NSAttributedString! {
        didSet {
            refreshLineCount()
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard lineNumbersEnabled, let context = UIGraphicsGetCurrentContext() else { return }

        context.saveGState()
        let fullText = (text ?? "") as NSString
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: UIColor.secondaryLabel,
        ]

        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) {
            _, usedRect, _, glyphRange, _ in
            let characterIndex = self.layoutManager.characterIndexForGlyph(at: glyphRange.location)
            guard characterIndex == 0 || fullText.character(at: characterIndex - 1) == 10 else { return }
            let prefix = fullText.substring(to: min(characterIndex, fullText.length))
            let lineNumber = prefix.reduce(into: 1) { count, character in
                if character == "\n" { count += 1 }
            }
            let number = "\(lineNumber)" as NSString
            let size = number.size(withAttributes: attributes)
            number.draw(
                at: CGPoint(
                    x: self.gutterWidth - Self.numberPadding - size.width,
                    y: usedRect.minY + self.textContainerInset.top
                ),
                withAttributes: attributes
            )
        }
        context.restoreGState()
    }

    /// Sizes the gutter to the current digit count (minimum two digits),
    /// mirroring the Mac metrics; the inset only moves when the width changes.
    private func updateTextInset() {
        if lineNumbersEnabled {
            let digitWidth = ("0" as NSString).size(withAttributes: [.font: numberFont]).width
            gutterWidth = EditorGutterMetrics.width(lineCount: lineCount, digitWidth: digitWidth)
        } else {
            gutterWidth = 0
        }
        var inset = textContainerInset
        inset.left = lineNumbersEnabled ? gutterWidth + Self.textGap : Self.plainInset
        if textContainerInset != inset {
            textContainerInset = inset
        }
    }

    private func refreshLineCount() {
        let value = (text ?? "") as NSString
        var count = 1
        if value.length > 0 {
            for index in 0..<value.length where value.character(at: index) == 10 {
                count += 1
            }
        }
        if count != lineCount {
            lineCount = count
            updateTextInset()
        }
    }
}
#elseif canImport(AppKit)
import AppKit

struct HighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 14
    var showLineNumbers = false
    var selection: Binding<NSRange>?
    var isActive = true

    @Environment(\.sqlEditorFocusToken) private var focusToken

    init(
        text: Binding<String>,
        fontSize: CGFloat = 14,
        showLineNumbers: Bool = false,
        selection: Binding<NSRange>? = nil,
        isActive: Bool = true
    ) {
        _text = text
        self.fontSize = fontSize
        self.showLineNumbers = showLineNumbers
        self.selection = selection
        self.isActive = isActive
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = LineNumberTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.lineNumbersEnabled = showLineNumbers
        textView.lineNumberFontSize = fontSize
        textView.appliedFontSize = fontSize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        if text.isEmpty {
            textView.string = ""
        } else {
            textView.textStorage?.setAttributedString(SQLHighlighter.highlight(text, fontSize: fontSize))
        }
        textView.rebuildLineStarts()
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? LineNumberTextView else { return }
        context.coordinator.parent = self
        textView.isEditable = isActive
        if !isActive, textView.window?.firstResponder === textView {
            textView.window?.makeFirstResponder(nil)
        }
        // A newly shown SQL document takes the keyboard once, so File > New SQL
        // Document lands the caret in its editor instead of the sidebar filter.
        if isActive,
           let focusToken,
           context.coordinator.claimedFocusToken != focusToken,
           let window = textView.window {
            context.coordinator.claimedFocusToken = focusToken
            window.makeFirstResponder(textView)
        }
        textView.lineNumbersEnabled = showLineNumbers
        textView.lineNumberFontSize = fontSize

        if textView.string != text || textView.appliedFontSize != fontSize {
            let selected = textView.selectedRange()
            context.coordinator.applyHighlight(text, to: textView, fontSize: fontSize)
            textView.rebuildLineStarts()
            textView.appliedFontSize = fontSize
            textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            textView.setSelectedRange(Self.clamped(selected, maximum: textView.string.utf16.count))
        }
        if let requestedSelection = selection?.wrappedValue,
           requestedSelection != textView.selectedRange() {
            textView.setSelectedRange(Self.clamped(requestedSelection, maximum: textView.string.utf16.count))
        }
    }

    private static func clamped(_ range: NSRange, maximum: Int) -> NSRange {
        let location = min(range.location, maximum)
        return NSRange(location: location, length: min(range.length, maximum - location))
    }

    @MainActor
        final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextEditor
        /// Focus token this editor has already honored, so it claims the
        /// keyboard once per document instead of on every update.
        var claimedFocusToken: UUID?
        private var isApplyingHighlight = false
        private var highlightTask: Task<Void, Never>?

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingHighlight, let textView = notification.object as? NSTextView else { return }
            let plainText = textView.string
            parent.text = plainText
            parent.selection?.wrappedValue = textView.selectedRange()
            (textView as? LineNumberTextView)?.rebuildLineStarts()
            textView.needsDisplay = true

            // Avoid replacing marked-text attributes and retokenizing an entire
            // large document for every key repeat. The committed text remains
            // immediately editable and is highlighted after a short idle beat.
            highlightTask?.cancel()
            guard !textView.hasMarkedText() else { return }
            let fontSize = parent.fontSize
            highlightTask = Task { @MainActor [weak textView] in
                try? await Task.sleep(for: .milliseconds(75))
                guard !Task.isCancelled,
                      let textView,
                      textView.string == plainText,
                      !textView.hasMarkedText() else { return }
                let selected = textView.selectedRange()
                let typingAttributes = textView.typingAttributes
                self.applyHighlight(plainText, to: textView, fontSize: fontSize)
                textView.typingAttributes = typingAttributes
                textView.setSelectedRange(HighlightedTextEditor.clamped(
                    selected,
                    maximum: plainText.utf16.count
                ))
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingHighlight, let textView = notification.object as? NSTextView else { return }
            parent.selection?.wrappedValue = textView.selectedRange()
        }

        func applyHighlight(_ value: String, to textView: NSTextView, fontSize: CGFloat) {
            isApplyingHighlight = true
            textView.textStorage?.setAttributedString(SQLHighlighter.highlight(value, fontSize: fontSize))
            isApplyingHighlight = false
        }

        deinit {
            highlightTask?.cancel()
        }
    }
}

private final class LineNumberTextView: NSTextView {
    var appliedFontSize: CGFloat = 14
    private var lineStarts: [Int] = [0]
    /// Width of the tinted gutter band; text begins `textGap` points after it.
    private var gutterWidth: CGFloat = 0
    private static let plainInset = EditorGutterMetrics.plainInset
    private static let numberPadding = EditorGutterMetrics.numberPadding
    private static let textGap = EditorGutterMetrics.textGap

    var lineNumbersEnabled = false {
        didSet {
            updateGutterMetrics()
            needsDisplay = true
        }
    }

    var lineNumberFontSize: CGFloat = 14 {
        didSet {
            updateGutterMetrics()
            needsDisplay = true
        }
    }

    private var numberFont: NSFont {
        .monospacedDigitSystemFont(ofSize: max(10, lineNumberFontSize - 2), weight: .regular)
    }

    /// NSTextView's inset is symmetric, so the gutter is laid out by keeping
    /// the inset at the leading/trailing average and shifting the origin by
    /// half their difference: the tracked container width still equals the
    /// frame minus both edges, and caret/selection/hit-testing all follow the
    /// origin, so the text wraps and hits exactly where it is drawn.
    override var textContainerOrigin: NSPoint {
        var origin = super.textContainerOrigin
        if lineNumbersEnabled {
            origin.x += (gutterWidth + Self.textGap - Self.plainInset) / 2
        }
        return origin
    }

    /// NSTextView's own drawing leaves the graphics state such that nothing
    /// painted afterwards reaches the backing store, so the gutter is drawn
    /// first. It never overlaps the glyphs: the text container starts
    /// `textGap` points past the band.
    override func draw(_ dirtyRect: NSRect) {
        if lineNumbersEnabled {
            drawGutterBand(in: dirtyRect)
            drawLineNumbers()
        }
        super.draw(dirtyRect)
    }

    private func drawLineNumbers() {
        guard let layoutManager, let textContainer else { return }

        let fullText = string as NSString
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let origin = textContainerOrigin

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
            _, usedRect, _, lineGlyphRange, _ in
            let characterIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)
            guard characterIndex == 0 || fullText.character(at: characterIndex - 1) == 10 else { return }
            let lineNumber = self.lineNumber(containing: characterIndex)
            let number = "\(lineNumber)" as NSString
            let size = number.size(withAttributes: attributes)
            number.draw(
                at: NSPoint(
                    x: self.gutterWidth - Self.numberPadding - size.width,
                    y: usedRect.minY + origin.y
                ),
                withAttributes: attributes
            )
        }
    }

    /// Subtle tint plus a hairline separator so the gutter reads as an
    /// intentional region, matching the results grid's frozen row-number
    /// column. Dynamic colors resolve against the current appearance at draw
    /// time; the rest of the view stays transparent.
    private func drawGutterBand(in dirtyRect: NSRect) {
        guard dirtyRect.minX < gutterWidth else { return }
        NSColor.labelColor.withAlphaComponent(0.045).setFill()
        NSRect(x: 0, y: dirtyRect.minY, width: gutterWidth, height: dirtyRect.height).fill()
        let hairlineWidth = 1 / (window?.backingScaleFactor ?? 2)
        NSColor.separatorColor.setFill()
        NSRect(
            x: gutterWidth - hairlineWidth,
            y: dirtyRect.minY,
            width: hairlineWidth,
            height: dirtyRect.height
        ).fill()
    }

    /// Sizes the gutter to the current digit count (minimum two digits) and
    /// keeps the symmetric inset in sync. Setting the inset invalidates the
    /// container origin, so layout and drawing stay agreed on the geometry.
    private func updateGutterMetrics() {
        let targetWidth: CGFloat
        let targetInset: NSSize
        if lineNumbersEnabled {
            let digitWidth = ("0" as NSString).size(withAttributes: [.font: numberFont]).width
            targetWidth = EditorGutterMetrics.width(lineCount: lineStarts.count, digitWidth: digitWidth)
            targetInset = NSSize(
                width: (targetWidth + Self.textGap + Self.plainInset) / 2,
                height: Self.plainInset
            )
        } else {
            targetWidth = 0
            targetInset = NSSize(width: Self.plainInset, height: Self.plainInset)
        }
        if targetWidth != gutterWidth {
            gutterWidth = targetWidth
            needsDisplay = true
        }
        if textContainerInset != targetInset {
            textContainerInset = targetInset
        }
    }

    func rebuildLineStarts() {
        let value = string as NSString
        var starts = [0]
        starts.reserveCapacity(max(1, value.length / 40))
        if value.length > 0 {
            for index in 0..<value.length where value.character(at: index) == 10 {
                starts.append(index + 1)
            }
        }
        lineStarts = starts
        updateGutterMetrics()
    }

    private func lineNumber(containing characterIndex: Int) -> Int {
        var lower = 0
        var upper = lineStarts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lineStarts[middle] <= characterIndex {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return max(1, lower)
    }
}
#endif
