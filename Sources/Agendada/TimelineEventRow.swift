import AgendadaCore
import SwiftUI

struct TimelineEventRow: View {
    let event: CalendarEvent
    let onOpenInCalendar: (() -> Void)?
    @Environment(ObservableLibraryStore.self) private var store

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

    private var selectedNote: AgendadaCore.Note? {
        store.selectedNoteID.flatMap { store.note(withID: $0) }
    }

    var body: some View {
        Button(action: { showPopover = true }) {
            HStack(spacing: 8) {
                if event.isAllDay {
                    Text("全天")
                        .font(.custom("Avenir Next", size: 11))
                        .foregroundStyle(calendarColor.opacity(0.8))
                        .frame(width: 38, alignment: .trailing)
                } else {
                    Text(timeString)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                        .frame(width: 38, alignment: .trailing)
                }

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(calendarColor)
                    .frame(width: 3, height: 18)

                Text(event.title)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.20))
                    .lineLimit(1)

                Spacer()

                if !event.isAllDay && isCurrentlyActive {
                    Text("现在")
                        .font(.custom("Avenir Next", size: 11))
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
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            eventPopover
        }
    }

    private var isCurrentlyActive: Bool {
        let now = Date()
        return now >= event.startDate && now <= event.endDate
    }

    private var eventPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            let associatedNote = findAssociatedNote()

            if let note = associatedNote {
                ContextMenuItem(
                    icon: "arrow.forward.circle",
                    title: "前往已关联的笔记",
                    subtitle: "跳转至与该日程关联的笔记「\(note.title)」",
                    action: {
                        store.selectNote(note.id)
                        showPopover = false
                    }
                )
            }

            ContextMenuItem(
                icon: "doc.badge.plus",
                title: "新建与日程关联的新笔记",
                subtitle: "在项目中新建笔记，并将笔记关联到此日程",
                action: {
                    createNoteWithEvent()
                    showPopover = false
                }
            )

            if let note = selectedNote {
                ContextMenuItem(
                    icon: "link.circle",
                    title: "关联到所选笔记",
                    subtitle: "关联所选笔记「\(note.title)」到此日程",
                    action: {
                        associateNoteToEvent(note)
                        showPopover = false
                    }
                )
            }

            ContextMenuDivider()

            ContextMenuItem(
                icon: "calendar.badge.clock",
                title: "快捷重新安排",
                subtitle: "快捷更改日程「\(event.title)」的开始时间",
                action: { showPopover = false }
            )

            ContextMenuItem(
                icon: "pencil",
                title: "编辑",
                subtitle: "修改该日程的持续时间、标题、日期或其他属性",
                action: {
                    onOpenInCalendar?()
                    showPopover = false
                }
            )

            if associatedNote != nil {
                ContextMenuItem(
                    icon: "link.badge.minus",
                    title: "取消关联笔记",
                    subtitle: "移除该日程与笔记的关联",
                    action: { showPopover = false }
                )
            }

            ContextMenuDivider()

            ContextMenuItem(
                icon: "calendar",
                title: "在「日历」中显示",
                subtitle: "在「日历」App 中打开该日程",
                action: {
                    onOpenInCalendar?()
                    showPopover = false
                }
            )
        }
        .frame(width: 360)
        .padding(.vertical, 4)
    }

    private func findAssociatedNote() -> AgendadaCore.Note? {
        let cal = Calendar.current
        let eventDay = cal.startOfDay(for: event.startDate)
        return store.filteredNotes().first { note in
            guard let scheduled = note.scheduledDate else { return false }
            let noteDay = cal.startOfDay(for: scheduled)
            return noteDay == eventDay && note.title.contains(event.title)
        }
    }

    private func createNoteWithEvent() {
        _ = store.note(withID: store.addNoteReturningID())
    }

    private func associateNoteToEvent(_ note: AgendadaCore.Note) {
        // TODO
    }
}
