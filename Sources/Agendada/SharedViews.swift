import SwiftUI

struct SmartOverviewSheet: Identifiable {
    let id = UUID()
    let query: String
}

struct SmartOverviewPromptSheet: View {
    let sheet: SmartOverviewSheet
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var query: String

    init(sheet: SmartOverviewSheet, onSave: @escaping (String, String) -> Void) {
        self.sheet = sheet
        self.onSave = onSave
        _query = State(initialValue: sheet.query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("保存为智能概览")
                .font(.title3.weight(.semibold))

            TextField("概览名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)

            TextField("查询条件", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }

                Button("保存") {
                    onSave(name, query)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(20)
    }
}

func copyToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

func splitCommaList(_ text: String) -> [String] {
    text.split(separator: ",").map(String.init)
}
