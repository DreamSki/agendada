import AppKit
import SwiftUI

struct AgendadaFloatingMenuSection: Identifiable {
    let id = UUID()
    var items: [AgendadaFloatingMenuItem]
}

struct AgendadaFloatingMenuItem: Identifiable {
    enum Role {
        case normal
        case destructive
    }

    let id = UUID()
    var iconSystemName: String
    var title: String
    var subtitle: String?
    var role: Role = .normal
    var isEnabled = true
    var showsSubmenuIndicator = false
    var dismissesAfterAction = true
    var action: @MainActor (AgendadaFloatingMenuPresenter) -> Void

    init(
        iconSystemName: String,
        title: String,
        subtitle: String? = nil,
        role: Role = .normal,
        isEnabled: Bool = true,
        showsSubmenuIndicator: Bool = false,
        dismissesAfterAction: Bool = true,
        action: @escaping @MainActor (AgendadaFloatingMenuPresenter) -> Void
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.isEnabled = isEnabled
        self.showsSubmenuIndicator = showsSubmenuIndicator
        self.dismissesAfterAction = dismissesAfterAction
        self.action = action
    }
}

@MainActor
final class AgendadaFloatingMenuPresenter {
    private var dismissHandler: (() -> Void)?
    private var showSubmenuHandler: (([AgendadaFloatingMenuSection]) -> Void)?

    func configure(
        dismiss: @escaping () -> Void,
        showSubmenu: @escaping ([AgendadaFloatingMenuSection]) -> Void
    ) {
        dismissHandler = dismiss
        showSubmenuHandler = showSubmenu
    }

    func showSubmenu(sections: [AgendadaFloatingMenuSection]) {
        showSubmenuHandler?(sections)
    }

    func dismiss() {
        dismissHandler?()
    }
}

struct AgendadaFloatingMenuView: View {
    let sections: [AgendadaFloatingMenuSection]
    let presenter: AgendadaFloatingMenuPresenter

    private let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.04))
                        .frame(height: 1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }

                ForEach(section.items) { item in
                    AgendadaFloatingMenuRow(item: item, presenter: presenter)
                }
            }
        }
        .padding(.vertical, 5)
        .frame(width: 214)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background {
            ZStack {
                AgendadaClearPopoverHost()

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.black.opacity(0.10), lineWidth: 0.6)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            }
        }
        .fixedSize()
    }
}

private struct AgendadaClearPopoverHost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        DispatchQueue.main.async {
            clearPopoverWindow(from: view)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.layer?.backgroundColor = NSColor.clear.cgColor
        DispatchQueue.main.async {
            clearPopoverWindow(from: view)
        }
    }

    private func clearPopoverWindow(from view: NSView) {
        guard let window = view.window else { return }
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
    }
}

private struct AgendadaFloatingMenuRow: View {
    let item: AgendadaFloatingMenuItem
    let presenter: AgendadaFloatingMenuPresenter
    @State private var isHovering = false

    private var foregroundColor: Color {
        if !item.isEnabled { return AgendaColor.textMuted }
        if item.role == .destructive { return .red }
        return Color(red: 0.08, green: 0.08, blue: 0.09)
    }

    var body: some View {
        Button {
            guard item.isEnabled else { return }
            item.action(presenter)
            if item.dismissesAfterAction {
                presenter.dismiss()
            }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: item.iconSystemName)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.role == .destructive ? .red : AgendaColor.amber)
                    .frame(width: 18, height: 18)
                    .opacity(item.isEnabled ? 1 : 0.55)

                Text(item.title)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)

                if item.showsSubmenuIndicator {
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AgendaColor.textMuted)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering && item.isEnabled ? Color.white.opacity(0.18) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .onHover { isHovering = $0 }
    }
}

private struct AgendadaFloatingMenuArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
