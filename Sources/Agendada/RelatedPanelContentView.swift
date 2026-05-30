import AgendadaCore
import SwiftUI

struct RelatedPanelContentView: View {
    @Environment(ObservableLibraryStore.self) private var store

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    integrationInfoCard
                        .padding(.top, 4)

                    if store.selectedNote != nil {
                        quickActionsSection
                    }

                    recentSection
                    relatedSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 32)
            }

            VStack(spacing: 0) {
                panelTabHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 30)
                    .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.980, green: 0.980, blue: 0.980).opacity(0.97), location: 0.0),
                        .init(color: Color(red: 0.980, green: 0.980, blue: 0.980).opacity(0.80), location: 0.55),
                        .init(color: .clear, location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .navigationTitle("")
        .background(AgendaColor.panelBg)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AgendaColor.divider)
                .frame(width: 1)
        }
    }

    // MARK: - Tab Header

    private var panelTabHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .regular))
                Text("时间轴")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Pyramid icon matching reference
            Image(systemName: "mountain.2")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.secondary.opacity(0.25))
        }
    }

    // MARK: - Integration Info Card

    private var integrationInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Agenda + 日历 + 提醒事项")
                .font(.custom("Avenir Next Demi Bold", size: 13))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            Text("Agenda 旨在与\u{201C}日历\u{201D}和\u{201C}提醒事项\u{201D}协同使用。向 Agenda 开放\u{201C}日历\u{201D}和\u{201C}提醒事项\u{201D}的访问权限，享受使 Agenda 独特出众的功能优势。")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(AgendaColor.textMuted)
                .lineSpacing(4)
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                Text("了解更多")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(AgendaColor.textMuted)

                Spacer()

                Button("连接") {
                    requestIntegrationsAccess()
                }
                .buttonStyle(.plain)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(AgendaColor.amber)
            }
        }
        .padding(14)
        .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
    }

    private func requestIntegrationsAccess() {
        // Placeholder — EventKit + Reminders integration in P2
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelSectionHeader(title: "快捷日期", systemImage: "forward.fill")

            VStack(spacing: 0) {
                quickActionButton("今晚", systemImage: "moon.stars") { scheduleForEvening() }
                Divider().padding(.leading, 28)
                quickActionButton("明天", systemImage: "sunrise") { scheduleForTomorrow() }
                Divider().padding(.leading, 28)
                quickActionButton("本周末", systemImage: "calendar.badge.clock") { scheduleForWeekend() }
                Divider().padding(.leading, 28)
                quickActionButton("下周", systemImage: "calendar") { scheduleForNextWeek() }
            }
            .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func quickActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(AgendaColor.amber)
                    .frame(width: 16)

                Text(title)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func scheduleForEvening() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let evening = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        store.scheduleDate(evening, noteID: noteID)
    }

    private func scheduleForTomorrow() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        store.scheduleDate(tomorrow, noteID: noteID)
    }

    private func scheduleForWeekend() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = cal.date(byAdding: .day, value: max(1, daysUntilSaturday),
                                 to: cal.startOfDay(for: Date()))!
        store.scheduleDate(saturday, noteID: noteID)
    }

    private func scheduleForNextWeek() {
        guard let noteID = store.selectedNoteID else { return }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        let daysUntilNextMonday = (9 - weekday) % 7
        let nextMonday = cal.date(byAdding: .day, value: daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday,
                                   to: cal.startOfDay(for: Date()))!
        store.scheduleDate(nextMonday, noteID: noteID)
    }

    // MARK: - Recent Edits

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionHeader(title: "最近编辑", systemImage: "tag")

            let recentNotes = store.filteredNotes()
                .sorted { $0.editedAt > $1.editedAt }
                .prefix(4)

            if recentNotes.isEmpty {
                emptyPanelText("无近期编辑记录")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(recentNotes)) { note in
                        Button {
                            store.selectNote(note.id)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(AgendaColor.amber)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .lineLimit(1)
                                        .font(.custom("Avenir Next Medium", size: 13))
                                        .foregroundStyle(note.status == .open ? .primary : .secondary)

                                    if let project = store.project(withID: note.projectID) {
                                        Text(project.name)
                                            .font(.custom("Avenir Next", size: 11))
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
                                            .font(.custom("Avenir Next Medium", size: 13))
                                            .foregroundStyle(.primary.opacity(0.85))

                                        Text(relatedNote.reasons.joined(separator: " / "))
                                            .font(.custom("Avenir Next", size: 11))
                                            .foregroundStyle(AgendaColor.textMuted)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)
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

    private func panelSectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AgendaColor.textMuted)
                .frame(width: 18)

            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(AgendaColor.textMuted)
        }
    }

    private func emptyPanelText(_ text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next", size: 13))
            .foregroundStyle(AgendaColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
    }
}
