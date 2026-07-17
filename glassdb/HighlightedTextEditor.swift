//
//  HighlightedTextEditor.swift
//  glassdb
//
//  UITextView wrapper for syntax-highlighted SQL editing on visionOS.
//

import SwiftUI
import UIKit

struct HighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 14
    var showLineNumbers = false
    var selection: Binding<NSRange>?

    init(
        text: Binding<String>,
        fontSize: CGFloat = 14,
        showLineNumbers: Bool = false,
        selection: Binding<NSRange>? = nil
    ) {
        _text = text
        self.fontSize = fontSize
        self.showLineNumbers = showLineNumbers
        self.selection = selection
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
