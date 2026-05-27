import AgendadaCore
import SwiftUI

struct EditorView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var draft = NoteDraft()

    var body: some View {
        Group {
            if let note = store.selectedNote {
                editor(for: note)
            } else {
                ContentUnavailableView("选择一条笔记", systemImage: "doc.text")
            }
        }
        .onChange(of: store.selectedNoteID) {
            loadSelectedNote()
        }
        .onAppear {
            loadSelectedNote()
        }
    }

    private func editor(for note: Note) -> some View {
        VStack(spacing: 0) {
            header(for: note)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("标题", text: $draft.title)
                        .font(.largeTitle.weight(.semibold))
                        .textFieldStyle(.plain)

                    HStack(spacing: 12) {
                        Toggle("当前关注", isOn: $draft.isFocused)
                            .toggleStyle(.switch)

                        Picker("状态", selection: $draft.status) {
                            ForEach(NoteStatus.allCases, id: \.self) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .frame(width: 150)

                        DatePicker(
                            "日期",
                            selection: Binding(
                                get: { draft.scheduledDate ?? Date() },
                                set: { draft.scheduledDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .disabled(!draft.hasScheduledDate)

                        Toggle("指定日期", isOn: $draft.hasScheduledDate)
                            .toggleStyle(.checkbox)
                    }

                    metadataField(title: "标签", text: $draft.tagsText, placeholder: "用逗号分隔，例如：MVP, 会议")
                    metadataField(title: "人员", text: $draft.peopleText, placeholder: "用逗号分隔，例如：产品, 工程")

                    if note.checklistSummary.totalCount > 0 {
                        checklistSummary(note.checklistSummary)
                    }

                    TextEditor(text: $draft.body)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 340)
                        .padding(10)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                    relatedNotes(for: note)
                }
                .padding(24)
            }
        }
        .onChange(of: draft) {
            saveDraft(for: note.id)
        }
    }

    private func header(for note: Note) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.project(withID: note.projectID)?.name ?? "未归属项目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(note.editedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                draft.isStarred.toggle()
            } label: {
                Label("标星", systemImage: draft.isStarred ? "star.fill" : "star")
            }

            Button {
                draft.isFocused.toggle()
            } label: {
                Label("当前关注", systemImage: draft.isFocused ? "target" : "circle")
            }

            Menu {
                Button("复制摘要") {
                    if let summary = store.summaryMarkdown(for: note.id) {
                        copyToPasteboard(summary)
                    }
                }

                Button("指定到今天") {
                    store.scheduleToday(noteID: note.id)
                    loadSelectedNote()
                }

                Button("复制笔记") {
                    store.duplicateNote(note.id)
                }

                Button("删除笔记", role: .destructive) {
                    store.deleteNote(note.id)
                }
            } label: {
                Label("更多", systemImage: "ellipsis.circle")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func metadataField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func checklistSummary(_ summary: ChecklistSummary) -> some View {
        HStack(spacing: 10) {
            Label(summary.title, systemImage: "checklist")
                .font(.callout.weight(.medium))

            Text("\(summary.openCount) 项未完成")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func relatedNotes(for note: Note) -> some View {
        let relatedNotes = store.relatedNotes(for: note.id)

        if !relatedNotes.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("相关笔记")
                    .font(.headline)

                ForEach(relatedNotes) { relatedNote in
                    Button {
                        store.selectNote(relatedNote.noteID)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(relatedNote.title)
                                    .font(.callout.weight(.medium))
                                Text(relatedNote.reasons.joined(separator: " / "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadSelectedNote() {
        guard let note = store.selectedNote else {
            draft = NoteDraft()
            return
        }

        draft = NoteDraft(note: note)
    }

    private func saveDraft(for noteID: Note.ID) {
        guard store.selectedNoteID == noteID else { return }

        let scheduledDate = draft.hasScheduledDate ? draft.scheduledDate : nil
        store.updateSelectedNote(
            title: draft.title,
            body: draft.body,
            scheduledDate: scheduledDate,
            tags: splitList(draft.tagsText),
            people: splitList(draft.peopleText)
        )
        store.setFocused(draft.isFocused, noteID: noteID)
        store.setStarred(draft.isStarred, noteID: noteID)
        store.setStatus(draft.status, noteID: noteID)
    }

    private func splitList(_ text: String) -> [String] {
        splitCommaList(text)
    }
}

private struct NoteDraft: Equatable {
    var title = ""
    var body = ""
    var hasScheduledDate = true
    var scheduledDate: Date? = Date()
    var tagsText = ""
    var peopleText = ""
    var status: NoteStatus = .open
    var isFocused = false
    var isStarred = false

    init() {}

    init(note: Note) {
        title = note.title
        body = note.body
        hasScheduledDate = note.scheduledDate != nil
        scheduledDate = note.scheduledDate ?? Date()
        tagsText = note.tags.joined(separator: ", ")
        peopleText = note.people.joined(separator: ", ")
        status = note.status
        isFocused = note.isFocused
        isStarred = note.isStarred
    }
}
