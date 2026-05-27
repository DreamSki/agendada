import AgendadaCore
import SwiftUI

struct TagManagerView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var sheet: TagSheet?
    @State private var deletionTarget: String?
    @State private var mergeSource: String?
    @State private var searchText = ""

    var body: some View {
        let tags = filteredTags

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("标签管理器")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    sheet = .create
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AgendaColor.amber)
                .help("新建标签")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(AgendaColor.textMuted)
                TextField("搜索标签", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            // Tag list
            if tags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.25))
                    Text(searchText.isEmpty ? "暂无标签" : "无匹配标签")
                        .font(.system(size: 13))
                        .foregroundStyle(AgendaColor.textMuted)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(tags, id: \.name) { item in
                            tagRow(item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 420, height: 480)
        .background(.regularMaterial)
        .sheet(item: $sheet) { s in
            tagSheet(s)
        }
        .confirmationDialog(
            "删除标签？",
            isPresented: Binding(
                get: { deletionTarget != nil },
                set: { if !$0 { deletionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let tag = deletionTarget {
                Button("删除\u{201C}\(tag)\u{201D}", role: .destructive) {
                    store.deleteTag(tag)
                    deletionTarget = nil
                }
            }
            Button("取消", role: .cancel) {
                deletionTarget = nil
            }
        } message: {
            if let tag = deletionTarget {
                Text("会从所有笔记中移除\u{201C}\(tag)\u{201D}标签，但不会删除笔记。")
            }
        }
        .confirmationDialog(
            "合并标签",
            isPresented: Binding(
                get: { mergeSource != nil },
                set: { if !$0 { mergeSource = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let source = mergeSource {
                ForEach(store.tagCounts.filter { $0.name != source }, id: \.name) { item in
                    Button("\u{201C}\(source)\u{201D} → \u{201C}\(item.name)\u{201D} (\(item.count) 条)") {
                        store.mergeTag(source, into: item.name)
                        mergeSource = nil
                    }
                }
            }
            Button("取消", role: .cancel) {
                mergeSource = nil
            }
        } message: {
            if let source = mergeSource {
                Text("选择要合并到的目标标签，\u{201C}\(source)\u{201D}将从所有笔记中移除。")
            }
        }
    }

    private var filteredTags: [(name: String, count: Int)] {
        let tags = store.tagCounts
        guard !searchText.isEmpty else { return tags }
        return tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Tag Row

    private func tagRow(_ item: (name: String, count: Int)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .font(.system(size: 11))
                .foregroundStyle(AgendaColor.tagCyan)
                .frame(width: 18)

            Text("#\(item.name)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Text("\(item.count) 条笔记")
                .font(.system(size: 11))
                .foregroundStyle(AgendaColor.textMuted)

            Spacer()

            Menu {
                Button("重命名") {
                    sheet = .rename(item.name)
                }
                Button("合并到其他标签") {
                    mergeSource = item.name
                }
                Divider()
                Button("删除标签", role: .destructive) {
                    deletionTarget = item.name
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(AgendaColor.textMuted.opacity(0.5))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 22, height: 22)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.clear)
        )
    }

    // MARK: - Tag Sheet

    private func tagSheet(_ s: TagSheet) -> some View {
        TagEditSheet(sheet: s) { result in
            switch result {
            case let .create(name):
                store.renameTag(name, to: name)
            case let .rename(oldName, newName):
                store.renameTag(oldName, to: newName)
            }
            sheet = nil
        }
    }
}

// MARK: - Tag Sheet Types

private enum TagSheet: Identifiable {
    case create
    case rename(String)

    var id: String {
        switch self {
        case .create: "create"
        case let .rename(name): "rename-\(name)"
        }
    }

    var title: String {
        switch self {
        case .create: "新建标签"
        case .rename: "重命名标签"
        }
    }

    var placeholder: String {
        switch self {
        case .create: "标签名称"
        case .rename: "新名称"
        }
    }

    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}

private enum TagSheetResult {
    case create(name: String)
    case rename(oldName: String, newName: String)
}

private struct TagEditSheet: View {
    let sheet: TagSheet
    let onSave: (TagSheetResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(sheet: TagSheet, onSave: @escaping (TagSheetResult) -> Void) {
        self.sheet = sheet
        self.onSave = onSave
        let initial: String = {
            if case let .rename(n) = sheet { return n }
            return ""
        }()
        _name = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sheet.title)
                .font(.title3.weight(.semibold))

            TextField(sheet.placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    if sheet.isCreate {
                        onSave(.create(name: name))
                    } else if case let .rename(oldName) = sheet {
                        onSave(.rename(oldName: oldName, newName: name))
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }
}
