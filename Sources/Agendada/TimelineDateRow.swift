import AgendadaCore
import SwiftUI

struct TimelineDateRow: View {
    let date: Date
    let hasItems: Bool
    let notes: [ScheduledNoteInfo]
    let onNewNote: (() -> Void)?
    let onNewEvent: (() -> Void)?
    let onSelectNote: ((UUID) -> Void)?

    @State private var showPopover = false
    @State private var showNotePopover = false
    @State private var isHovered = false

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var dateLabel: String {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if isToday {
            let weekday = formatter.weekdaySymbols[cal.component(.weekday, from: date) - 1]
            let day = cal.component(.day, from: date)
            return "今天，\(day) \(weekday)"
        } else {
            formatter.dateFormat = "d EEEE"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Today indicator — small solid amber dot
            Circle()
                .fill(isToday ? AgendaColor.amber : Color.clear)
                .frame(width: 6, height: 6)

            // Date label — click for date actions
            Button(action: { showPopover = true }) {
                Text(dateLabel)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(isToday ? AgendaColor.amber : Color(red: 0.35, green: 0.35, blue: 0.35))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                datePopover
            }

            // Note indicator button — only if there are scheduled notes
            if !notes.isEmpty {
                Button(action: { showNotePopover = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11, weight: .regular))
                        Text("\(notes.count)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(isHovered ? AgendaColor.amber.opacity(0.8) : AgendaColor.amber.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("\(notes.count) 条排期笔记")
                .popover(isPresented: $showNotePopover, arrowEdge: .bottom) {
                    notePopover
                }
            }

            Spacer()

            if hasItems {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary.opacity(isHovered ? 0.7 : 0.25))
            }
        }
        .padding(.leading, isToday ? 13 : 16)
        .padding(.trailing, 16)
        .padding(.top, 14)
        .padding(.bottom, 5)
        .overlay(alignment: .leading) {
            if isToday {
                RoundedRectangle(cornerRadius: 1)
                    .fill(AgendaColor.amber)
                    .frame(width: 2.5, height: 14)
                    .padding(.leading, 4)
            }
        }
        .onHover { isHovered = $0 }
    }

    // MARK: - Note Popover

    private var notePopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("排期笔记")
                .font(.custom("Avenir Next", size: 12))
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
                            .font(.custom("Avenir Next", size: 13))
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
        VStack(alignment: .leading, spacing: 0) {
            if let onNewNote {
                Button {
                    onNewNote()
                    showPopover = false
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 13))
                            .foregroundStyle(AgendaColor.amber)
                            .frame(width: 18)
                        Text("在这一天新建笔记")
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

            Divider().padding(.horizontal, 8)

            if let onNewEvent {
                Button {
                    onNewEvent()
                    showPopover = false
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 13))
                            .foregroundStyle(AgendaColor.amber)
                            .frame(width: 18)
                        Text("新建日程")
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
        .frame(width: 180)
        .padding(.vertical, 4)
    }
}
