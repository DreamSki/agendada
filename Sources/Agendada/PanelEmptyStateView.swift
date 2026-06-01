import SwiftUI

/// Reusable empty state view for the right panel.
/// Consistent icon size, spacing, and typography across all empty states.
struct PanelEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AgendaColor.panelHint.opacity(0.6))

            Text(title)
                .font(AgendaFont.panelCaption)
                .fontWeight(.medium)
                .foregroundStyle(AgendaColor.panelHint)

            if let subtitle {
                Text(subtitle)
                    .font(AgendaFont.panelMicro)
                    .foregroundStyle(AgendaColor.panelSub)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 28)
        .padding(.horizontal, AgendaSpacing.panelPaddingH)
    }
}
