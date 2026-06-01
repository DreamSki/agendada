import SwiftUI

/// A reusable context menu item with icon, title, and subtitle
struct ContextMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(AgendaColor.amber)
                    .frame(width: 22, alignment: .center)

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AgendaColor.panelHeading)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AgendaColor.panelSub)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A divider for context menu sections
struct ContextMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.9, green: 0.9, blue: 0.9))
            .frame(height: 1)
            .padding(.horizontal, 24)
    }
}
