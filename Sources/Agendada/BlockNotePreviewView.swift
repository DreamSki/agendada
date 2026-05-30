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
                    .font(.custom("Avenir Next", size: PreviewMetrics.bodyFontSize))
                    .foregroundStyle(PreviewMetrics.placeholderColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PreviewMetrics.blockVPadding)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleItems) { item in
                        PreviewBlockRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 首块顶部偏移：CSS padding-top=3px，但 SwiftUI blockVPadding=6，
        // 段间叠加需要 2x 但首段顶部只需 1x，故上移 3px 补偿
        .padding(.top, -(PreviewMetrics.blockVPadding / 2))
        .padding(.leading, PreviewMetrics.editorLeadingPadding)
        .padding(.trailing, PreviewMetrics.editorTrailingPadding)
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

// MARK: - Metrics (基于对比视图精准测量)

private enum PreviewMetrics {
    // 正文左边缘与卡片标题圆圈左边缘对齐（卡片 16px padding 处）
    static let editorLeadingPadding: CGFloat = 0
    static let editorTrailingPadding: CGFloat = 8
    static let nestIndent: CGFloat = 24
    static let markerWidth: CGFloat = 24

    // 段间距：CSS 3px，但 SwiftUI 需要 6px 才能匹配
    static let blockVPadding: CGFloat = 6

    // 正文：编辑器实测
    static let bodyFontSize: CGFloat = 14
    static let lineHeight: CGFloat = 1.65

    // 代码：font-size: 13px
    static let codeFontSize: CGFloat = 13

    // 标题：H1/H2 同字号 17pt，H3 小一号 15pt
    static let heading1Size: CGFloat = 17
    static let heading2Size: CGFloat = 17
    static let heading3Size: CGFloat = 15

    // 标题 vertical padding：CSS × 1.83
    // H1: CSS top=10px → 18.3, bottom=3px → 5.5
    // H2/H3: CSS 3px → 5.5
    static let heading1TopPadding: CGFloat = 18.3
    static let headingVPadding: CGFloat = 5.5

    static let quoteBorderWidth: CGFloat = 3
    static let quoteTextInset: CGFloat = 10
    static let mediaMaxHeight: CGFloat = 260

    // 表格单元格：CSS 7px，SwiftUI 需要 10px
    static let tableCellHPadding: CGFloat = 10
    static let tableCellVPadding: CGFloat = 10
    static let blockRadius: CGFloat = 6

    static let bodyColor = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let headingColor = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let mutedColor = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let placeholderColor = Color(red: 0.780, green: 0.780, blue: 0.800)
    static let quoteBorderColor = Color(red: 0.961, green: 0.898, blue: 0.753)  // #F5E5C0 引用块边框色
    static let codeColor = Color(red: 0.18, green: 0.18, blue: 0.19)  // #2E2E30
    static let codeBackgroundColor = Color.black.opacity(0.045)
    static let dividerColor = Color.black.opacity(0.10)  // rgba(0, 0, 0, 0.10)
    static let tableBorderColor = Color(red: 0.867, green: 0.867, blue: 0.867)  // #ddd
    static let tableHeaderBackgroundColor = Color.black.opacity(0.04)

    // 精确计算 lineSpacing：
    // CSS line-height 1.65 表示：单行高度 = fontSize * 1.65
    // SwiftUI lineSpacing 表示：n行高度 = n*fontSize + (n-1)*spacing
    // 解得：spacing ≈ fontSize * (lineHeight - 1) = fontSize * 0.65
    // 对于 14px：14 * 0.65 = 9.1px
    // 实测微调：8.5px 更接近视觉效果
    static func lineSpacing(for size: CGFloat) -> CGFloat {
        // 基于编辑器实测: lineHeight 23.1px = 14 * 1.65
        // 理论 spacing = size * (1.65 - 1) = size * 0.65
        // 微调后: 0.608
        size * 0.608
    }
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
        bodyText(block.content)
            .padding(.vertical, PreviewMetrics.blockVPadding)
            .background(block.backgroundColor ?? Color.clear)
    }

    // MARK: Heading

    private var headingView: some View {
        richText(
            block.content,
            fallback: block.plainText,
            fontSize: headingSize,
            baseWeight: .bold,
            baseColor: headingTextColor
        )
            .padding(.top, isH1 ? PreviewMetrics.heading1TopPadding : PreviewMetrics.headingVPadding)
            .padding(.bottom, PreviewMetrics.headingVPadding)
            .background(block.backgroundColor ?? Color.clear)
    }

    private var isH1: Bool { block.headingLevel == 1 }

    private var headingTextColor: Color {
        if block.headingLevel == 3 { return PreviewMetrics.mutedColor }
        return block.textColor ?? PreviewMetrics.headingColor
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
                .font(.custom("Avenir Next Demi Bold", size: PreviewMetrics.bodyFontSize))
                .foregroundStyle(PreviewMetrics.mutedColor)
                .frame(width: PreviewMetrics.markerWidth, alignment: .center)
            bodyText(block.content)
        }
        .padding(.vertical, PreviewMetrics.blockVPadding)
        .background(block.backgroundColor ?? Color.clear)
    }

    private var numberedView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(item.numberIndex ?? 1).")
                .font(.custom("Avenir Next", size: PreviewMetrics.bodyFontSize))
                .foregroundStyle(PreviewMetrics.mutedColor)
                .frame(width: PreviewMetrics.markerWidth, alignment: .trailing)
            bodyText(block.content)
        }
        .padding(.vertical, PreviewMetrics.blockVPadding)
        .background(block.backgroundColor ?? Color.clear)
    }

    private var checkboxView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                .font(.custom("Avenir Next Medium", size: PreviewMetrics.bodyFontSize))
                .foregroundStyle(block.isChecked ? AgendaColor.amber : PreviewMetrics.mutedColor)
                .frame(width: PreviewMetrics.markerWidth, alignment: .center)
            bodyText(block.checkboxContent)
                .strikethrough(block.isChecked, color: PreviewMetrics.mutedColor)
                .foregroundStyle(block.isChecked ? PreviewMetrics.mutedColor : PreviewMetrics.bodyColor)
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
        richText(
            block.content,
            fallback: block.plainText,
            fontSize: PreviewMetrics.bodyFontSize,
            baseColor: Color(red: 0.2, green: 0.2, blue: 0.2)  // #333333
        )
            .padding(.leading, PreviewMetrics.quoteBorderWidth + PreviewMetrics.quoteTextInset)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(PreviewMetrics.quoteBorderColor)
                    .frame(width: PreviewMetrics.quoteBorderWidth)
            }
            .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    // MARK: Code

    private var codeView: some View {
        richText(
            block.content,
            fallback: block.plainText,
            fontSize: PreviewMetrics.codeFontSize,
            baseColor: PreviewMetrics.codeColor,
            forceMonospace: true,
            lineHeight: 1.4  // 代码块使用更紧凑的行高
        )
            .padding(.horizontal, PreviewMetrics.tableCellHPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: PreviewMetrics.blockRadius).fill(PreviewMetrics.codeBackgroundColor))
            .padding(.vertical, PreviewMetrics.blockVPadding)
    }

    // MARK: Divider

    private var dividerView: some View {
        Rectangle()
            .fill(PreviewMetrics.dividerColor)
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
                            PreviewRichText(
                                fragments: cell.content.flatMap(\.fragments),
                                fallback: cell.content.map(\.plainText).joined(),
                                fontSize: PreviewMetrics.bodyFontSize,
                                baseWeight: isHeader ? .bold : .regular,  // 表头使用 bold (700)
                                baseColor: PreviewMetrics.bodyColor  // 所有单元格使用相同颜色
                            )
                                .padding(.horizontal, PreviewMetrics.tableCellHPadding)
                                .padding(.vertical, PreviewMetrics.tableCellVPadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if rowIndex < tc.rows.count - 1 {
                            Rectangle().fill(PreviewMetrics.tableBorderColor).frame(height: 1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(PreviewMetrics.tableBorderColor, lineWidth: 1))
            .padding(.vertical, PreviewMetrics.blockVPadding)
        )
    }

    // MARK: Helpers

    private func bodyText(_ content: PreviewContent?) -> some View {
        richText(
            content,
            fallback: block.plainText,
            fontSize: PreviewMetrics.bodyFontSize,
            baseColor: block.textColor ?? PreviewMetrics.bodyColor
        )
    }

    private func richText(
        _ content: PreviewContent?,
        fallback: String,
        fontSize: CGFloat,
        baseWeight: Font.Weight = .regular,
        baseColor: Color,
        forceMonospace: Bool = false,
        lineHeight: CGFloat? = nil
    ) -> some View {
        PreviewRichText(
            fragments: content?.fragments ?? [],
            fallback: fallback,
            fontSize: fontSize,
            baseWeight: baseWeight,
            baseColor: baseColor,
            forceMonospace: forceMonospace,
            lineHeight: lineHeight
        )
    }
}

