//
//  HighlightedTextEditor.swift
//  glassdb
//
//  UITextView wrapper for syntax-highlighted SQL editing on visionOS.
//

import SwiftUI
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
    var lineNumbersEnabled = false {
        didSet {
            updateTextInset()
            setNeedsDisplay()
        }
    }

    var lineNumberFontSize: CGFloat = 14 {
        didSet { setNeedsDisplay() }
    }

    override var text: String! {
        didSet { setNeedsDisplay() }
    }

    override var attributedText: NSAttributedString! {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard lineNumbersEnabled, let context = UIGraphicsGetCurrentContext() else { return }

        context.saveGState()
        let fullText = (text ?? "") as NSString
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: max(10, lineNumberFontSize - 2), weight: .regular),
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
                    x: self.textContainerInset.left - size.width - 10,
                    y: usedRect.minY + self.textContainerInset.top
                ),
                withAttributes: attributes
            )
        }
        context.restoreGState()
    }

    private func updateTextInset() {
        var inset = textContainerInset
        inset.left = lineNumbersEnabled ? 56 : 12
        textContainerInset = inset
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
        textView.lineNumbersEnabled = showLineNumbers
        textView.lineNumberFontSize = fontSize

        if textView.string != text || textView.appliedFontSize != fontSize {
            let selected = textView.selectedRange()
            context.coordinator.applyHighlight(text, to: textView, fontSize: fontSize)
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
    var lineNumbersEnabled = false {
        didSet {
            updateTextInset()
            needsDisplay = true
        }
    }

    var lineNumberFontSize: CGFloat = 14 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard lineNumbersEnabled,
              let layoutManager,
              let textContainer else { return }

        let fullText = string as NSString
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: max(10, lineNumberFontSize - 2), weight: .regular),
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
                    x: self.textContainerInset.width - size.width - 10,
                    y: usedRect.minY + origin.y
                ),
                withAttributes: attributes
            )
        }
    }

    private func updateTextInset() {
        textContainerInset = NSSize(width: lineNumbersEnabled ? 56 : 12, height: 12)
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
