#!/usr/bin/env swift

import Foundation

struct Check {
    let area: String
    let metric: String
    let preview: String
    let editor: String
    let status: String
    let note: String
}

enum ReportError: Error, CustomStringConvertible {
    case missingFile(String)
    case parseFailure(String)

    var description: String {
        switch self {
        case .missingFile(let path):
            return "Missing file: \(path)"
        case .parseFailure(let message):
            return "Parse failure: \(message)"
        }
    }
}

let root = findPackageRoot()
let previewPath = root.appendingPathComponent("Sources/Agendada/BlockNotePreviewView.swift")
let cssPath = root.appendingPathComponent("WebEditor/src/styles.css")

let previewSource = try read(previewPath.path)
let cssSource = try read(cssPath.path)

let preview = PreviewMetrics(source: previewSource)
let css = CSSMetrics(source: cssSource)

let checks: [Check] = [
    numeric("layout", "content leading inset", preview.value("editorLeadingPadding"), css.paddingInlineLeading, tolerance: 0.5, note: "Horizontal start position inside the same overlay frame."),
    numeric("layout", "content trailing inset", preview.value("editorTrailingPadding"), css.paddingInlineTrailing, tolerance: 0.5, note: ""),
    numeric("layout", "nested block indent", preview.value("nestIndent"), css.nestedIndent, tolerance: 0.5, note: ""),
    numeric("text", "body font size", preview.value("bodyFontSize"), css.bodyFontSize, tolerance: 0.1, note: ""),
    numeric("text", "body line-height ratio", preview.value("lineHeight"), css.bodyLineHeight, tolerance: 0.01, note: ""),
    text("text", "font family", preview.fontFamilies, css.fontFamily, note: "Different font stacks change glyph width, wrapping, and measured row height."),
    numeric("paragraph", "block vertical padding", preview.value("blockVPadding"), css.blockPaddingVertical, tolerance: 0.5, note: "SwiftUI applies this on both top and bottom, with an extra first-block top compensation."),
    numeric("paragraph", "lineSpacing coefficient", preview.lineSpacingCoefficient, css.bodyLineHeight.map { $0 - 1 }, tolerance: 0.02, note: "SwiftUI Text lineSpacing is not the same unit as CSS line-height; this is a drift signal, not a direct pixel equivalence."),
    numeric("heading", "H1 font size", preview.value("heading1Size"), css.heading1FontSize, tolerance: 0.5, note: ""),
    numeric("heading", "H2 font size", preview.value("heading2Size"), css.heading2FontSize, tolerance: 0.5, note: ""),
    numeric("heading", "H3 font size", preview.value("heading3Size"), css.heading3FontSize, tolerance: 0.5, note: ""),
    numeric("heading", "H1 top padding", preview.value("heading1TopPadding"), css.headingTopPadding, tolerance: 0.5, note: "CSS currently declares 3px for all heading blocks."),
    numeric("heading", "heading bottom padding", preview.value("headingVPadding"), css.blockPaddingVertical, tolerance: 0.5, note: ""),
    numeric("list", "marker column width", preview.value("markerWidth"), css.markerWidth, tolerance: 0.5, note: ""),
    numeric("list", "checkbox visual size", preview.value("bodyFontSize"), css.checkboxSize, tolerance: 0.5, note: "Preview uses SF Symbol font size, editor uses input width/height."),
    numeric("quote", "border width", preview.value("quoteBorderWidth"), css.quoteBorderWidth, tolerance: 0.5, note: ""),
    numeric("quote", "text inset", preview.value("quoteTextInset"), css.quoteInset, tolerance: 0.5, note: ""),
    numeric("code", "font size", preview.value("codeFontSize"), nil, tolerance: 0.5, note: "Editor CSS does not pin code block font-size; BlockNote/theme default decides it."),
    numeric("code", "horizontal padding", preview.value("tableCellHPadding"), css.codePaddingHorizontal, tolerance: 0.5, note: ""),
    numeric("code", "vertical padding", 8, css.codePaddingVertical, tolerance: 0.5, note: ""),
    numeric("code", "corner radius", preview.value("blockRadius"), css.codeRadius, tolerance: 0.5, note: ""),
    numeric("code", "requested line-height", preview.codeLineHeightArgument, nil, tolerance: 0.01, note: preview.usesLineHeightParameter ? "Applied by PreviewRichText." : "Preview passes lineHeight: 1.4, but PreviewRichText ignores the parameter."),
    numeric("divider", "rule thickness", 1, css.dividerThickness, tolerance: 0.1, note: ""),
    numeric("divider", "vertical margin/padding", 10, css.dividerMarginVertical, tolerance: 0.5, note: ""),
    numeric("table", "cell horizontal padding", preview.value("tableCellHPadding"), css.tableCellPaddingHorizontal, tolerance: 0.5, note: "Editor table cells are governed by BlockNote table CSS unless explicitly overridden."),
    numeric("table", "cell vertical padding", preview.value("tableCellVPadding"), css.tableCellPaddingVertical, tolerance: 0.5, note: "Editor table cells are governed by BlockNote table CSS unless explicitly overridden."),
    text("table", "column width model", "equal flexible SwiftUI columns", "BlockNote table layout/default column widths", note: "Preview uses maxWidth infinity for each cell; editor may preserve table column sizing."),
    text("inline", "background highlight padding", preview.inlineBackgroundSummary, "1px 3px with 3px radius", note: "CSS highlight adds padding and rounded clone decoration; preview needs the same visual box model to match wrapping."),
    text("inline", "link decoration", "amber + underline", "BlockNote/theme link style", note: "Editor CSS does not explicitly mirror preview link color."),
    text("media", "image max height", "\(format(preview.value("mediaMaxHeight")))px", "not pinned in editor CSS", note: "Preview caps images at 260px; editor media sizing comes from BlockNote."),
]

