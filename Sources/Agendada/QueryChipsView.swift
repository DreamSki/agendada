import AgendadaCore
import SwiftUI

// MARK: - Query Chips

/// Renders a horizontal row of read-only query chips parsed from search text.
struct QueryChipsRow: View {
    let chips: [QueryChip]

    var body: some View {
        if chips.isEmpty { EmptyView() }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips) { chip in
                    QueryChipBadge(chip: chip)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

/// A single read-only chip badge showing a parsed search token.
struct QueryChipBadge: View {
    let chip: QueryChip

    private var chipColor: Color {
        switch chip.chipType {
        case .tag:         return AgendaColor.tagCyan
        case .person:      return AgendaColor.chipBlue
        case .status:      return Color.orange
        case .has:         return Color.teal
        case .is:           return Color.purple
        case .date:        return AgendaColor.amber
        case .keyword:     return AgendaColor.textMuted
        case .notKeyword:  return Color.red
        }
    }

    var body: some View {
        Text(chip.label)
            .font(.custom("Avenir Next Medium", size: 10))
            .foregroundStyle(chipColor)
            .strikethrough(chip.chipType == .notKeyword, color: chipColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(chipColor.opacity(0.12), in: Capsule())
            .overlay(
                Capsule().stroke(chipColor.opacity(0.2), lineWidth: 0.5)
            )
    }
}