// MARK: - Rich Inline Text

private struct PreviewRichText: View {
    let fragments: [PreviewTextFragment]
    let fallback: String
    let fontSize: CGFloat
    var baseWeight: Font.Weight = .regular
    var baseColor: Color = PreviewMetrics.bodyColor
    var forceMonospace = false
    var lineHeight: CGFloat?

    var body: some View {
        // 精确计算 lineSpacing：
        // CSS line-height 1.65：单行 = fontSize * 1.65
        // SwiftUI：n行 = n*fontSize + (n-1)*spacing
        // 理论值 spacing = fontSize * 0.65，但实测需要微调
        // 微调系数 0.608 比理论值 0.65 更接近实际渲染效果
        let spacing = fontSize * 0.608

        return composedText
            .lineSpacing(spacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var composedText: Text {
        let visibleFragments = fragments.isEmpty
            ? [PreviewTextFragment(text: fallback.isEmpty ? " " : fallback)]
            : fragments
        return visibleFragments.reduce(Text("")) { partial, fragment in
            partial + styledText(fragment)
        }
    }

    private func styledText(_ fragment: PreviewTextFragment) -> Text {
        let isMono = forceMonospace || fragment.isCode
        let fontName: String
        if isMono {
            fontName = "Menlo"
        } else if fragment.isBold {
            fontName = "Avenir Next Demi Bold"
        } else {
            switch baseWeight {
            case .bold: fontName = "Avenir Next Bold"
            case .medium: fontName = "Avenir Next Medium"
            default: fontName = "Avenir Next"
            }
        }
        var text = Text(fragment.text.isEmpty ? " " : fragment.text)
            .font(.custom(fontName, size: fontSize))
            .foregroundColor(fragment.textColor ?? baseColor)

        if fragment.isItalic {
            text = text.italic()
        }
        if fragment.isUnderline || fragment.linkURL != nil {
            text = text.underline()
        }
        if fragment.isStrikethrough {
            text = text.strikethrough()
        }
        if fragment.linkURL != nil {
            text = text.foregroundColor(AgendaColor.amber)
        }
        return text
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
                    .frame(maxWidth: .infinity, maxHeight: PreviewMetrics.mediaMaxHeight, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: PreviewMetrics.blockRadius))

                if block.hasVisibleImageLabel {
                    Text(block.imageLabel)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(PreviewMetrics.mutedColor)
                        .lineLimit(2)
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.custom("Avenir Next Medium", size: 14))
                    .foregroundStyle(AgendaColor.amber)
                Text(block.imageLabel)
                    .font(.custom("Avenir Next", size: PreviewMetrics.bodyFontSize))
                    .foregroundStyle(PreviewMetrics.mutedColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, PreviewMetrics.tableCellHPadding)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: PreviewMetrics.blockRadius).fill(PreviewMetrics.codeBackgroundColor))
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

