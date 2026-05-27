@preconcurrency import AppKit
import SwiftUI

@MainActor
struct PlainGrowingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    let placeholder: String
    let font: NSFont
    let minHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.placeholder = placeholder
        textView.string = text
        textView.font = font
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.bounds.width, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }

        context.coordinator.parent = self
        textView.placeholder = placeholder
        textView.font = font
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        textView.minSize = NSSize(width: 0, height: minHeight)

        let width = max(scrollView.bounds.width, scrollView.frame.width, scrollView.contentView.bounds.width, scrollView.contentSize.width, 1)
        if abs(textView.frame.width - width) > 0.5 || textView.frame.height < minHeight {
            textView.frame.size = NSSize(width: width, height: max(textView.frame.height, minHeight))
        }

        if textView.string != text {
            textView.string = text
        }

        textView.needsDisplay = true
        context.coordinator.remeasureIfNeeded(textView)
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 6
        return style
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainGrowingTextView
        private var lastMeasuredText = ""
        private var lastMeasuredWidth: CGFloat = 0
        private var lastMeasuredMinHeight: CGFloat = 0

        init(_ parent: PlainGrowingTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            remeasure(textView)
        }

        func remeasureIfNeeded(_ textView: NSTextView) {
            let width = measuredWidth(for: textView)
            guard width >= 180 else { return }
            guard textView.string != lastMeasuredText ||
                    abs(width - lastMeasuredWidth) > 0.5 ||
                    abs(parent.minHeight - lastMeasuredMinHeight) > 0.5 else {
                return
            }

            remeasure(textView)
        }

        func remeasure(_ textView: NSTextView) {
            guard let textContainer = textView.textContainer,
                  let layoutManager = textView.layoutManager else {
                return
            }

            let width = measuredWidth(for: textView)
            guard width >= 180 else { return }
            textView.frame.size.width = width
            textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let nextHeight = measuredTextHeight(for: textView, width: width)

            lastMeasuredText = textView.string
            lastMeasuredWidth = width
            lastMeasuredMinHeight = parent.minHeight

            if abs(parent.measuredHeight - nextHeight) > 0.5 {
                parent.measuredHeight = nextHeight
            }
            textView.frame.size.height = nextHeight
        }

        private func measuredTextHeight(for textView: NSTextView, width: CGFloat) -> CGFloat {
            let text = textView.string.isEmpty ? " " : textView.string
            let attributes: [NSAttributedString.Key: Any] = [
                .font: parent.font,
                .paragraphStyle: parent.paragraphStyle
            ]
            let rect = (text as NSString).boundingRect(
                with: NSSize(width: max(width, 1), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )
            return max(parent.minHeight, ceil(rect.height) + 6)
        }

        private func measuredWidth(for textView: NSTextView) -> CGFloat {
            let scrollView = textView.enclosingScrollView
            return max(
                textView.bounds.width,
                textView.frame.width,
                scrollView?.bounds.width ?? 0,
                scrollView?.frame.width ?? 0,
                scrollView?.contentView.bounds.width ?? 0,
                scrollView?.contentSize.width ?? 0,
                0
            )
        }
    }
}

@MainActor
private final class PlaceholderTextView: NSTextView {
    var placeholder = ""

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        placeholder.draw(at: NSPoint(x: textContainerInset.width, y: textContainerInset.height), withAttributes: attributes)
    }
}
