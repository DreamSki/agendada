import SwiftUI

private struct FloatingMenuHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readFloatingMenuHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FloatingMenuHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(FloatingMenuHeightPreferenceKey.self) { height in
            onChange(height)
        }
    }
}

struct AgendadaFloatingMenuSection: Identifiable {
    let id = UUID()
    var items: [AgendadaFloatingMenuItem]
}

struct AgendadaFloatingMenuItem: Identifiable {
    enum Role {
        case normal
        case destructive
    }

    enum IconStyle {
        case systemImage(String)
        case colorCircle(Color?)
        case text(String)
        case empty
    }

    let id = UUID()
    var iconStyle: IconStyle
    var title: String
    var subtitle: String?
    var role: Role = .normal
    var isEnabled = true
    var isHeader = false
    var showsSubmenuIndicator = false
    var dismissesAfterAction = true
    var action: @MainActor (AgendadaFloatingMenuPresenter) -> Void

    init(
        iconSystemName: String,
        title: String,
        subtitle: String? = nil,
        role: Role = .normal,
        isEnabled: Bool = true,
        isHeader: Bool = false,
        showsSubmenuIndicator: Bool = false,
        dismissesAfterAction: Bool = true,
        action: @escaping @MainActor (AgendadaFloatingMenuPresenter) -> Void
    ) {
        self.iconStyle = .systemImage(iconSystemName)
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.isEnabled = isEnabled
        self.isHeader = isHeader
        self.showsSubmenuIndicator = showsSubmenuIndicator
        self.dismissesAfterAction = dismissesAfterAction
        self.action = action
    }

    init(
        iconColor: Color?,
        title: String,
        subtitle: String? = nil,
        role: Role = .normal,
        isEnabled: Bool = true,
        isHeader: Bool = false,
        showsSubmenuIndicator: Bool = false,
        dismissesAfterAction: Bool = true,
        action: @escaping @MainActor (AgendadaFloatingMenuPresenter) -> Void
    ) {
        self.iconStyle = .colorCircle(iconColor)
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.isEnabled = isEnabled
        self.isHeader = isHeader
        self.showsSubmenuIndicator = showsSubmenuIndicator
        self.dismissesAfterAction = dismissesAfterAction
        self.action = action
    }

    init(
        iconText: String,
        title: String,
        subtitle: String? = nil,
        role: Role = .normal,
        isEnabled: Bool = true,
        isHeader: Bool = false,
        showsSubmenuIndicator: Bool = false,
        dismissesAfterAction: Bool = true,
        action: @escaping @MainActor (AgendadaFloatingMenuPresenter) -> Void
    ) {
        self.iconStyle = .text(iconText)
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.isEnabled = isEnabled
        self.isHeader = isHeader
        self.showsSubmenuIndicator = showsSubmenuIndicator
        self.dismissesAfterAction = dismissesAfterAction
        self.action = action
    }

    init(
        title: String,
        subtitle: String? = nil,
        role: Role = .normal,
        isEnabled: Bool = true,
        isHeader: Bool = false,
        showsSubmenuIndicator: Bool = false,
        dismissesAfterAction: Bool = true,
        action: @escaping @MainActor (AgendadaFloatingMenuPresenter) -> Void
    ) {
        self.iconStyle = .empty
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.isEnabled = isEnabled
        self.isHeader = isHeader
        self.showsSubmenuIndicator = showsSubmenuIndicator
        self.dismissesAfterAction = dismissesAfterAction
        self.action = action
    }
}

@MainActor
final class AgendadaFloatingMenuPresenter: ObservableObject {
    private var dismissHandler: (() -> Void)?
    private var showSubmenuHandler: (([AgendadaFloatingMenuSection]) -> Void)?
    private var popToRootHandler: (() -> Void)?
    private var titleStack: [String?] = []

    // Menu stack for navigation
    @Published private(set) var menuStack: [[AgendadaFloatingMenuSection]] = []
    @Published private(set) var currentSections: [AgendadaFloatingMenuSection] = []
    @Published private(set) var currentBackTitle: String?

    var isInSubmenu: Bool {
        !menuStack.isEmpty
    }

    func configure(
        dismiss: @escaping () -> Void,
        showSubmenu: @escaping ([AgendadaFloatingMenuSection]) -> Void,
        popToRoot: @escaping () -> Void = {}
    ) {
        dismissHandler = dismiss
        showSubmenuHandler = showSubmenu
        popToRootHandler = popToRoot
    }

    func reset() {
        menuStack.removeAll()
        titleStack.removeAll()
        currentSections = []
        currentBackTitle = nil
    }

    func setRootSections(_ sections: [AgendadaFloatingMenuSection]) {
        menuStack.removeAll()
        titleStack.removeAll()
        currentSections = sections
        currentBackTitle = nil
    }

