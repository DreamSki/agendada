import AgendadaCore
import SwiftUI

struct TimelineReminderRow: View {
    let reminder: CalendarReminder
    @Environment(CalendarStore.self) private var calendarStore

    @State private var showPopover = false
    @State private var isHovered = false
    @State private var localCompleted: Bool

    init(reminder: CalendarReminder) {
        self.reminder = reminder
        self._localCompleted = State(initialValue: reminder.isCompleted)
    }

    private var calendarColor: Color {
        Color(
            red: reminder.calendarColor.red,
            green: reminder.calendarColor.green,
            blue: reminder.calendarColor.blue,
            opacity: reminder.calendarColor.alpha
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            // Hollow circle checkbox — visually distinct from events
            Button {
                toggleCompletion()
            } label: {
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(
                            localCompleted ? AgendaColor.amber : Color(red: 0.65, green: 0.65, blue: 0.65),
                            lineWidth: 1.5
                        )
                        .frame(width: 16, height: 16)

                    // Inner checkmark when completed
                    if localCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AgendaColor.amber)
                    }
                }
                .frame(width: 20)
            }
            .buttonStyle(.plain)
            .help(localCompleted ? "标记为未完成" : "标记为已完成")

            // Title — readable dark text
            Text(reminder.title)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(localCompleted ? Color(red: 0.70, green: 0.70, blue: 0.70) : Color(red: 0.20, green: 0.20, blue: 0.20))
                .strikethrough(localCompleted, color: Color(red: 0.70, green: 0.70, blue: 0.70))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            isHovered
                ? Color(red: 0.95, green: 0.95, blue: 0.95)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            showPopover = true
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            reminderPopover
        }
    }

    private func toggleCompletion() {
        localCompleted.toggle()
        Task {
            await calendarStore.toggleReminder(reminder.id)
        }
    }

    private var reminderPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text(reminder.title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 8)

            // Mark complete / incomplete
            Button {
                toggleCompletion()
                showPopover = false
            } label: {
                HStack {
                    Image(systemName: localCompleted ? "arrow.uturn.backward" : "checkmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(AgendaColor.amber)
                        .frame(width: 18)
                    Text(localCompleted ? "标记为未完成" : "标记完成")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal, 8)

            // Open in Reminders
            Button {
                calendarStore.openReminderInReminders(reminder.id)
                showPopover = false
            } label: {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13))
                        .foregroundStyle(AgendaColor.amber)
                        .frame(width: 18)
                    Text("在提醒事项中打开")
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
        .frame(width: 200)
        .padding(.vertical, 4)
    }
}
