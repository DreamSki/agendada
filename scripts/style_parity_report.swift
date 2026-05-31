#!/usr/bin/env swift

import AppKit
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
let editorBridgePath = root.appendingPathComponent("Sources/Agendada/BlockNoteCardEditorView.swift")

let previewSource = try read(previewPath.path)
let cssSource = try read(cssPath.path)
let editorBridgeSource = try read(editorBridgePath.path)

let preview = PreviewMetrics(source: previewSource)
let css = CSSMetrics(source: cssSource)
let runtime = RuntimeStyleOverrides(source: editorBridgeSource)

let checks: [Check] = [
    numeric("layout", "content leading inset", preview.value("editorLeadingPadding"), css.paddingInlineLeading, tolerance: 0.5, note: "Horizontal start position inside the same overlay frame."),
    numeric("layout", "content trailing inset", preview.value("editorTrailingPadding"), css.paddingInlineTrailing, tolerance: 0.5, note: ""),
    numeric("layout", "nested block indent", preview.value("nestIndent"), css.nestedIndent, tolerance: 0.5, note: ""),
    numeric("text", "body font size", preview.value("bodyFontSize"), css.bodyFontSize, tolerance: 0.1, note: ""),
    numeric("text", "body line-height ratio", preview.value("lineHeight"), css.bodyLineHeight, tolerance: 0.01, note: ""),
    numeric("text", "body rendered line box", preview.lineBoxHeight(fontSizeName: "bodyFontSize", lineHeight: preview.value("lineHeight"), fontName: "Avenir Next"), css.bodyLineBoxHeight, tolerance: 0.5, note: "Uses AppKit font metrics for the SwiftUI side; catches lineSpacing conversions that look right on paper but render differently."),
    fontFamily("text", "font family", preview.fontFamilies, css.fontFamily),
    numeric("paragraph", "block vertical padding", preview.value("blockVPadding"), css.blockPaddingVertical, tolerance: 0.5, note: "SwiftUI applies this on both top and bottom, with an extra first-block top compensation."),
    numeric("heading", "H1 font size", preview.value("heading1Size"), css.heading1FontSize, tolerance: 0.5, note: ""),
    numeric("heading", "H2 font size", preview.value("heading2Size"), css.heading2FontSize, tolerance: 0.5, note: ""),
    numeric("heading", "H3 font size", preview.value("heading3Size"), css.heading3FontSize, tolerance: 0.5, note: ""),
    numeric("heading", "H1 top padding", preview.value("heading1TopPadding"), css.heading1TopPadding, tolerance: 0.5, note: ""),
    numeric("heading", "heading bottom padding", preview.value("headingVPadding"), css.headingBottomPadding, tolerance: 0.5, note: ""),
    numeric("list", "marker column width", preview.value("markerWidth"), css.markerWidth, tolerance: 0.5, note: ""),
    numeric("list", "checkbox visual size", preview.value("bodyFontSize"), css.checkboxSize, tolerance: 0.5, note: "Preview uses SF Symbol font size, editor uses input width/height."),
    numeric("quote", "border width", preview.value("quoteBorderWidth"), css.quoteBorderWidth, tolerance: 0.5, note: ""),
    numeric("quote", "text inset", preview.value("quoteTextInset"), css.quoteInset, tolerance: 0.5, note: ""),
    numeric("code", "font size", preview.value("codeFontSize"), css.codeFontSize, tolerance: 0.5, note: ""),
    numeric("code", "horizontal padding", preview.value("tableCellHPadding"), css.codePaddingHorizontal, tolerance: 0.5, note: ""),
    numeric("code", "vertical padding", 8, css.codePaddingVertical, tolerance: 0.5, note: ""),
    numeric("code", "corner radius", preview.value("blockRadius"), css.codeRadius, tolerance: 0.5, note: ""),
    numeric("code", "requested line-height", preview.codeLineHeightArgument, css.codeLineHeight, tolerance: 0.01, note: preview.usesLineHeightParameter ? "Applied by PreviewRichText." : "Preview passes lineHeight: 1.4, but PreviewRichText ignores the parameter."),
    numeric("code", "rendered line box", preview.lineBoxHeight(fontSizeName: "codeFontSize", lineHeight: preview.codeLineHeightArgument, fontName: "Menlo"), css.codeLineBoxHeight, tolerance: 0.5, note: "Uses AppKit metrics for Menlo in the SwiftUI preview."),
    numeric("divider", "rule thickness", 1, css.dividerThickness, tolerance: 0.1, note: ""),
    numeric("divider", "vertical margin/padding", 10, css.dividerMarginVertical, tolerance: 0.5, note: ""),
    numeric("table", "cell horizontal padding", preview.value("tableCellHPadding"), css.tableCellPaddingHorizontal, tolerance: 0.5, note: "Editor table cells are governed by BlockNote table CSS unless explicitly overridden."),
    numeric("table", "cell vertical padding", preview.value("tableCellVPadding"), css.tableCellPaddingVertical, tolerance: 0.5, note: "Editor table cells are governed by BlockNote table CSS unless explicitly overridden."),
    text("table", "column width model", "equal flexible/full-width columns", css.tableColumnModel, note: ""),
    text("inline", "background highlight padding", preview.inlineBackgroundSummary, css.inlineBackgroundSummary, note: ""),
    text("inline", "link decoration", "amber + underline", css.linkDecorationSummary, note: ""),
    numeric("media", "image max height", preview.value("mediaMaxHeight"), css.mediaMaxHeight, tolerance: 0.5, note: ""),
    text("runtime", "post-load metric overrides", "no editor metric overrides", runtime.editorMetricOverrideSummary, note: "The app injects helper CSS after the editor loads; this catches rules that would override styles.css inside the real WKWebView."),
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

func fontFamily(_ area: String, _ metric: String, _ preview: String, _ editor: String) -> Check {
    let previewPrimary = canonicalPrimaryFont(preview)
    let editorPrimary = canonicalPrimaryFont(editor)
    return Check(
        area: area,
        metric: metric,
        preview: preview,
        editor: editor,
        status: previewPrimary == editorPrimary ? "MATCH" : "DIFF",
        note: previewPrimary == editorPrimary
            ? "Primary family matches; preview uses explicit Avenir Next weight names while editor uses CSS font-weight plus a fallback stack."
            : "Different primary font families change glyph width, wrapping, and measured row height."
    )
}

func canonicalPrimaryFont(_ value: String) -> String {
    let lowercased = value.lowercased()
    if lowercased.contains("avenir next") { return "avenir next" }
    if lowercased.contains("inter") { return "inter" }
    return value
        .split(separator: ",")
        .first
        .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: " \"'").union(.whitespacesAndNewlines)).lowercased() }
        ?? value.lowercased()
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

    func lineBoxHeight(fontSizeName: String, lineHeight: Double?, fontName: String) -> Double? {
        guard let size = value(fontSizeName), let lineHeight else { return nil }
        guard source.contains("naturalLineBox") && source.contains("verticalInset") else {
            return nil
        }
        let font = NSFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        let naturalLineBox = NSLayoutManager().defaultLineHeight(for: font)
        let targetLineBox = size * lineHeight
        let extraLeading = max(0, targetLineBox - naturalLineBox)
        return naturalLineBox + extraLeading
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

struct RuntimeStyleOverrides {
    let source: String

    var editorMetricOverrideSummary: String {
        let css = injectedHelperCSS
        let metricOverrideSignals = [
            ".bn-block-content",
            "data-content-type=\\\"heading\\\"",
            "padding-inline",
            "padding-top:",
            "padding-bottom:",
            "font-size:",
            "line-height:",
            "--level"
        ]
        let hasMetricOverride = metricOverrideSignals.contains { css.contains($0) }
        return hasMetricOverride ? "overrides editor metrics after load" : "no editor metric overrides"
    }

    private var injectedHelperCSS: String {
        guard let start = source.range(of: "styleEl.textContent = `"),
              let end = source.range(
                of: "`;\n          document.head.appendChild(styleEl);",
                range: start.upperBound..<source.endIndex
              ) else {
            return ""
        }
        return String(source[start.upperBound..<end.lowerBound])
    }
}

struct CSSMetrics {
    let source: String

    var fontFamily: String {
        guard let value = property("html,\nbody,\n#root", "font-family") else { return "not pinned" }
        return resolveCSSVariables(in: value)
    }

    var bodyFontSize: Double? {
        pxProperty(".bn-editor", "font-size")
    }

    var bodyLineHeight: Double? {
        numberProperty(".bn-editor", "line-height")
    }

    var bodyLineBoxHeight: Double? {
        guard let fontSize = bodyFontSize, let lineHeight = bodyLineHeight else { return nil }
        return fontSize * lineHeight
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

    var heading1TopPadding: Double? {
        pxProperty(#".bn-block-content[data-content-type="heading"]:has(> h1),\n.bn-block-content[data-content-type="heading"][data-level="1"]"#, "padding-top")
            ?? pxProperty(#".bn-block-content[data-content-type="heading"][data-level="1"]"#, "padding-top")
            ?? headingTopPadding
    }

    var headingBottomPadding: Double? {
        pxProperty(#".bn-block-content[data-content-type="heading"]"#, "padding-bottom")
            ?? blockPaddingVertical
    }

    var heading1FontSize: Double? {
        pxCustomProperty(#".bn-block-content[data-content-type="heading"]:has(> h1),\n.bn-block-content[data-content-type="heading"][data-level="1"]"#, "--level")
            ?? pxCustomProperty(#".bn-block-content[data-content-type="heading"][data-level="1"]"#, "--level")
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

    var codeFontSize: Double? {
        pxProperty(#".bn-block-content[data-content-type="codeBlock"]"#, "font-size")
            ?? pxProperty(#".bn-block-content[data-content-type="codeBlock"] > pre"#, "font-size")
    }

    var codeLineHeight: Double? {
        numberProperty(#".bn-block-content[data-content-type="codeBlock"]"#, "line-height")
            ?? numberProperty(#".bn-block-content[data-content-type="codeBlock"] > pre"#, "line-height")
    }

    var codeLineBoxHeight: Double? {
        guard let fontSize = codeFontSize, let lineHeight = codeLineHeight else { return nil }
        return fontSize * lineHeight
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
        paddingPair(selector: #".bn-editor [data-content-type="table"] th,\n.bn-editor [data-content-type="table"] td"#, property: "padding")?.vertical
    }

    var tableCellPaddingHorizontal: Double? {
        paddingPair(selector: #".bn-editor [data-content-type="table"] th,\n.bn-editor [data-content-type="table"] td"#, property: "padding")?.horizontal
    }

    var tableColumnModel: String {
        let tableLayout = property(#".bn-editor [data-content-type="table"] table"#, "table-layout")
        let width = property(#".bn-editor [data-content-type="table"] table"#, "width")
        if tableLayout == "fixed" && width == "100%" {
            return "equal flexible/full-width columns"
        }
        return "BlockNote table layout/default column widths"
    }

    var inlineBackgroundSummary: String {
        let selector = #"[data-style-type=backgroundColor]:not([data-value="default"])"#
        let padding = property(selector, "padding")
        let radius = property(selector, "border-radius")
        if padding == "0" && radius == "0" {
            return "backgroundColor rendered, no explicit CSS padding/radius"
        }
        return "\(padding ?? "not pinned") with \(radius ?? "not pinned") radius"
    }

    var linkDecorationSummary: String {
        let selector = ".bn-default-styles a,\n.bn-inline-content a"
        let color = property(selector, "color")?.uppercased()
        let decoration = property(selector, "text-decoration")
        if color == "#F5A623" && decoration == "underline" {
            return "amber + underline"
        }
        return "BlockNote/theme link style"
    }

    var mediaMaxHeight: Double? {
        pxProperty(#"[data-file-block] .bn-visual-media"#, "max-height")
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

    private func resolveCSSVariables(in value: String) -> String {
        var resolved = value
        for _ in 0..<5 {
            guard let match = regex(#"var\((--[A-Za-z0-9-]+)\)"#).firstMatch(in: resolved, range: NSRange(resolved.startIndex..., in: resolved)),
                  let fullRange = Range(match.range(at: 0), in: resolved),
                  let nameRange = Range(match.range(at: 1), in: resolved) else {
                break
            }
            let variableName = String(resolved[nameRange])
            guard let variableValue = property(":root", variableName) else { break }
            resolved.replaceSubrange(fullRange, with: variableValue)
        }
        return resolved
    }

    private func blocks(for selector: String) -> [String] {
        let normalizedSelector = selector.replacingOccurrences(of: #"\n"#, with: "\n")
        let escaped = NSRegularExpression.escapedPattern(for: normalizedSelector)
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
    if value.trimmingCharacters(in: .whitespacesAndNewlines) == "0" {
        return 0
    }
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