    func showSubmenu(sections: [AgendadaFloatingMenuSection], title: String? = nil) {
        // Push current sections to stack before showing submenu
        if !currentSections.isEmpty {
            menuStack.append(currentSections)
            titleStack.append(currentBackTitle)
        }
        currentSections = sections
        currentBackTitle = title
        showSubmenuHandler?(sections)
    }

    func popToRoot() {
        guard let rootSections = menuStack.first else { return }
        menuStack.removeAll()
        titleStack.removeAll()
        currentSections = rootSections
        currentBackTitle = nil
        popToRootHandler?()
    }

    func goBack() {
        guard !menuStack.isEmpty else {
            dismiss()
            return
        }
        currentSections = menuStack.removeLast()
        currentBackTitle = titleStack.isEmpty ? nil : titleStack.removeLast()
        showSubmenuHandler?(currentSections)
    }

    func dismiss() {
        // Reset menu state when dismissing to ensure clean state on next open
        menuStack.removeAll()
        titleStack.removeAll()
        currentSections = []
        currentBackTitle = nil
        dismissHandler?()
    }
}

struct AgendadaFloatingMenuView: View {
    let sections: [AgendadaFloatingMenuSection]
    @ObservedObject var presenter: AgendadaFloatingMenuPresenter
    let width: CGFloat
    var showBackButton: Bool = true
    var backTitle: String?
    @State private var rootContentHeight: CGFloat = 0
    @State private var currentContentHeight: CGFloat = 0

    private let cornerRadius: CGFloat = 16

    init(
        sections: [AgendadaFloatingMenuSection],
        presenter: AgendadaFloatingMenuPresenter,
        width: CGFloat = 214,
        showBackButton: Bool = true,
        backTitle: String? = nil
    ) {
        self.sections = sections
        self.presenter = presenter
        self.width = width
        self.showBackButton = showBackButton
        self.backTitle = backTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button (shown in submenus)
            if showBackButton && presenter.isInSubmenu {
                backButton
                divider
            }

            // Menu items
            ForEach(Array(visibleSections.enumerated()), id: \.element.id) { index, section in
                if index > 0 || (showBackButton && presenter.isInSubmenu) {
                    divider
                }

                ForEach(section.items) { item in
                    AgendadaFloatingMenuRow(item: item, presenter: presenter)
                }
            }
        }
        .padding(.vertical, 5)
        .readFloatingMenuHeight { height in
            currentContentHeight = height
            if !presenter.isInSubmenu {
                rootContentHeight = height
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: width)
        .frame(height: reservedHeight == 0 ? nil : reservedHeight, alignment: .top)
        .agendadaGlassPopover(cornerRadius: cornerRadius)
        .onAppear {
            presenter.setRootSections(sections)
        }
    }

    private var visibleSections: [AgendadaFloatingMenuSection] {
        // When in a submenu, use the presenterʼs navigation stack.
        // At root level, always use the latest `sections` prop so that
        // filter state changes (e.g. calendar source toggles) are reflected.
        if presenter.isInSubmenu {
            return presenter.currentSections
        }
        return sections
    }

    private var reservedHeight: CGFloat {
        max(rootContentHeight, currentContentHeight)
    }

    private var backButton: some View {
        Button {
            presenter.goBack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AgendaColor.textMuted)
                Text(backTitle ?? presenter.currentBackTitle ?? "返回")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.09))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
    }
}

private struct AgendadaFloatingMenuRow: View {
    let item: AgendadaFloatingMenuItem
    let presenter: AgendadaFloatingMenuPresenter
    @State private var isHovering = false

    private var foregroundColor: Color {
        if item.isHeader { return Color(red: 0.08, green: 0.08, blue: 0.09) }
        if !item.isEnabled { return AgendaColor.textMuted }
        if item.role == .destructive { return .red }
        return Color(red: 0.08, green: 0.08, blue: 0.09)
    }

    var body: some View {
        Button {
            guard item.isEnabled, !item.isHeader else { return }
            item.action(presenter)
            if item.dismissesAfterAction {
                presenter.dismiss()
            }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                iconView
                    .frame(width: 18, height: 18)
                    .opacity(item.isEnabled ? 1 : 0.55)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.custom(item.isHeader ? "Avenir Next Demi Bold" : "Avenir Next", size: 13))
                        .foregroundStyle(foregroundColor)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(AgendaColor.textMuted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if item.showsSubmenuIndicator {
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AgendaColor.textMuted)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, item.subtitle == nil ? 5 : 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering && item.isEnabled && !item.isHeader ? Color.white.opacity(0.18) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.iconStyle {
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.role == .destructive ? .red : AgendaColor.amber)
        case .colorCircle(let color):
            if let color = color {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            } else {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AgendaColor.textMuted)
            }
        case .text(let text):
            Text(text)
                .font(.custom("Avenir Next Demi Bold", size: text.count > 2 ? 8 : 10))
                .foregroundStyle(AgendaColor.amber)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        case .empty:
            Color.clear
        }
    }
}
