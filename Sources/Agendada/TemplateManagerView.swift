import AgendadaCore
import SwiftUI

struct TemplateManagerView: View {
    @Environment(ObservableLibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var sheet: TemplateSheet?
    @State private var deletionTarget: CustomNoteTemplate?
    @State private var searchText = ""

    var body: some View {
        let templates = filteredTemplates
        let builtInTemplates = filteredBuiltInTemplates

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("模板管理器")
                    .font(.title2.weight(.semibold))

                Spacer()

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
                TextField("搜索模板", text: $searchText)
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

            // Built-in templates section
            VStack(alignment: .leading, spacing: 0) {
                Text("内置模板")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AgendaColor.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                if builtInTemplates.isEmpty {
                    Text("无匹配内置模板")
                        .font(.system(size: 12))
                        .foregroundStyle(AgendaColor.textMuted)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                } else {
                    ForEach(builtInTemplates) { template in
                        builtInTemplateRow(template)
                    }
                }
            }

            Divider()
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Custom templates section
            if templates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.25))
                    Text(searchText.isEmpty ? "暂无自定义模板" : "无匹配模板")
                        .font(.system(size: 13))
                        .foregroundStyle(AgendaColor.textMuted)
                    Text("在笔记右键菜单选择「存储为模板」")
                        .font(.system(size: 11))
                        .foregroundStyle(AgendaColor.textMuted.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("自定义模板")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AgendaColor.textMuted)
                            .padding(.bottom, 8)

