import SwiftUI

enum AgendaColor {
    // Accent — warm amber #F5A623
    static let amber = Color(red: 0.961, green: 0.651, blue: 0.137)
    static let amberLight = Color(red: 0.98, green: 0.76, blue: 0.20)
    static let amberBorder = Color(red: 0.94, green: 0.62, blue: 0.04)

    // Card active state — #FFFCF5, border #F5E5C0, handle #F0D59B
    static let cardActiveFill = Color(red: 0.992, green: 0.984, blue: 0.973)
    static let cardActiveBorder = Color(red: 0.961, green: 0.898, blue: 0.753)
    static let cardDragHandle = Color(red: 0.941, green: 0.835, blue: 0.608)

    // Blue for @mention chips
    static let chipBlue = Color(red: 0.30, green: 0.64, blue: 0.75)
    static let chipBlueText = Color.white

    // Cyan for #tags
    static let tagCyan = Color(red: 0.26, green: 0.69, blue: 0.75)

    // Canvas — integration card bg #F2F2F2
    static let canvasGray = Color(red: 0.949, green: 0.949, blue: 0.949)

    // Card
    static let cardWhite = Color.white
    static let cardBorder = Color(red: 0.89, green: 0.89, blue: 0.87)
    static let cardShadow = Color.black.opacity(0.05)

    // Sidebar — bg #F5F5F7, selected #E3E3E3, hover #EAEAEA, border #E5E5E5
    static let sidebarBg = Color(red: 0.961, green: 0.961, blue: 0.969)
    static let sidebarSelectedBg = Color(red: 0.890, green: 0.890, blue: 0.890)
    static let sidebarHoverBg = Color(red: 0.918, green: 0.918, blue: 0.918)
    static let sidebarBorder = Color(red: 0.898, green: 0.898, blue: 0.898)

    // Right panel — bg #FAFAFA
    static let panelBg = Color(red: 0.980, green: 0.980, blue: 0.980)

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textMuted = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
    static let textBody = Color(red: 0.20, green: 0.20, blue: 0.20)    // #333333

    // Dividers
    static let divider = Color.primary.opacity(0.08)

    // Toolbar capsule — #EEEEEE
    static let toolbarCapsuleBg = Color(red: 0.933, green: 0.933, blue: 0.933)
}

enum AgendaFont {
    // Header breadcrumb — Avenir Next
    static let breadcrumbCategory: Font = .custom("Avenir Next", size: 20)
    static let breadcrumbTitle: Font = .custom("Avenir Next Medium", size: 20)
    static let breadcrumbContext: Font = .custom("Avenir Next", size: 16)

    // Note cards — 20pt Avenir Next Medium title
    static let cardTitle: Font = .custom("Avenir Next", size: 20)
    static let cardTitleUnselected: Font = .custom("Avenir Next", size: 20)
    static let cardBody: Font = .custom("Avenir Next", size: 14)
    static let cardBodyCompact: Font = .custom("Avenir Next", size: 13)
    static let cardMeta: Font = .custom("Avenir Next", size: 13)

    // Metadata inline
    static let metaLabel: Font = .custom("Avenir Next Medium", size: 13)
    static let chipLabel: Font = .custom("Avenir Next Demi Bold", size: 13)

    // Sidebar
    static let sidebarSection: Font = .custom("Avenir Next Demi Bold", size: 11)
    static let sidebarItem: Font = .custom("Avenir Next", size: 13)
    static let sidebarItemActive: Font = .custom("Avenir Next Medium", size: 13)

    // Panel
    static let panelSectionHeader: Font = .custom("Avenir Next Medium", size: 12)
    static let panelTitle: Font = .custom("Avenir Next Medium", size: 13)
    static let panelBody: Font = .custom("Avenir Next", size: 13)
    static let panelSubtitle: Font = .custom("Avenir Next", size: 11)

    // Date chips
    static let dateChip: Font = .custom("Avenir Next Medium", size: 13)
    static let dateUnselected: Font = .custom("Avenir Next", size: 13)
}

enum AgendaSpacing {
    // Card
    static let cardPaddingH: CGFloat = 20
    static let cardPaddingV: CGFloat = 16
    static let cardRadius: CGFloat = 12
    static let cardGap: CGFloat = 20

    // Content area
    static let contentPaddingH: CGFloat = 32

    // Sidebar
    static let sidebarItemH: CGFloat = 32
    static let sidebarItemRadius: CGFloat = 6
    static let sidebarPaddingH: CGFloat = 13
    static let sidebarIconCol: CGFloat = 24

    // Panel
    static let panelPaddingH: CGFloat = 16
    static let panelPaddingTop: CGFloat = 16

    // Body text — leading-relaxed ≈ 1.625 line height
    static let bodyLineSpacing: CGFloat = 4
}

enum AgendaIcon {
    static let sidebar: CGFloat = 16
    static let toolbar: CGFloat = 18
    static let card: CGFloat = 16
    static let panel: CGFloat = 14
    static let chip: CGFloat = 13
}

enum AgendaShadow {
    static let cardY: CGFloat = 2
    static let cardRadius: CGFloat = 6
    static let toolbarY: CGFloat = 4
    static let toolbarRadius: CGFloat = 10
}
