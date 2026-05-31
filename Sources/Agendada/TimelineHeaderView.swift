import AgendadaCore
import SwiftUI

struct TimelineHeaderView: View {
    @Environment(CalendarStore.self) private var calendarStore
    let onScrollUp: () -> Void
    let onScrollDown: () -> Void

    @State private var showFilter = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)

            Text(calendarStore.visibleMonth)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.primary)

            // Filter button
            Button(action: { showFilter = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(calendarStore.enabledSourceIDs.isEmpty ? .secondary : AgendaColor.amber)
            }
            .buttonStyle(.plain)
            .help("筛选日历来源")
            .popover(isPresented: $showFilter, arrowEdge: .bottom) {
                filterPopover
            }

            Spacer()

            Button(action: onScrollUp) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("向上滚动一页")

            Button(action: onScrollDown) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("向下滚动一页")
        }
    }

    // MARK: - Filter Popover

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Select all
            Button {
                calendarStore.enableAllSources()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: calendarStore.isAllSourcesEnabled ? "checkmark.square" : "square")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text("全部显示")
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

            // Calendar sources
            let eventSources = calendarStore.calendarSources.filter { $0.type == .event }
            if !eventSources.isEmpty {
                sectionLabel("日历")
                ForEach(eventSources) { source in
                    sourceToggle(source)
                }
                Divider().padding(.horizontal, 8)
            }

            let reminderSources = calendarStore.calendarSources.filter { $0.type == .reminder }
            if !reminderSources.isEmpty {
                sectionLabel("提醒事项")
                ForEach(reminderSources) { source in
                    sourceToggle(source)
                }
            }
        }
        .frame(width: 200)
        .padding(.vertical, 4)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.custom("Avenir Next Medium", size: 11))
            .foregroundStyle(AgendaColor.textMuted)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    private func sourceToggle(_ source: CalendarSource) -> some View {
        let isEnabled = calendarStore.enabledSourceIDs.isEmpty || calendarStore.enabledSourceIDs.contains(source.id)
        return Button {
            calendarStore.toggleSource(source.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.square" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                // Color dot
                Circle()
                    .fill(Color(
                        red: source.color.red,
                        green: source.color.green,
                        blue: source.color.blue,
                        opacity: source.color.alpha
                    ))
                    .frame(width: 8, height: 8)

                Text(source.title)
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
