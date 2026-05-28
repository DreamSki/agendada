import AgendadaCore
import AppKit
import SwiftUI

struct BlockNotePreviewView: View {
    let note: Note
    var maxBlocks: Int?

    private var blocks: [PreviewBlock] {
        PreviewBlock.decode(from: note.blockJSON)
    }

    private var visibleItems: [PreviewRenderItem] {
        let visible = flattenedItems(from: blocks).filter { !$0.block.isVisuallyEmpty }
        if let maxBlocks = maxBlocks {
            return Array(visible.prefix(maxBlocks))
        }
        return visible
    }

    var body: some View {
        Group {
            if visibleItems.isEmpty {
                Text("空白笔记")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.78, green: 0.78, blue: 0.80))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleItems) { item in
                        PreviewBlockRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, 30)
        .padding(.trailing, 8)
    }

    private func flattenedItems(from blocks: [PreviewBlock], depth: Int = 0) -> [PreviewRenderItem] {
        var items: [PreviewRenderItem] = []
        var numberedIndex = 1

        for block in blocks {
            let numberIndex: Int?
            if block.type == "numberedListItem" {
                numberIndex = numberedIndex
                numberedIndex += 1
            } else {
                numberIndex = nil
                numberedIndex = 1
            }

            items.append(PreviewRenderItem(block: block, depth: depth, numberIndex: numberIndex))
            if let children = block.children, !children.isEmpty {
                items.append(contentsOf: flattenedItems(from: children, depth: depth + 1))
            }
        }

        return items
    }
}

// MARK: - Metrics (match editor CSS exactly)

private enum PreviewMetrics {
    static let nestIndent: CGFloat = 24
    static let markerWidth: CGFloat = 24
    static let blockVPadding: CGFloat = 3
    static let bodyFontSize: CGFloat = 14
    static let lineHeight: CGFloat = 1.65
    static let codeFontSize: CGFloat = 13
    static let heading1Size: CGFloat = 20
    static let heading2Size: CGFloat = 17
    static let heading3Size: CGFloat = 16
}

private struct PreviewRenderItem: Identifiable {
    let id = UUID()
    let block: PreviewBlock
    let depth: Int
    let numberIndex: Int?
}

// MARK: - Block Row

private struct PreviewBlockRow: View {
    let item: PreviewRenderItem

    private var block: PreviewBlock { item.block }