    var checkboxContent: PreviewContent {
        .text(checkboxText)
    }

    var isChecked: Bool {
        if let checked = props?["checked"]?.boolValue { return checked }
        return plainText.range(of: #"^\s*[-*]?\s*\[[xX]\]"#, options: .regularExpression) != nil
    }

    var headingLevel: Int {
        props?["level"]?.intValue ?? 2
    }

    var textColor: Color? {
        PreviewCSSColor.color(from: props?["textColor"]?.stringValue)
    }

    var backgroundColor: Color? {
        PreviewCSSColor.color(from: props?["backgroundColor"]?.stringValue)
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
        // 所有 block 都要显示，包括空段落和空列表项
        return false
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

    var fragments: [PreviewTextFragment] {
        switch self {
        case .text(let value):
            return [PreviewTextFragment(text: value)]
        case .inline(let items):
            return items.flatMap(\.fragments)
        case .tableContent(let tc):
            return tc.rows.flatMap { row in
                row.cells.flatMap { cell in cell.content.flatMap(\.fragments) }
            }
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
    var href: String?
    var url: String?
    var styles: [String: PreviewJSONValue]?
    var props: [String: PreviewJSONValue]?

    enum CodingKeys: String, CodingKey {
        case type, text, content, href, url, styles, props
    }

    var plainText: String {
        if let text { return text }
        return content?.map(\.plainText).joined() ?? ""
    }

    var fragments: [PreviewTextFragment] {
        if let text {
            return [PreviewTextFragment(
                text: text,
                styles: styles,
                linkURL: linkURL
            )]
        }
        return content?.flatMap { child in
            child.fragments.map { fragment in
                fragment.merging(parentStyles: styles, parentLinkURL: linkURL)
            }
        } ?? []
    }

    private var linkURL: URL? {
        let raw = href ?? url ?? props?["href"]?.stringValue ?? props?["url"]?.stringValue
        guard type == "link" || raw != nil, let raw, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}

private struct PreviewTextFragment {
    var text: String
    var styles: [String: PreviewJSONValue]? = nil
    var linkURL: URL? = nil

    var isBold: Bool { boolStyle("bold") }
    var isItalic: Bool { boolStyle("italic") }
    var isUnderline: Bool { boolStyle("underline") }
    var isStrikethrough: Bool { boolStyle("strike") || boolStyle("strikethrough") }
    var isCode: Bool { boolStyle("code") }

    var textColor: Color? {
        PreviewCSSColor.color(from: stringStyle("textColor") ?? stringStyle("color"))
    }

    func merging(parentStyles: [String: PreviewJSONValue]?, parentLinkURL: URL?) -> PreviewTextFragment {
        var merged = parentStyles ?? [:]
        styles?.forEach { key, value in merged[key] = value }
        return PreviewTextFragment(text: text, styles: merged.isEmpty ? nil : merged, linkURL: linkURL ?? parentLinkURL)
    }

    private func boolStyle(_ key: String) -> Bool {
        styles?[key]?.boolValue ?? false
    }

    private func stringStyle(_ key: String) -> String? {
        styles?[key]?.stringValue
    }
}

private enum PreviewCSSColor {
    static func color(from rawValue: String?) -> Color? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false, value.lowercased() != "default" else { return nil }

        if value.hasPrefix("#") {
            return color(fromHex: String(value.dropFirst()))
        }
        if value.lowercased().hasPrefix("rgb") {
            return color(fromRGBFunction: value)
        }
        return namedColor(value)
    }

    private static func color(fromHex hex: String) -> Color? {
        let expanded: String
        if hex.count == 3 {
            expanded = hex.map { "\($0)\($0)" }.joined()
        } else {
            expanded = hex
        }
        guard expanded.count == 6, let intValue = Int(expanded, radix: 16) else { return nil }
        let red = Double((intValue >> 16) & 0xff) / 255
        let green = Double((intValue >> 8) & 0xff) / 255
        let blue = Double(intValue & 0xff) / 255
        return Color(red: red, green: green, blue: blue)
    }

    private static func color(fromRGBFunction value: String) -> Color? {
        let numbers = value
            .replacingOccurrences(of: #"rgba?\("#, with: "", options: .regularExpression)
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard numbers.count >= 3 else { return nil }
        return Color(red: numbers[0] / 255, green: numbers[1] / 255, blue: numbers[2] / 255)
    }

    private static func namedColor(_ value: String) -> Color? {
        switch value.lowercased() {
        case "red": return Color(red: 0.95, green: 0.35, blue: 0.35)
        case "green": return Color(red: 0.28, green: 0.68, blue: 0.45)
        case "blue": return Color(red: 0.26, green: 0.56, blue: 0.95)
        case "yellow": return Color(red: 0.95, green: 0.80, blue: 0.15)
        case "brown": return Color(red: 0.65, green: 0.45, blue: 0.30)
        case "pink": return Color(red: 0.93, green: 0.36, blue: 0.62)
        case "purple": return Color(red: 0.62, green: 0.35, blue: 0.85)
        case "gray": return Color(red: 0.55, green: 0.55, blue: 0.60)
        default: return nil
        }
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
