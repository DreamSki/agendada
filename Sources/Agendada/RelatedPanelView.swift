import AgendadaCore
import SwiftUI

struct RelatedPanelView: View {
    @Environment(ObservableLibraryStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    timelineSection
                        .padding(.top, 16)

                    integrationCard

                    recentSection

                    relatedSection
                }
                .padding(.horizontal, AgendaSpacing.panelPaddingH)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .background(AgendaColor.panelBg)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AgendaColor.divider)
                .frame(width: 1)
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.primary)
                    Text("时间轴")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "mountain.2")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.25))
            }

            // Selected note date info
            if let note = store.selectedNote {
                timelineNoteInfo(note)
            } else {
                timelineOverviewInfo
            }
        }
        .padding(.bottom, 4)
    }

    private func timelineNoteInfo(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = note.scheduledDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(AgendaColor.amber)
                    Text(dateLabel(for: date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AgendaColor.amber)
                }
            } else {
                Text("未指定日期")
                    .font(.system(size: 12))
                    .foregroundStyle(AgendaColor.textMuted)
            }

            if note.checklistSummary.totalCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 10))
                    Text(note.checklistSummary.title)
                        .font(.system(size: 12))
                }
                .foregroundStyle(AgendaColor.textMuted)
            }
        }
    }

    private var timelineOverviewInfo: some View {
        let todayNotes = store.filteredNotes().filter {
            guard let d = $0.scheduledDate else { return false }
            return Calendar.current.isDateInToday(d)
        }

        return Group {
            if !todayNotes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 10))
                    Text("今天 \(todayNotes.count) 条笔记")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(AgendaColor.amber)
            }
        }
    }

    private func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInTomorrow(date) { return "明天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let fm = DateFormatter()
        fm.locale = Locale(identifier: "zh_CN")
        fm.dateFormat = "M月d日 EEEE"
        return fm.string(from: date)
    }

    // MARK: - Integration Card

    private var integrationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agenda + 日历 + 提醒事项")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            Text("Agenda 旨在与\u{201C}日历\u{201D}和\u{201C}提醒事项\u{201D}协同使用。向 Agenda 开放\u{201C}日历\u{201D}和\u{201C}提醒事项\u{201D}的访问权限，享受使 Agenda 独特出众的功能优势。")
                .font(.system(size: 12))
                .foregroundStyle(AgendaColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            HStack(alignment: .firstTextBaseline) {
                Button("了解更多") {}
                    .buttonStyle(.plain)
                    .foregroundStyle(AgendaColor.textMuted)

                Spacer()

                Button("连接") {}
                    .buttonStyle(.plain)
                    .foregroundStyle(AgendaColor.amber)
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(14)
        .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Recent Edits

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionHeader(title: "最近编辑", systemImage: "paintbrush.pointed")

            let recentNotes = store.filteredNotes()
                .sorted { $0.editedAt > $1.editedAt }
                .prefix(4)

            if recentNotes.isEmpty {
                emptyPanelText("无近期编辑记录")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(recentNotes)) { note in
                        Button {
                            store.selectNote(note.id)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                noteColorDot(note.noteColor)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .lineLimit(1)
                                        .font(AgendaFont.panelTitle)
                                        .foregroundStyle(note.status == .open ? .primary : .secondary)

                                    if let project = store.project(withID: note.projectID) {
                                        Text(project.name)
                                            .font(AgendaFont.panelSubtitle)
                                            .foregroundStyle(AgendaColor.textMuted)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Related Notes

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionHeader(title: "相关笔记", systemImage: "link")

            if let selectedNoteID = store.selectedNoteID {
                let relatedNotes = store.relatedNotes(for: selectedNoteID)

                if relatedNotes.isEmpty {
                    emptyPanelText("无相关笔记")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(relatedNotes) { relatedNote in
                            Button {
                                store.selectNote(relatedNote.noteID)
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(.secondary.opacity(0.2))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(relatedNote.title)
                                            .lineLimit(1)
                                            .font(AgendaFont.panelTitle)
                                            .foregroundStyle(.primary.opacity(0.85))

                                        Text(relatedNote.reasons.joined(separator: " / "))
                                            .font(AgendaFont.panelSubtitle)
                                            .foregroundStyle(AgendaColor.textMuted)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)

                                    Text("@")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundStyle(.secondary.opacity(0.22))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                emptyPanelText("选择一条笔记查看关联")
            }
        }
    }

    // MARK: - Helpers

    private func noteColorDot(_ color: NoteColor?) -> some View {
        Circle()
            .fill(color.map { noteColorValue($0) } ?? AgendaColor.amber)
            .frame(width: 6, height: 6)
    }

    private func noteColorValue(_ color: NoteColor) -> Color {
        switch color {
        case .accent: AgendaColor.amber
        case .red: Color(red: 0.95, green: 0.35, blue: 0.35)
        case .green: Color(red: 0.28, green: 0.68, blue: 0.45)
        case .blue: Color(red: 0.26, green: 0.56, blue: 0.95)
        case .yellow: Color(red: 0.95, green: 0.80, blue: 0.15)
        case .brown: Color(red: 0.65, green: 0.45, blue: 0.30)
        case .pink: Color(red: 0.93, green: 0.36, blue: 0.62)
        case .purple: Color(red: 0.62, green: 0.35, blue: 0.85)
        case .gray: Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }

    private func panelSectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AgendaColor.textMuted)
                .frame(width: 18)

            Text(title)
                .font(AgendaFont.panelSectionHeader)
                .foregroundStyle(AgendaColor.textMuted)
        }
    }

    private func emptyPanelText(_ text: String) -> some View {
        Text(text)
            .font(AgendaFont.panelBody)
            .foregroundStyle(AgendaColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
    }
}
