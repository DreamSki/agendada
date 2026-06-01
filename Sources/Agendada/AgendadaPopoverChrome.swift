import AppKit
import SwiftUI

extension View {
    func agendadaGlassPopover(cornerRadius: CGFloat = 16) -> some View {
        modifier(AgendadaGlassPopoverModifier(cornerRadius: cornerRadius))
            .presentationBackground(.clear)
    }
}

private struct AgendadaGlassPopoverModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background {
                ZStack {
                    AgendadaPopoverWindowBackdrop(cornerRadius: cornerRadius)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.16),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.42), lineWidth: 0.5)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.black.opacity(0.16), lineWidth: 0.7)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 10)
                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                }
            }
    }
}

private struct AgendadaPopoverWindowBackdrop: NSViewRepresentable {
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        DispatchQueue.main.async {
            configurePopoverWindow(from: view, cornerRadius: cornerRadius)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.layer?.backgroundColor = NSColor.clear.cgColor
        DispatchQueue.main.async {
            configurePopoverWindow(from: view, cornerRadius: cornerRadius)
        }
    }

    private func configurePopoverWindow(from view: NSView, cornerRadius: CGFloat) {
        guard let window = view.window, let contentView = window.contentView else { return }

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        clearBackgrounds(from: contentView)

        let identifier = NSUserInterfaceItemIdentifier("AgendadaPopoverWindowBackdrop")
        let backdrop: NSVisualEffectView
        if let existing = contentView.subviews.first(where: { $0.identifier == identifier }) as? NSVisualEffectView {
            backdrop = existing
        } else {
            backdrop = NSVisualEffectView()
            backdrop.identifier = identifier
            backdrop.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(backdrop, positioned: .below, relativeTo: nil)
            NSLayoutConstraint.activate([
                backdrop.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                backdrop.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                backdrop.topAnchor.constraint(equalTo: contentView.topAnchor),
                backdrop.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }

        backdrop.material = .popover
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = cornerRadius
        backdrop.layer?.cornerCurve = .continuous
        backdrop.layer?.masksToBounds = true
    }

    private func clearBackgrounds(from view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        for subview in view.subviews where subview.identifier?.rawValue != "AgendadaPopoverWindowBackdrop" {
            clearBackgrounds(from: subview)
        }
    }
}
