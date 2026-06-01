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
            // Spine dot — calendar color
            Circle()
                .fill(calendarColor.opacity(0.8))
                .frame(width: 4, height: 4)

            // Checkbox
            Button(action: toggleCompletion) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            reminder.isCompleted ? calendarColor : AgendaColor.panelSub.opacity(0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: 16, height: 16)

                    if reminder.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(calendarColor)
                    }
                }
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(reminder.isCompleted ? "标记为未完成" : "标记为已完成")

            // Title
            Text(reminder.title)
                .font(AgendaFont.panelBody)
                .foregroundStyle(reminder.isCompleted ? AgendaColor.panelHint : AgendaColor.panelBody)
                .strikethrough(reminder.isCompleted, color: AgendaColor.panelHint)
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture { showPopover = true }

            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.leading, AgendaSpacing.timelineRowIndent)
        .padding(.trailing, AgendaSpacing.panelPaddingH)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? AgendaColor.panelHover.opacity(0.6) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isHovered {
                RoundedRectangle(cornerRadius: 1)
                    .fill(calendarColor.opacity(0.7))
                    .frame(width: 2.5, height: 14)
                    .padding(.leading, AgendaSpacing.timelineHoverBarOffset)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            reminderPopover
        }
    }

    private func toggleCompletion() {
        Task {
            await calendarStore.toggleReminder(reminder.id)
        }
    }

    // MARK: - Popover

    private var reminderPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            ContextMenuItem(
                icon: "doc.badge.plus",
                title: "新建带有提醒事项的笔记",
                subtitle: "在项目中新建包含此提醒事项的笔记",
                action: {
                    _ = store.addNoteReturningID()
                    showPopover = false
                }
            )

            if let note = selectedNote {
                ContextMenuItem(
                    icon: "plus.circle",
                    title: "添加至所选笔记",
                    subtitle: "将该提醒事项添加至所选笔记「\(note.title)」",
                    action: { showPopover = false }
                )
            }

            ContextMenuDivider()

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
                icon: "pencil",
                title: "编辑",
                subtitle: "修改该提醒事项的标题、截止日期或其他属性",
                action: {
                    calendarStore.openReminderInReminders(reminder.id)
                    showPopover = false
                }
            )

            ContextMenuDivider()

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
}
