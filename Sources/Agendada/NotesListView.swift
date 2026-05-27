import AgendadaCore
import SwiftUI

struct NotesListView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @State private var smartOverviewSheet: SmartOverviewSheet?
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            notesList
        }
        .navigationTitle(store.activeTitle)
        .sheet(item: $smartOverviewSheet) { sheet in
            SmartOverviewPromptSheet(sheet: sheet) { name, query in
                store.addSmartOverview(name: name, query: query)
                smartOverviewSheet = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.activeTitle)
                        .font(.title2.weight(.semibold))
                    Text("\(store.filteredNotes().count) 条笔记")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    copyToPasteboard(store.summaryMarkdownForFilteredNotes())
                } label: {
                    Label("复制摘要", systemImage: "doc.on.doc")
                }

                Menu {
                    ForEach(NoteTemplate.allCases) { template in
                        Button(template.title) {
                            store.addNote(template: template)
                        }
                    }
                } label: {
                    Label("新建", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            TextField("搜索标题、正文、标签或人员", text: $searchText)
                .textFieldStyle(.roundedBorder)

            quickFilters
        }
        .padding(16)
    }

    @ViewBuilder
    private var quickFilters: some View {
        if !store.allTags.isEmpty || !store.allPeople.isEmpty || !searchText.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !searchText.isEmpty {
                        Button {
                            smartOverviewSheet = SmartOverviewSheet(query: searchText)
                        } label: {
                            Label("保存为智能概览", systemImage: "line.3.horizontal.decrease.circle")
                        }

                        Button {
                            searchText = ""
                        } label: {
                            Label("清除筛选", systemImage: "xmark.circle")
                        }
                    }

                    ForEach(store.allTags, id: \.self) { tag in
                        Button {
                            searchText = "tag:\(tag)"
                        } label: {
                            Label(tag, systemImage: "tag")
                        }
                    }

                    ForEach(store.allPeople, id: \.self) { person in
                        Button {
                            searchText = "person:\(person)"
                        } label: {
                            Label(person, systemImage: "person")
                        }
                    }
                }
                .font(.caption)
            }
        }
    }

    private var notesList: some View {
        List(selection: selectedNoteBinding) {
            ForEach(store.filteredNotes()) { note in
                NoteRow(note: note, projectName: store.project(withID: note.projectID)?.name ?? "未归属")
                    .tag(note.id)
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button(note.isStarred ? "取消标星" : "标星") {
                            store.setStarred(!note.isStarred, noteID: note.id)
                        }

                        Button("指定到今天") {
                            store.scheduleToday(noteID: note.id)
                        }

                        Button("复制笔记") {
                            store.duplicateNote(note.id)
                        }

                        Button("删除笔记", role: .destructive) {
                            store.deleteNote(note.id)
                        }
                    }
            }
        }
        .overlay {
            if store.filteredNotes().isEmpty {
                ContentUnavailableView("没有匹配的笔记", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    private var selectedNoteBinding: Binding<Note.ID?> {
        Binding {
            store.selectedNoteID
        } set: { noteID in
            guard let noteID else { return }
            store.selectNote(noteID)
        }
    }

}

private struct NoteRow: View {
    let note: Note
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)

                if note.isFocused {
                    Image(systemName: "target")
                        .foregroundStyle(.orange)
                        .help("当前关注")
                }

                if note.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .help("已标星")
                }
            }

            Text(note.body.isEmpty ? "无正文" : note.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Label(projectName, systemImage: "folder")

                if let scheduledDate = note.scheduledDate {
                    Label(scheduledDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }

                if note.checklistSummary.totalCount > 0 {
                    Label(note.checklistSummary.title, systemImage: "checklist")
                }

                Text(note.status.title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !note.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}