                        ForEach(templates) { template in
                            customTemplateRow(template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 420, height: 520)
        .background(.regularMaterial)
        .sheet(item: $sheet) { s in
            templateSheet(s)
        }
        .confirmationDialog(
            "删除模板？",
            isPresented: Binding(
                get: { deletionTarget != nil },
                set: { if !$0 { deletionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let template = deletionTarget {
                Button("删除「\(template.name)」", role: .destructive) {
                    store.deleteCustomNoteTemplate(template.id)
                    deletionTarget = nil
                }
            }
            Button("取消", role: .cancel) {
                deletionTarget = nil
            }
        } message: {
            Text("删除后将无法恢复，但不会影响已使用此模板创建的笔记。")
        }
    }

    private var filteredTemplates: [CustomNoteTemplate] {
        let templates = store.customNoteTemplatesList()
        guard !searchText.isEmpty else { return templates }
        return templates.filter { template in
            template.name.localizedCaseInsensitiveContains(searchText)
                || template.title.localizedCaseInsensitiveContains(searchText)
                || template.body.localizedCaseInsensitiveContains(searchText)
                || template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var filteredBuiltInTemplates: [NoteTemplate] {
        guard !searchText.isEmpty else { return NoteTemplate.allCases }
        return NoteTemplate.allCases.filter { template in
            template.title.localizedCaseInsensitiveContains(searchText)
                || template.defaultNoteTitle.localizedCaseInsensitiveContains(searchText)
                || template.body.localizedCaseInsensitiveContains(searchText)
                || template.defaultTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // MARK: - Built-in Template Row

    private func builtInTemplateRow(_ template: NoteTemplate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(AgendaColor.amber)
                .frame(width: 18)

            Text(template.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                sheet = .preview(.builtIn(template))
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AgendaColor.textMuted)
            .help("预览模板")

            Button {
                let id = store.addNoteReturningID(template: template)
                store.selectNote(id)
                dismiss()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AgendaColor.amber)
            .help("从模板新建笔记")

            Text("内置")
                .font(.system(size: 10))
                .foregroundStyle(AgendaColor.textMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AgendaColor.canvasGray, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Custom Template Row

    private func customTemplateRow(_ template: CustomNoteTemplate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 11))
                .foregroundStyle(AgendaColor.amber)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                if !template.tags.isEmpty {
                    Text(template.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.system(size: 10))
                        .foregroundStyle(AgendaColor.textMuted)
                }
            }

            Spacer()

            Button {
                sheet = .preview(.custom(template))
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AgendaColor.textMuted)
            .help("预览模板")

            Button {
                if let id = store.addNoteReturningID(customTemplate: template.id) {
                    store.selectNote(id)
                    dismiss()
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AgendaColor.amber)
            .help("从模板新建笔记")

            Menu {
                Button("预览") {
                    sheet = .preview(.custom(template))
                }
                Button("从模板新建笔记") {
                    if let id = store.addNoteReturningID(customTemplate: template.id) {
                        store.selectNote(id)
                        dismiss()
                    }
                }
                Divider()
                Button("重命名") {
                    sheet = .rename(template)
                }
                Divider()
                Button("删除模板", role: .destructive) {
                    deletionTarget = template
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

    // MARK: - Template Sheet

    @ViewBuilder
    private func templateSheet(_ s: TemplateSheet) -> some View {
        switch s {
        case .rename:
            TemplateEditSheet(sheet: s) { newName in
            if case let .rename(template) = s {
                store.renameCustomNoteTemplate(template.id, name: newName)
            }
            sheet = nil
        }
        case let .preview(preview):
            TemplatePreviewSheet(preview: preview) {
                switch preview {
                case let .builtIn(template):
                    let id = store.addNoteReturningID(template: template)
                    store.selectNote(id)
                case let .custom(template):
                    if let id = store.addNoteReturningID(customTemplate: template.id) {
                        store.selectNote(id)
                    }
                }
                sheet = nil
                dismiss()
            }
        }
    }
}

// MARK: - Template Sheet Types

private enum TemplateSheet: Identifiable {
    case rename(CustomNoteTemplate)
    case preview(TemplatePreview)

    var id: String {
        switch self {
        case let .rename(template): "rename-\(template.id)"
        case let .preview(preview): "preview-\(preview.id)"
        }
    }
}

private enum TemplatePreview: Identifiable {
    case builtIn(NoteTemplate)
    case custom(CustomNoteTemplate)

    var id: String {
        switch self {
        case let .builtIn(template): "built-in-\(template.id)"
        case let .custom(template): "custom-\(template.id)"
        }
    }

    var name: String {
        switch self {
        case let .builtIn(template): template.title
        case let .custom(template): template.name
        }
    }

    var title: String {
        switch self {
        case let .builtIn(template): template.defaultNoteTitle
        case let .custom(template): template.title
        }
    }

    var body: String {
        switch self {
        case let .builtIn(template): template.body
        case let .custom(template): template.body
        }
    }

    var tags: [String] {
        switch self {
        case let .builtIn(template): template.defaultTags
        case let .custom(template): template.tags
        }
    }
}

private struct TemplateEditSheet: View {
    let sheet: TemplateSheet
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(sheet: TemplateSheet, onSave: @escaping (String) -> Void) {
        self.sheet = sheet
        self.onSave = onSave
        let initial: String = {
            if case let .rename(t) = sheet { return t.name }
            return ""
        }()
        _name = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名模板")
                .font(.title3.weight(.semibold))

            TextField("模板名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    onSave(name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }
}

private struct TemplatePreviewSheet: View {
    let preview: TemplatePreview
    let onCreate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.name)
                        .font(.title3.weight(.semibold))
                    Text(preview.title)
                        .font(.system(size: 13))
                        .foregroundStyle(AgendaColor.textMuted)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary.opacity(0.55))
            }

            if !preview.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(preview.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AgendaColor.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AgendaColor.canvasGray, in: Capsule())
                    }
                }
            }

            ScrollView {
                Text(plainPreview(preview.body))
                    .font(.system(size: 13))
                    .foregroundStyle(AgendaColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(width: 380, height: 220)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.06), lineWidth: 0.5))

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                Button {
                    onCreate()
                    dismiss()
                } label: {
                    Label("新建笔记", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private func plainPreview(_ html: String) -> String {
        let withoutTags = html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</(p|h[1-6]|li|ul|ol)>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let collapsedSpaces = withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+\\n", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsedSpaces.isEmpty ? "空白内容" : collapsedSpaces
    }
}
