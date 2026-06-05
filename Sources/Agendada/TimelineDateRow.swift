import AgendadaCore
import AppKit
import SwiftUI

struct TimelineDateRow: View {
    let date: Date
    let hasItems: Bool
    let notes: [ScheduledNoteInfo]
    let onNewNote: (() -> Void)?
    let onNewEvent: (() -> Void)?
    let onSelectNote: ((UUID) -> Void)?
    @Environment(ObservableLibraryStore.self) private var store

    @State private var showPopover = false
    @State private var showNotePopover = false
    @State private var isHovered = false
    @State private var dateMenuPresenter = AgendadaFloatingMenuPresenter()
    @State private var noteMenuPresenter = AgendadaFloatingMenuPresenter()
    @State private var dateMenuDismissedAt = Date.distantPast
    @State private var noteMenuDismissedAt = Date.distantPast

    private static let zhFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var dateLabel: String {
        let cal = Calendar.current
        let f = Self.zhFormatter
        if isToday {
            let weekday = f.weekdaySymbols[cal.component(.weekday, from: date) - 1]
            let day = cal.component(.day, from: date)
            return "今天，\(day) \(weekday)"
        } else {
            f.dateFormat = "d EEEE"
            return f.string(from: date)
        }
    }

    private var fullDateString: String {
        let f = Self.zhFormatter
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f.string(from: date)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Spine node — aligned to timeline spine
            Circle()
                .fill(isToday ? AgendaColor.amber : AgendaColor.panelHint.opacity(0.3))
                .frame(width: isToday ? 7 : 5, height: isToday ? 7 : 5)

            Button(action: { toggleDateMenu() }) {
                Text(dateLabel)
                    .font(isToday ? AgendaFont.panelBodyMedium : AgendaFont.panelBody)
                    .foregroundStyle(isToday ? AgendaColor.amber : AgendaColor.panelSub)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                AgendadaFloatingMenuView(sections: dateMenuSections(), presenter: dateMenuPresenter, width: 330)
            }

            if !notes.isEmpty {
                Button(action: { toggleNoteMenu() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10, weight: .regular))
                        Text("\(notes.count)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(AgendaColor.amber.opacity(0.5))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNotePopover, arrowEdge: .trailing) {
                    AgendadaFloatingMenuView(sections: noteMenuSections(), presenter: noteMenuPresenter, width: 220)
                }
            }

            Spacer()
        }
        .padding(.leading, AgendaSpacing.panelSpineLeading + AgendaSpacing.timelineDateDotLeadingAdjust)
        .padding(.trailing, AgendaSpacing.panelPaddingH)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? AgendaColor.panelHover.opacity(0.6) : Color.clear)
                .animation(.easeOut(duration: 0.2), value: isHovered)
        )
        .onHover { isHovered = $0 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            showPopover = false
            showNotePopover = false
        }
        .onChange(of: showPopover) { _, isPresented in
            if !isPresented { dateMenuDismissedAt = Date() }
        }
        .onChange(of: showNotePopover) { _, isPresented in
            if !isPresented { noteMenuDismissedAt = Date() }
        }
        // Today: left amber bar at spine
        .overlay(alignment: .leading) {
            if isToday {
                RoundedRectangle(cornerRadius: 1)
                    .fill(AgendaColor.amber)
                    .frame(width: 3, height: 16)
                    .padding(.leading, AgendaSpacing.timelineTodayBarOffset)
            }
        }
    }

    // MARK: - Note Popover

    private func toggleNoteMenu() {
        if showNotePopover {
            showNotePopover = false
            return
        }
        guard Date().timeIntervalSince(noteMenuDismissedAt) > 0.18 else { return }

        noteMenuPresenter.configure(
            dismiss: { showNotePopover = false },
            showSubmenu: { _ in }
        )
        showNotePopover = true
    }

    private func noteMenuSections() -> [AgendadaFloatingMenuSection] {
        [
            AgendadaFloatingMenuSection(items: notes.map { note in
                AgendadaFloatingMenuItem(
                    iconSystemName: "doc.text",
                    title: displayTitle(for: note)
                ) { _ in
                    onSelectNote?(note.id)
                }
            })
        ]
    }

    // MARK: - Date Popover

    private func toggleDateMenu() {
        if showPopover {
            showPopover = false
            return
        }
        guard Date().timeIntervalSince(dateMenuDismissedAt) > 0.18 else { return }

        dateMenuPresenter.configure(
            dismiss: { showPopover = false },
            showSubmenu: { _ in }
        )
        showPopover = true
    }

    private func dateMenuSections() -> [AgendadaFloatingMenuSection] {
        var sections: [AgendadaFloatingMenuSection] = []

        if !notes.isEmpty {
            let noteItems = notes.map { note in
                AgendadaFloatingMenuItem(
                    iconSystemName: notes.count == 1 ? "arrow.forward.circle" : "doc.text",
                    title: notes.count == 1 ? "前往“\(displayTitle(for: note))”" : displayTitle(for: note),
                    subtitle: notes.count == 1 ? "跳转到指定于这天的笔记" : "指定于 \(fullDateString)"
                ) { _ in
                    onSelectNote?(note.id)
                }
            }

            sections.append(
                AgendadaFloatingMenuSection(
                    items: noteItems
                )
            )
        }

        var createItems: [AgendadaFloatingMenuItem] = []
        if let onNew = onNewNote {
            createItems.append(
                AgendadaFloatingMenuItem(
                    iconSystemName: "doc.badge.plus",
                    title: "在这一天新建笔记",
                    subtitle: "新建一条笔记，指定日期 \(fullDateString)"
                ) { _ in
                    onNew()
                }
            )
        }

        if let onEvent = onNewEvent {
            createItems.append(
                AgendadaFloatingMenuItem(
                    iconSystemName: "calendar.badge.plus",
                    title: "在日历中打开这一天",
                    subtitle: fullDateString
                ) { _ in
                    onEvent()
                }
            )
        }

        if !createItems.isEmpty {
            sections.append(AgendadaFloatingMenuSection(items: createItems))
        }

        return sections
    }

    private func displayTitle(for note: ScheduledNoteInfo) -> String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "无标题笔记" : trimmed
    }

}
