import SwiftUI

/// A reusable collapsible section for the right panel.
/// Shows an icon + title + summary when collapsed.
/// When expanded, optionally shows a custom label (e.g. month navigation) replacing the title.
struct CollapsibleSection<Content: View, ExpandedLabel: View>: View {
    let icon: String
    let title: String
    let summary: String?
    var showTitleWhenExpanded: Bool = false
    @Binding var isExpanded: Bool
    var onIconTap: (() -> Void)?
    @ViewBuilder let expandedLabel: () -> ExpandedLabel
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                // Icon — standalone button when onIconTap is provided
                if let onIconTap {
                    Button(action: onIconTap) {
                        iconView
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        iconView
                    }
                    .buttonStyle(.plain)
                }

                // Title / expanded label — tapping toggles collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isExpanded && !showTitleWhenExpanded {
                            expandedLabel()
                        } else {
                            Text(title)
                                .font(AgendaFont.panelSectionTitle)
                                .foregroundStyle(AgendaColor.panelHeading)

                            if let summary, !isExpanded {
                                Text("· \(summary)")
                                    .font(AgendaFont.panelCaption)
                                    .foregroundStyle(AgendaColor.panelSub)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AgendaColor.panelHint)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AgendaSpacing.panelPaddingH)
            .frame(minHeight: AgendaSpacing.panelSectionHeaderH)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? AgendaColor.panelHover.opacity(0.5) : Color.clear)
            )
            .onHover { isHovered = $0 }

            // Expanded content
            if isExpanded {
                content()
            }

            // Divider
            Rectangle()
                .fill(AgendaColor.panelWarmDivider)
                .frame(height: 1)
                .padding(.horizontal, AgendaSpacing.panelPaddingH)
        }
        .padding(.bottom, 6)
    }

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .light))
            .foregroundStyle(AgendaColor.amber)
            .frame(width: 14)
    }
}

// MARK: - Convenience init without expanded label

extension CollapsibleSection where ExpandedLabel == EmptyView {
    init(
        icon: String,
        title: String,
        summary: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.summary = summary
        self.showTitleWhenExpanded = true
        self._isExpanded = isExpanded
        self.onIconTap = nil
        self.expandedLabel = { EmptyView() }
        self.content = content
    }
}
