import AgendadaCore
import SwiftUI

struct TimelineEventRow: View {
    let event: CalendarEvent
    let onOpenInCalendar: (() -> Void)?

    @State private var showPopover = false
    @State private var isHovered = false

    private var calendarColor: Color {
        Color(
            red: event.calendarColor.red,
            green: event.calendarColor.green,
            blue: event.calendarColor.blue,
            opacity: event.calendarColor.alpha
        )
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.startDate)
    }

    var body: some View {
        Button(action: { showPopover = true }) {
            HStack(spacing: 8) {
                if event.isAllDay {
                    // All-day: tinted label
                    Text("全天")
                        .font(.custom("Avenir Next", size: 11))
                        .foregroundStyle(calendarColor.opacity(0.8))
                        .frame(width: 38, alignment: .trailing)
                } else {
                    // Timed: show start time in readable gray
                    Text(timeString)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                        .frame(width: 38, alignment: .trailing)
                }

                // Calendar color bar — taller for events
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(calendarColor)
                    .frame(width: 3, height: 18)

                // Event title — deep readable text
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.20))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(event.calendarTitle)
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(calendarColor.opacity(0.7))
                        Text("·")
                            .font(.custom("Avenir Next", size: 9))
                            .foregroundStyle(AgendaColor.textMuted)
                        Text(event.accountTitle)
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(AgendaColor.textMuted)
                    }
                }

                Spacer()

                // "now" indicator for active events
                if !event.isAllDay && isCurrentlyActive {
                    Text("现在")
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(AgendaColor.amber)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                isHovered
                    ? Color(red: 0.95, green: 0.95, blue: 0.95)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            eventPopover
        }
    }

    private var isCurrentlyActive: Bool {
        let now = Date()
        return now >= event.startDate && now <= event.endDate
    }

    private var eventPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Event title
            Text(event.title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Time range
            if !event.isAllDay {
                Text(timeRangeString)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                Text("全天")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            Divider().padding(.horizontal, 8)

            // Open in Calendar
            if let onOpen = onOpenInCalendar {
                Button {
                    onOpen()
                    showPopover = false
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundStyle(AgendaColor.amber)
                            .frame(width: 18)
                        Text("在日历中打开")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 200)
        .padding(.vertical, 4)
    }

    private var timeRangeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }
}
