import AgendadaCore
import SwiftUI

struct CategoryEditorSheet: View {
    enum Mode: Equatable {
        case create
        case edit(ProjectCategory)
        case createSubcategory(parentCategory: ProjectCategory)

        var title: String {
            switch self {
            case .create: "新建分类"
            case .edit:   "编辑分类"
            case .createSubcategory: "新建子分类"
            }
        }

        var isCreate: Bool {
            switch self {
            case .create, .createSubcategory: return true
            case .edit: return false
            }
        }
    }

    let mode: Mode
    let onSave: (String, CategoryColor) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var color: CategoryColor
    @FocusState private var isNameFocused: Bool

    init(mode: Mode, onSave: @escaping (String, CategoryColor) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _color = State(initialValue: .orange)
        case .edit(let category):
            _name = State(initialValue: category.name)
            _color = State(initialValue: category.color)
        case .createSubcategory:
            _name = State(initialValue: "")
            _color = State(initialValue: .orange)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode.title)
                .font(.title3.weight(.semibold))

            Text("分类名称：")
                .font(.caption)
                .foregroundStyle(AgendaColor.textMuted)
            TextField("未命名分类", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)

            Text("分类颜色：")
                .font(.caption)
                .foregroundStyle(AgendaColor.textMuted)
            CategoryColorPicker(selectedColor: $color)

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                Button("保存") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(trimmed.isEmpty ? "未命名分类" : trimmed, color)
                }
                .buttonStyle(.borderedProminent)
                .tint(AgendaColor.amber)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mode.isCreate)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear { isNameFocused = true }
    }
}
