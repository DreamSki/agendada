import AgendadaCore
import SwiftUI

struct TimelineReminderRow: View {
    let reminder: CalendarReminder
    @Environment(CalendarStore.self) private var calendarStore
    @Environment(ObservableLibraryStore.self) private var store

    @State private var showPopover = false
    @State private var isHovered = false

    init(reminder: CalendarReminder) {
        self.reminder = reminder
    }

    private var calendarColor: Color {
        Color(
            red: reminder.calendarColor.red,
            green: reminder.calendarColor.green,
            blue: reminder.calendarColor.blue,
            opacity: reminder.calendarColor.alpha
        )
    }

    private var selectedNote: AgendadaCore.Note? {
        store.selectedNoteID.flatMap { store.note(withID: $0) }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Hollow circle checkbox
            Button(action: toggleCompletion) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            reminder.isCompleted ? AgendaColor.amber : Color(red: 0.65, green: 0.65, blue: 0.65),
                            lineWidth: 1.5
                        )
                        .frame(width: 16, height: 16)

                    if reminder.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AgendaColor.amber)
                    }
                }
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(reminder.isCompleted ? "标记为未完成" : "标记为已完成")

            // Title - clickable to show popover
            Text(reminder.title)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(reminder.isCompleted ? Color(red: 0.70, green: 0.70, blue: 0.70) : Color(red: 0.20, green: 0.20, blue: 0.20))
                .strikethrough(reminder.isCompleted, color: Color(red: 0.70, green: 0.70, blue: 0.70))
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture {
                    showPopover = true
                }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            isHovered
                ? Color(red: 0.95, green: 0.95, blue: 0.95)
                : Color.clear
        )
        .onHover { isHovered = $0 }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            reminderPopover
        }
    }

    private func toggleCompletion() {
        Task {
            await calendarStore.toggleReminder(reminder.id)
        }
    }

    private var reminderPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section 1: Note Association
            ContextMenuItem(
                icon: "doc.badge.plus",
                title: "新建带有提醒事项的笔记",
                subtitle: "在项目中新建包含此提醒事项的笔记",
                action: {
                    createNoteWithReminder()
                    showPopover = false
                }
            )

            if let note = selectedNote {
                ContextMenuItem(
                    icon: "plus.circle",
                    title: "添加至所选笔记",
                    subtitle: "将该提醒事项添加至所选笔记「\(note.title)」",
                    action: {
                        addReminderToNote(note)
                        showPopover = false
                    }
                )
            }

            ContextMenuDivider()

            // Section 2: Reminder Actions
            ContextMenuItem(
                icon: reminder.isCompleted ? "arrow.uturn.backward" : "checkmark.circle",
                title: reminder.isCompleted ? "标记为未完成" : "标记为已完成",
                subtitle: reminder.isCompleted ? "重新显示此提醒事项" : "已完成的提醒事项将不再出现于时间轴上",
                action: {
                    toggleCompletion()
                    showPopover = false
                }
            )

            ContextMenuItem(
                icon: "calendar.badge.clock",
                title: "快捷重新安排",
                subtitle: "快捷地修改「\(reminder.title)」的截止日期",
                action: {
                    // TODO: Implement quick reschedule
                    showPopover = false
                }
            )

            ContextMenuItem(
                icon: "pencil",
                title: "编辑",
                subtitle: "修改该提醒事项的标题、截止日期或其他属性",
                action: {
                    calendarStore.openReminderInReminders(reminder.id)
                    showPopover = false
                }
            )

            ContextMenuDivider()

            // Section 3: Jump
            ContextMenuItem(
                icon: "list.bullet.rectangle",
                title: "在「提醒事项」中显示",
                subtitle: "打开「提醒事项」App 并跳转到「\(reminder.title)」",
                action: {
                    calendarStore.openReminderInReminders(reminder.id)
                    showPopover = false
                }
            )
        }
        .frame(width: 360)
        .padding(.vertical, 4)
    }

    private func createNoteWithReminder() {
        let noteID = store.addNoteReturningID()
        // Add reminder content to note
        if let note = store.note(withID: noteID) {
            let content = "# 提醒事项\n\n\(reminder.title)"
            // TODO: Need to add a method to update note content
        }
    }

    private func addReminderToNote(_ note: AgendadaCore.Note) {
        // TODO: Add reminder reference/content to note
    }
}
