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

// MARK: - Native NSPopover Bridge

struct NSPopoverPresenter<PopoverContent: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let preferredEdge: NSRectEdge
    let contentSize: CGSize
    let content: () -> PopoverContent

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self

        if isPresented {
            context.coordinator.show(from: nsView)
        } else {
            context.coordinator.close()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        var parent: NSPopoverPresenter
        var popover: NSPopover?

        init(parent: NSPopoverPresenter) {
            self.parent = parent
        }

        func show(from view: NSView) {
            if popover?.isShown == true { return }

            let p = NSPopover()
            p.behavior = .transient
            p.animates = true
            p.contentSize = parent.contentSize
            p.delegate = self

            let hosting = NSHostingController(rootView: parent.content())
            hosting.view.wantsLayer = true

            p.contentViewController = hosting

            let anchorRect = NSRect(
                x: view.bounds.midX - 1,
                y: view.bounds.midY - 1,
                width: 2,
                height: 2
            )

            p.show(relativeTo: anchorRect, of: view, preferredEdge: parent.preferredEdge)
            popover = p
        }

        func close() {
            popover?.performClose(nil)
            popover = nil
        }

        func popoverDidClose(_ notification: Notification) {
            popover = nil
            if parent.isPresented {
                parent.isPresented = false
            }
        }
    }
}
