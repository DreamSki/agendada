import AgendadaCore
import AppKit
import SwiftUI

struct TimelineEventRow: View {
    let event: CalendarEvent
    let onOpenInCalendar: (() -> Void)?
    @Environment(ObservableLibraryStore.self) private var store

    @State private var showPopover = false
    @State private var isHovered = false
    @State private var menuPresenter = AgendadaFloatingMenuPresenter()
    @State private var menuDismissedAt = Date.distantPast

    private var calendarColor: Color {
        Color(
            red: event.calendarColor.red,
            green: event.calendarColor.green,
            blue: event.calendarColor.blue,
            opacity: event.calendarColor.alpha
        )
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: event.startDate)
    }

    private var relativeTimeString: String {
        let now = Date()
        let interval = event.startDate.timeIntervalSince(now)

        if interval < 0 {
            let pastInterval = abs(interval)
            if pastInterval < 60 { return "刚刚" }
            if pastInterval < 3600 { return "\(Int(pastInterval / 60))分钟前" }
            if pastInterval < 86400 { return "\(Int(pastInterval / 3600))小时前" }
            return timeString
        } else {
            if interval < 3600 { return "\(Int(interval / 60))分钟后" }
            if interval < 86400 {
                let hours = Int(interval / 3600)
                let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
                if minutes > 0 {
                    return "\(hours)小时\(minutes)分后"
                }
                return "\(hours)小时后"
            }
            return timeString
        }
    }

    private var isCurrentlyActive: Bool {
        let now = Date()
        return now >= event.startDate && now <= event.endDate
    }

    private var selectedNote: AgendadaCore.Note? {
        store.selectedNoteID.flatMap { store.note(withID: $0) }
    }

    var body: some View {
        Button(action: { toggleMenu() }) {
            HStack(spacing: 8) {
                // Spine dot — calendar color
                Circle()
                    .fill(calendarColor.opacity(0.8))
                    .frame(width: 4, height: 4)

                if event.isAllDay {
                    Text("全日")
                        .font(AgendaFont.panelCaption)
                        .foregroundStyle(AgendaColor.panelAllDayText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AgendaColor.panelAllDayBg))
                } else {
                    Text(timeString)
                        .font(AgendaFont.panelCaption)
                        .foregroundStyle(AgendaColor.panelSub)
                        .frame(width: 34, alignment: .leading)

                    if !isCurrentlyActive && abs(event.startDate.timeIntervalSince(Date())) < 86400 {
                        Text(relativeTimeString)
                            .font(AgendaFont.panelMicro)
                            .foregroundStyle(AgendaColor.panelHint)
                    }
                }

                Text(event.title)
                    .font(AgendaFont.panelBody)
                    .foregroundStyle(AgendaColor.panelBody)
                    .lineLimit(1)

                Spacer()

                if !event.isAllDay && isCurrentlyActive {
                    Text("现在")
                        .font(AgendaFont.panelCaption)
                        .foregroundStyle(AgendaColor.amber)
                }
            }
            .padding(.vertical, 5)
            .padding(.leading, AgendaSpacing.timelineRowIndent)
            .padding(.trailing, AgendaSpacing.panelPaddingH)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? AgendaColor.panelHover.opacity(0.6) : Color.clear)
                    .animation(.easeOut(duration: 0.2), value: isHovered)
            )
            .overlay(alignment: .leading) {
                if isHovered {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(calendarColor.opacity(0.7))
                        .frame(width: 2.5, height: 14)
                        .padding(.leading, AgendaSpacing.timelineHoverBarOffset)
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            showPopover = false
        }
        .onChange(of: showPopover) { _, isPresented in
            if !isPresented { menuDismissedAt = Date() }
        }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            AgendadaFloatingMenuView(sections: eventMenuSections(), presenter: menuPresenter, width: 330)
        }
    }

    // MARK: - Popover

    private func toggleMenu() {
        if showPopover {
            showPopover = false
            return
        }
        guard Date().timeIntervalSince(menuDismissedAt) > 0.18 else { return }

        menuPresenter.configure(
            dismiss: { showPopover = false },
            showSubmenu: { _ in }
        )
        showPopover = true
    }

    private func eventMenuSections() -> [AgendadaFloatingMenuSection] {
        let associatedNote = findAssociatedNote()
        var firstItems: [AgendadaFloatingMenuItem] = []

        if let note = associatedNote {
            firstItems.append(
                AgendadaFloatingMenuItem(
                    iconSystemName: "arrow.forward.circle",
                    title: "前往已关联的笔记",
                    subtitle: "跳转至与该日程关联的笔记「\(note.title)」"
                ) { _ in
                    store.selectNote(note.id)
                }
            )
        }

        firstItems.append(
            AgendadaFloatingMenuItem(
                iconSystemName: "doc.badge.plus",
                title: "新建与日程关联的新笔记",
                subtitle: "在项目中新建笔记，并将笔记关联到此日程"
            ) { _ in
                createNoteWithEvent()
            }
        )

        if let note = selectedNote {
            firstItems.append(
                AgendadaFloatingMenuItem(
                    iconSystemName: "link.circle",
                    title: "关联到所选笔记",
                    subtitle: "关联所选笔记「\(note.title)」到此日程"
                ) { _ in
                    associateNoteToEvent(note)
                }
            )
        }

        var eventItems: [AgendadaFloatingMenuItem] = [
            AgendadaFloatingMenuItem(
                iconSystemName: "calendar.badge.clock",
                title: "快捷重新安排",
                subtitle: "快捷更改日程「\(event.title)」的开始时间"
            ) { _ in },
            AgendadaFloatingMenuItem(
                iconSystemName: "pencil",
                title: "编辑",
                subtitle: "修改该日程的持续时间、标题、日期或其他属性"
            ) { _ in
                onOpenInCalendar?()
            }
        ]

        if associatedNote != nil {
            eventItems.append(
                AgendadaFloatingMenuItem(
                    iconSystemName: "link.badge.minus",
                    title: "取消关联笔记",
                    subtitle: "移除该日程与笔记的关联"
                ) { _ in }
            )
        }

        return [
            AgendadaFloatingMenuSection(items: firstItems),
            AgendadaFloatingMenuSection(items: eventItems),
            AgendadaFloatingMenuSection(items: [
                AgendadaFloatingMenuItem(
                    iconSystemName: "calendar",
                    title: "在「日历」中显示",
                    subtitle: "在「日历」App 中打开该日程"
                ) { _ in
                    onOpenInCalendar?()
                }
            ])
        ]
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