print("Agendada card preview vs editor style parity report")
print("Root: \(root.path)")
print("Preview: \(previewPath.path)")
print("Editor CSS: \(cssPath.path)")
print("")

let statusOrder = ["DIFF": 0, "GAP": 1, "MATCH": 2]
for check in checks.sorted(by: { lhs, rhs in
    if lhs.area != rhs.area { return lhs.area < rhs.area }
    return (statusOrder[lhs.status] ?? 9) < (statusOrder[rhs.status] ?? 9)
}) {
    print("[\(check.status)] \(check.area) / \(check.metric)")
    print("  preview: \(check.preview)")
    print("  editor:  \(check.editor)")
    if !check.note.isEmpty {
        print("  note:    \(check.note)")
    }
}

let counts = Dictionary(grouping: checks, by: \.status).mapValues(\.count)
print("")
print("Summary: \(counts["MATCH", default: 0]) match, \(counts["DIFF", default: 0]) differ, \(counts["GAP", default: 0]) have missing or non-comparable data.")

func findPackageRoot() -> URL {
    var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while url.path != "/" {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return url
        }
        url.deleteLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

func read(_ path: String) throws -> String {
    guard FileManager.default.fileExists(atPath: path) else {
        throw ReportError.missingFile(path)
    }
    return try String(contentsOfFile: path, encoding: .utf8)
}

func numeric(_ area: String, _ metric: String, _ preview: Double?, _ editor: Double?, tolerance: Double, note: String) -> Check {
    let status: String
    if let preview, let editor {
        status = abs(preview - editor) <= tolerance ? "MATCH" : "DIFF"
    } else {
        status = "GAP"
    }
    return Check(
        area: area,
        metric: metric,
        preview: preview.map { "\(format($0))px" } ?? "not pinned",
        editor: editor.map { "\(format($0))px" } ?? "not pinned",
        status: status,
        note: note
    )
}

func text(_ area: String, _ metric: String, _ preview: String, _ editor: String, note: String) -> Check {
    Check(
        area: area,
        metric: metric,
        preview: preview,
        editor: editor,
        status: preview == editor ? "MATCH" : "DIFF",
        note: note
    )
}

func format(_ value: Double?) -> String {
    guard let value else { return "nil" }
    if abs(value.rounded() - value) < 0.0001 {
        return String(Int(value.rounded()))
    }
    return String(format: "%.2f", value)
}

struct PreviewMetrics {
    let source: String

    func value(_ name: String) -> Double? {
        let pattern = #"static\s+let\s+\#(name)\s*:\s*CGFloat\s*=\s*([0-9]+(?:\.[0-9]+)?)"#
        return firstNumber(pattern)
    }

    var lineSpacingCoefficient: Double? {
        let values = numbers(#"size\s*\*\s*([0-9]+(?:\.[0-9]+)?)"#)
        return values.last
    }

    var codeLineHeightArgument: Double? {
        firstNumber(#"forceMonospace:\s*true,[\s\S]*?lineHeight:\s*([0-9]+(?:\.[0-9]+)?)"#)
    }

    var usesLineHeightParameter: Bool {
        guard let bodyRange = source.range(of: "var body: some View"),
              let composedRange = source.range(of: "return composedText", range: bodyRange.upperBound..<source.endIndex) else {
            return false
        }
        let bodySnippet = String(source[bodyRange.lowerBound..<composedRange.upperBound])
        return bodySnippet.contains("lineHeight") && !bodySnippet.contains("let spacing = fontSize * 0.608")
    }

    var fontFamilies: String {
        let names = matches(#"\.custom\("([^"]+)""#)
        return Array(Set(names)).sorted().joined(separator: ", ")
    }

    var inlineBackgroundSummary: String {
        guard source.contains("fragment.backgroundColor") else {
            return "not rendered on inline fragments"
        }
        if source.contains("as? Text ?? text") {
            return "attempted background, no CSS padding/radius; cast fallback may drop it"
        }
        return "backgroundColor rendered, no explicit CSS padding/radius"
    }

    private func firstNumber(_ pattern: String) -> Double? {
        numbers(pattern).first
    }

    private func numbers(_ pattern: String) -> [Double] {
        let regex = regex(pattern)
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: source) else {
                return nil
            }
            return Double(source[range])
        }
    }

    private func matches(_ pattern: String) -> [(String)] {
        let regex = regex(pattern)
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: source) else {
                return nil
            }
            return String(source[range])
        }
    }
}

