import AgendadaCore
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

            Button(action: { showPopover = true }) {
                Text(dateLabel)
                    .font(isToday ? AgendaFont.panelBodyMedium : AgendaFont.panelBody)
                    .foregroundStyle(isToday ? AgendaColor.amber : AgendaColor.panelSub)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                datePopover
            }

            if !notes.isEmpty {
                Button(action: { showNotePopover = true }) {
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
                    notePopover
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

    private var notePopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("排期笔记")
                .font(AgendaFont.panelCaption)
                .foregroundStyle(AgendaColor.textMuted)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(notes) { note in
                Button {
                    onSelectNote?(note.id)
                    showNotePopover = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12))
                            .foregroundStyle(AgendaColor.amber)
                            .frame(width: 16)

                        Text(note.title)
                            .font(AgendaFont.panelBody)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 200)
        .padding(.vertical, 4)
    }

    // MARK: - Date Popover

    private var datePopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !notes.isEmpty {
                ContextMenuItem(
                    icon: "arrow.forward.circle",
                    title: "前往被指定的笔记",
                    subtitle: "跳转到指定于这天的笔记",
                    action: {
                        if let firstNote = notes.first {
                            onSelectNote?(firstNote.id)
                        }
                        showPopover = false
                    }
                )
                ContextMenuDivider()
            }

            if let onNew = onNewNote {
                ContextMenuItem(
                    icon: "doc.badge.plus",
                    title: "在这一天新建笔记",
                    subtitle: "新建一条笔记，指定日期 \(fullDateString)",
                    action: {
                        onNew()
                        showPopover = false
                    }
                )
            }

            if let onNew = onNewEvent {
                ContextMenuItem(
                    icon: "calendar.badge.plus",
                    title: "新建日程",
                    subtitle: "在「日历」App 中添加 \(fullDateString) 的日程",
                    action: {
                        onNew()
                        showPopover = false
                    }
                )
            }
        }
        .frame(width: 360)
        .padding(.vertical, 4)
    }
}
