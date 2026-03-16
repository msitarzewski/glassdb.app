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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
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

        // Apply initial highlighting
        if !text.isEmpty {
            let selected = textView.selectedRange
            textView.attributedText = SQLHighlighter.highlight(text, fontSize: fontSize)
            textView.selectedRange = selected
        }

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
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
        }
    }
}
