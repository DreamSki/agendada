import SwiftUI

// 精准测量工具：测量 SwiftUI 中各元素的实际渲染尺寸
struct StyleMeasurementView: View {
    @State private var measurements: [String: MeasurementResult] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("SwiftUI 样式测量")
                        .font(.title)
                    Spacer()
                    Button("清除缓存") {
                        measurements.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 10)

                // CSS 预期值参考
                GroupBox("CSS 预期值 (styles.css)") {
                    VStack(alignment: .leading, spacing: 4) {
                        cssRow("正文", fontSize: 14, lineHeight: 1.65, padding: 3)
                        cssRow("H1", fontSize: 20, lineHeight: 1.65, padding: 3)
                        cssRow("H2", fontSize: 17, lineHeight: 1.65, padding: 3)
                        cssRow("H3", fontSize: 16, lineHeight: 1.65, padding: 3)
                        cssRow("表格单元格", fontSize: 14, lineHeight: 1.65, padding: 7, paddingH: 10)
                    }
                    .font(.system(.body, design: .monospaced))
                    .font(.system(size: 12))
                }

                // SwiftUI 实测值
                GroupBox("SwiftUI 实测值") {
                    VStack(alignment: .leading, spacing: 8) {
                        measurementItem("段落单行", key: "para_single") {
                            Text("测试文本 Test text")
                                .font(.system(size: 14))
                                .lineSpacing(8.5)
                                .padding(.vertical, 4)
                        }

                        measurementItem("段落多行", key: "para_multi") {
                            Text("这是一段很长的测试文本，用来测量多行文本的实际高度。A long test text to measure multi-line content height.")
                                .font(.system(size: 14))
                                .lineSpacing(8.5)
                                .padding(.vertical, 4)
                                .frame(width: 400, alignment: .leading)
                        }

                        measurementItem("H1", key: "heading_h1") {
                            Text("H1 标题文本")
                                .font(.system(size: 18.5, weight: .bold))
                                .lineSpacing(0)
                                .padding(.top, 4)
                        }

                        measurementItem("H2", key: "heading_h2") {
                            Text("H2 标题文本")
                                .font(.system(size: 15.5, weight: .bold))
                                .lineSpacing(0)
                                .padding(.top, 4)
                        }

                        measurementItem("H3", key: "heading_h3") {
                            Text("H3 标题文本")
                                .font(.system(size: 14.5, weight: .bold))
                                .lineSpacing(0)
                                .padding(.top, 4)
                        }

                        measurementItem("表格单元格(单行)", key: "table_cell_single") {
                            Text("单元格文本")
                                .font(.system(size: 14))
                                .lineSpacing(8.5)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }

                        measurementItem("表格单元格(多行)", key: "table_cell_multi") {
                            Text("第一行文本\n第二行文本")
                                .font(.system(size: 14))
                                .lineSpacing(8.5)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(width: 150, alignment: .leading)
                        }
                    }
                }

                // 对比结果
                if !measurements.isEmpty {
                    GroupBox("对比分析") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(sortedKeys, id: \.self) { key in
                                if let result = measurements[key] {
                                    comparisonRow(key: key, result: result)
                                }
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                        .font(.system(size: 11))
                    }
                }

                // 推荐参数
                GroupBox("推荐 PreviewMetrics 参数") {
                    VStack(alignment: .leading, spacing: 4) {
                        codeLine("static let bodyFontSize: CGFloat = 14")
                        codeLine("static let lineHeight: CGFloat = 1.65")
                        codeLine("static let blockVPadding: CGFloat = 4  // 段间距")
                        codeLine("static let heading1Size: CGFloat = 18.5  // H1")
                        codeLine("static let heading2Size: CGFloat = 15.5  // H2")
                        codeLine("static let heading3Size: CGFloat = 14.5  // H3")
                        codeLine("static let tableCellVPadding: CGFloat = 8  // 表格")
                        Divider()
                        codeLine("// lineSpacing 计算:")
                        codeLine("func lineSpacing(for size: CGFloat) -> CGFloat {")
                        codeLine("    return size * 0.608  // 1.65 - 1.042(默认行高)")
                        codeLine("}")
                    }
                    .font(.system(.body, design: .monospaced))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .frame(width: 650, height: 750)
    }

    var sortedKeys: [String] {
        measurements.keys.sorted()
    }

    func cssRow(_ name: String, fontSize: CGFloat, lineHeight: CGFloat, padding: CGFloat, paddingV: CGFloat? = nil, paddingH: CGFloat? = nil) -> some View {
        let pv = paddingV ?? padding
        let ph = paddingH ?? 0
        let lineH = fontSize * lineHeight
        let totalH = lineH + pv * 2
        return HStack {
            Text(name).frame(width: 80, alignment: .leading)
            Text("fs:\(Int(fontSize))").frame(width: 40)
            Text("lh:\(String(format: "%.2f", lineHeight))").frame(width: 50)
            Text("pd:\(Int(pv))").frame(width: 40)
            Text("总H:\(String(format: "%.1f", totalH))").frame(width: 50)
        }
    }

    func measurementItem<Content: View>(_ title: String, key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: HeightPreferenceKey.self, value: [HeightMeasurement(key: key, height: geo.size.height)])
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        }
        .onPreferenceChange(HeightPreferenceKey.self) { values in
            for item in values {
                measurements[item.key] = MeasurementResult(height: String(format: "%.1f", item.height))
            }
        }
    }

    func comparisonRow(key: String, result: MeasurementResult) -> some View {
        HStack(spacing: 8) {
            Text(key)
                .frame(width: 120, alignment: .leading)
            Text("H: \(result.height)")
                .foregroundStyle(.primary)
        }
    }

    func codeLine(_ text: String) -> some View {
        Text(text)
    }
}

// 测量结果
struct MeasurementResult {
    let height: String
}

// 高度测量值结构
private struct HeightMeasurement: Equatable {
    let key: String
    let height: CGFloat
}

// 用于传递高度测量结果的 PreferenceKey
private struct HeightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [HeightMeasurement] = []

    static func reduce(value: inout [HeightMeasurement], nextValue: () -> [HeightMeasurement]) {
        value.append(contentsOf: nextValue())
    }
}

#Preview {
    StyleMeasurementView()
}
