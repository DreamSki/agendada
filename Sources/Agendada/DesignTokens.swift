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

    // Right panel — warm off-white #FAF9F6
    static let panelBg = Color(red: 0.980, green: 0.976, blue: 0.965)

    // Panel text hierarchy
    static let panelHeading = Color(red: 0.125, green: 0.129, blue: 0.141)    // #202124
    static let panelBody = Color(red: 0.184, green: 0.204, blue: 0.216)       // #2F3437
    static let panelSub = Color(red: 0.541, green: 0.561, blue: 0.596)        // #8A8F98
    static let panelHint = Color(red: 0.710, green: 0.722, blue: 0.745)       // #B5B8BE

    // Panel warm divider #EEE8DF
    static let panelWarmDivider = Color(red: 0.933, green: 0.910, blue: 0.875)

    // Panel all-day event tag
    static let panelAllDayBg = Color(red: 0.906, green: 0.969, blue: 0.925)    // #E7F7EC
    static let panelAllDayText = Color(red: 0.149, green: 0.635, blue: 0.412)  // #26A269

    // Panel hover #FFF7EC
    static let panelHover = Color(red: 1.0, green: 0.969, blue: 0.925)

    // Panel icon gray (for section icons)
    static let panelIconGray = Color(red: 0.604, green: 0.604, blue: 0.604)   // #9A9A9A

    // Panel timeline spine
    static let panelSpine = panelWarmDivider.opacity(0.6)

    // Text (legacy — used by sidebar and other components)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textMuted = Color(red: 0.557, green: 0.557, blue: 0.576)       // #8E8E93
    static let textBody = Color(red: 0.20, green: 0.20, blue: 0.20)           // #333333

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

    // Panel — 5-level type scale
    static let panelHeader: Font = .custom("Avenir Next Demi Bold", size: 15)
    static let panelSectionTitle: Font = .custom("Avenir Next Medium", size: 13)
    static let panelBody: Font = .custom("Avenir Next", size: 12)
    static let panelBodyMedium: Font = .custom("Avenir Next Medium", size: 12)
    static let panelCaption: Font = .custom("Avenir Next", size: 10)
    static let panelMicro: Font = .custom("Avenir Next", size: 9)

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

    // Panel (compact sidebar layout)
    static let panelPaddingH: CGFloat = 22
    static let panelModuleSpacing: CGFloat = 24
    static let panelCardRadius: CGFloat = 18
    static let panelSectionRadius: CGFloat = 16
    static let panelCardPadding: CGFloat = 18

    // Panel — collapsible sections
    static let panelSectionHeaderH: CGFloat = 28
    static let panelSpineLeading: CGFloat = 14
    static let panelLevel1: CGFloat = 40   // Event/reminder indent = panelPaddingH + 18

    // Panel — timeline specific
    static let timelineRowIndent: CGFloat = 30        // Event/reminder row indent from left edge
    static let timelineTodayTopSpacing: CGFloat = 10 // Extra top spacing for today row (vs 6 for normal days)
    static let timelineHoverBarOffset: CGFloat = 4   // Hover bar offset from row left edge
    static let timelineDateDotLeadingAdjust: CGFloat = -3
    static let timelineTodayBarOffset: CGFloat = -2  // Today amber bar offset from spine

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

// MARK: - Category Color → SwiftUI Color

import AgendadaCore

extension CategoryColor {
    var sidebarTint: Color {
        switch self {
        case .orange:   Color(red: 1.0, green: 0.42, blue: 0.0)
        case .tan:      Color(red: 0.85, green: 0.62, blue: 0.38)
        case .purple:   Color(red: 0.65, green: 0.43, blue: 0.83)
        case .green:    Color(red: 0.42, green: 0.80, blue: 0.44)
        case .pink:     Color(red: 0.92, green: 0.36, blue: 0.82)
        case .gray:     Color(red: 0.67, green: 0.71, blue: 0.75)
        case .red:      Color(red: 1.0, green: 0.42, blue: 0.42)
        case .blue:     Color(red: 0.49, green: 0.72, blue: 1.0)
        case .olive:    Color(red: 0.61, green: 0.68, blue: 0.48)
        case .gold:     Color(red: 0.76, green: 0.65, blue: 0.26)
        case .teal:     Color(red: 0.26, green: 0.74, blue: 0.74)
        case .indigo:   Color(red: 0.45, green: 0.47, blue: 0.60)
        case .burgundy: Color(red: 0.54, green: 0.21, blue: 0.17)
        }
    }
}
