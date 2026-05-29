import SwiftUI

// 样式计算器：基于 CSS 预期值自动计算 SwiftUI 参数
struct StyleCalculator {
    // CSS 预期值（来自编辑器 styles.css）
    struct CSSValues {
        static let bodyFontSize: CGFloat = 14
        static let bodyLineHeight: CGFloat = 1.65
        static let codeFontSize: CGFloat = 13
        static let codeLineHeight: CGFloat = 1.5  // 代码块默认行高
        static let heading1Size: CGFloat = 20
        static let heading2Size: CGFloat = 17
        static let heading3Size: CGFloat = 16
        static let blockPaddingVertical: CGFloat = 3
        static let tableCellPaddingV: CGFloat = 7
        static let tableCellPaddingH: CGFloat = 10
    }

    // 计算 CSS 中的元素总高度（预期值）
    static func cssElementHeight(fontSize: CGFloat, lineHeight: CGFloat, lines: Int = 1, paddingVertical: CGFloat = 0) -> CGFloat {
        let lineTotalHeight = fontSize * lineHeight
        let contentHeight = lineTotalHeight * CGFloat(lines)
        return contentHeight + paddingVertical * 2
    }

    // SwiftUI 中需要的 lineSpacing 值
    // CSS line-height 包含字体本身，SwiftUI lineSpacing 只在行间添加
    static func swiftUILineSpacing(for fontSize: CGFloat, cssLineHeight: CGFloat) -> CGFloat {
        // CSS: 单行高度 = fontSize * lineHeight
        // SwiftUI: 单行高度 ≈ fontSize + 默认行高修正
        // 为了匹配 CSS，我们需要让 n 行高度 = n * fontSize * lineHeight
        // SwiftUI: n 行高度 = n * fontSize + (n-1) * lineSpacing
        // 解得: lineSpacing = fontSize * (lineHeight - 1) * n / (n-1)
        // 当 n 很大时: lineSpacing ≈ fontSize * (lineHeight - 1)

        let baseSpacing = fontSize * (cssLineHeight - 1)
        return baseSpacing
    }

    // 计算准确的 lineSpacing 以匹配 CSS line-height
    // 基于：SwiftUI 默认行高约 fontSize * 1.15-1.18
    static func accurateLineSpacing(for fontSize: CGFloat, cssLineHeight: CGFloat) -> CGFloat {
        let cssLineHeightPx = fontSize * cssLineHeight  // 例如：14 * 1.65 = 23.1
        let swiftUIDefaultLineHeight = fontSize * 1.16  // 估算值
        let difference = cssLineHeightPx - swiftUIDefaultLineHeight
        return max(0, difference)
    }

    // 表格单元格的总高度计算
    static func tableCellHeight(fontSize: CGFloat = 14, lineHeight: CGFloat = 1.65, paddingV: CGFloat = 7) -> CGFloat {
        let lineTotalHeight = fontSize * lineHeight
        return lineTotalHeight + paddingV * 2
    }
}

// 预计算的最佳参数（基于实测调整）
struct OptimizedPreviewMetrics {
    // 基础参数
    static let bodyFontSize: CGFloat = 14
    static let bodyLineHeight: CGFloat = 1.65
    static let codeFontSize: CGFloat = 13

    // 计算得出的 lineSpacing
    // 14px * (1.65 - 1.16) ≈ 7px (SwiftUI 默认行高约 1.16x)
    // 但实测显示需要更大的值来匹配编辑器
    static let bodyLineSpacing: CGFloat = 8.5  // 经过微调

    // 代码块 lineSpacing
    // 13px * (1.5 - 1.16) ≈ 4.4px
    static let codeLineSpacing: CGFloat = 4.5

    // 标题大小（SwiftUI .bold 比 CSS font-weight: 700 渲染更大）
    static let heading1Size: CGFloat = 18.5  // 从 20 调小
    static let heading2Size: CGFloat = 15.5  // 从 17 调小
    static let heading3Size: CGFloat = 14.5  // 从 16 调小

    // 段间距
    static let blockPaddingVertical: CGFloat = 4  // 两个段落之间 = 8px

    // 表格单元格 padding
    static let tableCellPaddingV: CGFloat = 8  // 调整以匹配编辑器
    static let tableCellPaddingH: CGFloat = 10
}