    var body: some View {
        Group {
            switch block.type {
            case "heading":
                headingView
            case "bulletListItem":
                bulletView
            case "numberedListItem":
                numberedView
            case "checkListItem":
                checkboxView
            case "quote":
                quoteView
            case "codeBlock":
                codeView
            case "divider":
                dividerView
            case "image":
                imageView
            case "table":
                tableView
            default:
                paragraphView
            }
        }
        .padding(.leading, CGFloat(item.depth) * PreviewMetrics.nestIndent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Paragraph

    private var paragraphView: some View {
        bodyText(block.plainText)
            .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    // MARK: Heading

    private var headingView: some View {
        Text(block.plainText)
            .font(.system(size: headingSize, weight: .bold))
            .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
            .lineSpacing(lineSpacingForSize(headingSize))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 3)
            .padding(.bottom, PreviewMetrics.blockVPadding)
    }

    private var headingSize: CGFloat {
        switch block.headingLevel {
        case 1: return PreviewMetrics.heading1Size
        case 3: return PreviewMetrics.heading3Size
        default: return PreviewMetrics.heading2Size
        }
    }

    // MARK: Lists

    private var bulletView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(bulletMarker)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AgendaColor.textMuted)
                .frame(width: PreviewMetrics.markerWidth, alignment: .center)
            bodyText(block.plainText)
        }
        .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    private var numberedView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(item.numberIndex ?? 1).")
                .font(.system(size: 14))
                .foregroundStyle(AgendaColor.textMuted)
                .frame(width: PreviewMetrics.markerWidth, alignment: .trailing)
            bodyText(block.plainText)
        }
        .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    private var checkboxView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(block.isChecked ? AgendaColor.amber : AgendaColor.textMuted)
                .frame(width: PreviewMetrics.markerWidth, alignment: .center)
            bodyText(block.checkboxText)
                .strikethrough(block.isChecked, color: AgendaColor.textMuted)
                .foregroundStyle(block.isChecked ? AgendaColor.textMuted : AgendaColor.textBody)
        }
        .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    private var bulletMarker: String {
        switch item.depth % 3 {
        case 1: return "\u{25E6}" // ◦
        case 2: return "\u{25AA}" // ▪︎
        default: return "\u{2022}" // •
        }
    }

    // MARK: Quote

    private var quoteView: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color(red: 0.961, green: 0.898, blue: 0.753))
                .frame(width: 3)
            bodyText(block.plainText)
                .italic()
        }
        .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    // MARK: Code

    private var codeView: some View {
        Text(block.plainText.isEmpty ? " " : block.plainText)
            .font(.system(size: PreviewMetrics.codeFontSize, design: .monospaced))
            .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.19))
            .lineSpacing(0)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.045)))
            .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    // MARK: Divider

    private var dividerView: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 1)
            .padding(.vertical, 10)
    }

    // MARK: Image

    private var imageView: some View {
        PreviewImageBlock(block: block)
            .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    // MARK: Table

    private var tableView: some View {
        guard let tc = block.tableContent, !tc.rows.isEmpty else {
            return AnyView(EmptyView())
        }
        let headerCount = tc.headerRows ?? 0
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(tc.rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            let isHeader = rowIndex < headerCount || cell.type == "tableHeader"
                            Text(cell.content.map(\.plainText).joined())
                                .font(.system(size: PreviewMetrics.bodyFontSize))
                                .fontWeight(isHeader ? .semibold : .regular)
                                .foregroundStyle(isHeader ? Color(red: 0.102, green: 0.102, blue: 0.102) : AgendaColor.textBody)
                                .lineSpacing(lineSpacingForSize(PreviewMetrics.bodyFontSize))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isHeader ? Color.primary.opacity(0.04) : Color.clear)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if rowIndex < tc.rows.count - 1 {
                            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            .padding(.vertical, PreviewMetrics.blockVPadding)
        )
    }

    // MARK: Helpers

    private func bodyText(_ value: String) -> some View {
        Text(value.isEmpty ? " " : value)
            .font(.system(size: PreviewMetrics.bodyFontSize))
            .foregroundStyle(AgendaColor.textBody)
            .lineSpacing(lineSpacingForSize(PreviewMetrics.bodyFontSize))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func lineSpacingForSize(_ size: CGFloat) -> CGFloat {
        max(0, size * PreviewMetrics.lineHeight - size)
    }
}

// MARK: - Image Block

private struct PreviewImageBlock: View {
    let block: PreviewBlock

    var body: some View {
        if let image = block.localImage {
            VStack(alignment: .leading, spacing: 6) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 260, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if block.hasVisibleImageLabel {
                    Text(block.imageLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(AgendaColor.textMuted)
                        .lineLimit(2)
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AgendaColor.amber)
                Text(block.imageLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(AgendaColor.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.045)))
        }
    }
}

// MARK: - Block JSON Decoding

private struct PreviewBlock: Decodable, Identifiable {
    var id = UUID()
    var type: String
    var content: PreviewContent?
    var props: [String: PreviewJSONValue]?
    var children: [PreviewBlock]?

    enum CodingKeys: String, CodingKey {
        case type, content, props, children
    }

    var plainText: String {
        content?.plainText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var checkboxText: String {
        plainText
            .replacingOccurrences(of: #"^\s*[-*]?\s*\[[ xX]\]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isChecked: Bool {
        if let checked = props?["checked"]?.boolValue { return checked }
        return plainText.range(of: #"^\s*[-*]?\s*\[[xX]\]"#, options: .regularExpression) != nil
    }

    var headingLevel: Int {
        props?["level"]?.intValue ?? 2
    }

    var imageLabel: String {
        if let caption = props?["caption"]?.stringValue, !caption.isEmpty { return caption }
        if let name = props?["name"]?.stringValue, !name.isEmpty { return name }
        return "图片"
    }

    var hasVisibleImageLabel: Bool {
        if let caption = props?["caption"]?.stringValue, !caption.isEmpty { return true }
        return false
    }

    var imageURL: URL? {
        guard let value = props?["url"]?.stringValue ?? props?["src"]?.stringValue,
              let url = URL(string: value) else { return nil }
        return url
    }

    var localImage: NSImage? {
        guard let imageURL, imageURL.isFileURL else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    var isVisuallyEmpty: Bool {
        switch type {
        case "divider", "image", "table": return false
        default: return plainText.isEmpty
        }
    }

    var tableContent: PreviewTableContent? {
        guard case .tableContent(let tc) = content else { return nil }
        return tc
    }

    static func decode(from data: Data) -> [PreviewBlock] {
        (try? JSONDecoder().decode([PreviewBlock].self, from: data)) ?? []
    }
}

private enum PreviewContent: Decodable {
    case text(String)
    case inline([PreviewInline])
    case tableContent(PreviewTableContent)

    var plainText: String {
        switch self {
        case .text(let value): return value
        case .inline(let items): return items.map(\.plainText).joined()
        case .tableContent(let tc):
            return tc.rows.flatMap { row in
                row.cells.map { cell in cell.content.map(\.plainText).joined() }
            }.joined(separator: " ")
        }
    }

    init(from decoder: Decoder) throws {
        if let tc = try? PreviewTableContent(from: decoder) {
            self = .tableContent(tc)
            return
        }
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }
        self = .inline((try? container.decode([PreviewInline].self)) ?? [])
    }
}

private struct PreviewTableContent: Decodable {
    let rows: [PreviewTableRow]
    let headerRows: Int?
}

private struct PreviewTableRow: Decodable {
    let cells: [PreviewTableCell]
}

private struct PreviewTableCell: Decodable {
    let type: String?
    let content: [PreviewInline]
}

private struct PreviewInline: Decodable {
    var type: String?
    var text: String?
    var content: [PreviewInline]?

    var plainText: String {
        if let text { return text }
        return content?.map(\.plainText).joined() ?? ""
    }
}

private enum PreviewJSONValue: Decodable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case object([String: PreviewJSONValue])
    case array([PreviewJSONValue])
    case null

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([PreviewJSONValue].self) {
            self = .array(value)
        } else {
            self = .object((try? container.decode([String: PreviewJSONValue].self)) ?? [:])
        }
    }
}