struct CSSMetrics {
    let source: String

    var fontFamily: String {
        property("html,\nbody,\n#root", "font-family") ?? "not pinned"
    }

    var bodyFontSize: Double? {
        pxProperty(".bn-editor", "font-size")
    }

    var bodyLineHeight: Double? {
        numberProperty(".bn-editor", "line-height")
    }

    var paddingInlineLeading: Double? {
        paddingInline?.0
    }

    var paddingInlineTrailing: Double? {
        paddingInline?.1
    }

    var blockPaddingVertical: Double? {
        paddingPair(selector: ".bn-block-content", property: "padding")?.vertical
    }

    var nestedIndent: Double? {
        pxProperty(".bn-block-group .bn-block-group", "margin-left")
    }

    var markerWidth: Double? {
        firstPx(in: property(#".bn-block-content[data-content-type="bulletListItem"]::before,\n.bn-block-content[data-content-type="numberedListItem"]::before"#, "flex"))
            ?? pxProperty(#".bn-block-content[data-content-type="bulletListItem"]::before,\n.bn-block-content[data-content-type="numberedListItem"]::before"#, "min-width")
    }

    var checkboxSize: Double? {
        pxProperty(#".bn-block-content[data-content-type="checkListItem"] input[type="checkbox"]"#, "width")
    }

    var headingTopPadding: Double? {
        pxProperty(#".bn-block-content[data-content-type="heading"]"#, "padding-top")
    }

    var heading1FontSize: Double? {
        pxCustomProperty(#".bn-block-content[data-content-type="heading"][data-level="1"]"#, "--level")
    }

    var heading2FontSize: Double? {
        pxCustomProperty(#".bn-block-content[data-content-type="heading"]"#, "--level")
    }

    var heading3FontSize: Double? {
        pxCustomProperty(#".bn-block-content[data-content-type="heading"][data-level="3"]"#, "--level")
    }

    var quoteBorderWidth: Double? {
        firstPx(in: property(#".bn-block-content[data-content-type="quote"] blockquote"#, "border-left"))
    }

    var quoteInset: Double? {
        pxProperty(#".bn-block-content[data-content-type="quote"] blockquote"#, "padding-left")
    }

    var codePaddingVertical: Double? {
        paddingPair(selector: #".bn-block-content[data-content-type="codeBlock"] > pre"#, property: "padding")?.vertical
    }

    var codePaddingHorizontal: Double? {
        paddingPair(selector: #".bn-block-content[data-content-type="codeBlock"] > pre"#, property: "padding")?.horizontal
    }

    var codeRadius: Double? {
        pxProperty(#".bn-block-content[data-content-type="codeBlock"]"#, "border-radius")
    }

    var dividerThickness: Double? {
        firstPx(in: property(#".bn-block-content[data-content-type="divider"] hr"#, "border-top"))
    }

    var dividerMarginVertical: Double? {
        paddingPair(selector: #".bn-block-content[data-content-type="divider"] hr"#, property: "margin")?.vertical
    }

    var tableCellPaddingVertical: Double? {
        nil
    }

    var tableCellPaddingHorizontal: Double? {
        nil
    }

    private var paddingInline: (Double, Double)? {
        guard let value = property(".bn-editor", "padding-inline") else { return nil }
        let parts = value.split(separator: " ").compactMap { firstPx(in: String($0)) }
        if parts.count == 2 { return (parts[0], parts[1]) }
        if parts.count == 1 { return (parts[0], parts[0]) }
        return nil
    }

    private func pxProperty(_ selector: String, _ name: String) -> Double? {
        property(selector, name).flatMap(firstPx(in:))
    }

    private func numberProperty(_ selector: String, _ name: String) -> Double? {
        guard let value = property(selector, name) else { return nil }
        return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func pxCustomProperty(_ selector: String, _ name: String) -> Double? {
        pxProperty(selector, name)
    }

    private func paddingPair(selector: String, property propertyName: String) -> (vertical: Double, horizontal: Double)? {
        guard let value = property(selector, propertyName) else { return nil }
        let parts = value.split(separator: " ").compactMap { firstPx(in: String($0)) }
        if parts.count == 2 { return (parts[0], parts[1]) }
        if parts.count == 1 { return (parts[0], parts[0]) }
        return nil
    }

    private func property(_ selector: String, _ name: String) -> String? {
        let pattern = #"(?m)^\s*\#(NSRegularExpression.escapedPattern(for: name))\s*:\s*([^;]+);"#
        for block in blocks(for: selector) {
            if let match = regex(pattern).firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: block) {
                return String(block[range]).replacingOccurrences(of: "!important", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func blocks(for selector: String) -> [String] {
        let escaped = NSRegularExpression.escapedPattern(for: selector)
        let exactPattern = #"(?s)(?:^|\n)\s*\#(escaped)\s*\{(.*?)\n\}"#
        let exactBlocks = regex(exactPattern)
            .matches(in: source, range: NSRange(source.startIndex..., in: source))
            .compactMap { match -> String? in
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: source) else {
                    return nil
                }
                return String(source[range])
            }
        if !exactBlocks.isEmpty {
            return exactBlocks
        }

        let fallbackPattern = #"(?s)\#(escaped)\s*\{(.*?)\}"#
        return regex(fallbackPattern)
            .matches(in: source, range: NSRange(source.startIndex..., in: source))
            .compactMap { match -> String? in
                guard match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: source) else {
                    return nil
                }
                return String(source[range])
            }
    }
}

func firstPx(in value: String?) -> Double? {
    guard let value else { return nil }
    let pattern = #"([0-9]+(?:\.[0-9]+)?)px"#
    guard let match = regex(pattern).firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
          match.numberOfRanges > 1,
          let range = Range(match.range(at: 1), in: value) else {
        return nil
    }
    return Double(value[range])
}

func regex(_ pattern: String) -> NSRegularExpression {
    do {
        return try NSRegularExpression(pattern: pattern)
    } catch {
        fatalError("Invalid regex \(pattern): \(error)")
    }
}
