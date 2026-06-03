#!/usr/bin/env swift

// Static Analysis Script for Agendada Performance Issues
// Usage: swift StaticAnalysis.swift <project-root>

import Foundation

// MARK: - Analysis Rules

struct Issue {
    let file: String
    let line: Int
    let severity: Severity
    let category: Category
    let message: String
    let fix: String?

    enum Severity: String {
        case critical = "🔴 CRITICAL"
        case warning = "⚠️ WARNING"
        case info = "ℹ️ INFO"
    }

    enum Category: String {
        case mainThread = "MainThread"
        case memory = "Memory"
        case ui = "UIPerformance"
        case cascade = "CascadeUpdate"
        case task = "TaskLeak"
    }
}

class Analyzer {
    private var issues: [Issue] = []
    private let projectRoot: String

    init(projectRoot: String) {
        self.projectRoot = projectRoot
    }

    // MARK: - Rule 1: Main Thread Blocking Operations

    func checkMainThreadBlocking(file: String, lines: [String]) {
        let criticalFunctions = [
            "JSONEncoder().encode",
            "JSONDecoder().decode",
            "Data.write",
            "Data.read",
            "FileHandle.write",
            "FileManager.copyItem",
            "FileManager.removeItem",
            "snapshot()",
            "NSRegularExpression",
            "String.range(of:options:range:)"
        ]

        for (index, line) in lines.enumerated() {
            // Check if we're inside a @MainActor context
            let prevLines = Array(lines.prefix(index).suffix(10))
            let isMainActorContext = prevLines.contains { $0.contains("@MainActor") }

            guard isMainActorContext else { continue }

            // Skip Task blocks (they're already async)
            if line.contains("Task {") || line.contains("Task {") { continue }

            for funcName in criticalFunctions {
                if line.contains(funcName) && !line.trimmingCharacters(in: .whitespaces).starts(with: "//") {
                    issues.append(Issue(
                        file: file,
                        line: index + 1,
                        severity: .warning,
                        category: .mainThread,
                        message: "Potential main-thread blocking: \(funcName)",
                        fix: "Move to Task { await ... } or background actor"
                    ))
                }
            }
        }
    }

    // MARK: - Rule 2: Global State Invalidation

    func checkGlobalInvalidation(file: String, lines: [String]) {
        let patterns = [
            ("publishChange()", "每次状态变化都触发全局刷新"),
            ("revision &+", "revision 递增触发所有观察者刷新"),
            ("invalidateFilteredNotesCache()", "缓存失效导致 filteredNotes() 重新计算")
        ]

        for (index, line) in lines.enumerated() {
            for (pattern, message) in patterns {
                if line.contains(pattern) {
                    issues.append(Issue(
                        file: file,
                        line: index + 1,
                        severity: .warning,
                        category: .cascade,
                        message: message,
                        fix: "考虑使用精细化的观察者模式"
                    ))
                }
            }
        }
    }

    // MARK: - Rule 3: Unbounded Growth Patterns

    func checkUnboundedGrowth(file: String, lines: [String]) {
        // Find var declarations
        for (index, line) in lines.enumerated() {
            if line.contains("var ") && (line.contains(": [") || line.contains(": Set")) {
                let varName = extractVariableName(from: line)

                // Check if this collection ever gets cleaned
                let subsequentLines = Array(lines.suffix(from: index + 1).prefix(50))
                let hasCleanup = subsequentLines.contains { l in
                    l.contains("\(varName).remove") ||
                    l.contains("\(varName) = ") ||
                    l.contains("\(varName).removeAll")
                }

                if !hasCleanup {
                    issues.append(Issue(
                        file: file,
                        line: index + 1,
                        severity: .info,
                        category: .memory,
                        message: "潜在无限增长的集合: \(varName)",
                        fix: "添加清理逻辑或限制最大大小"
                    ))
                }
            }
        }
    }

    // MARK: - Rule 4: Task Management

    func checkTaskManagement(file: String, lines: [String]) {
        for (index, line) in lines.enumerated() {
            // Check for Task creation without cancellation
            if line.contains("Task") && line.contains("=") {
                let varName = extractVariableName(from: line)

                // Look ahead to see if cancel() is called before creating new one
                let prevLines = Array(lines.prefix(index).suffix(5))
                let hasCancel = prevLines.contains { $0.contains("cancel()") }

                if !hasCancel && !line.contains("?") {
                    issues.append(Issue(
                        file: file,
                        line: index + 1,
                        severity: .warning,
                        category: .task,
                        message: "Task 可能未在重新赋值前取消",
                        fix: "添加 \(varName)?.cancel()"
                    ))
                }
            }
        }
    }

    // MARK: - Rule 5: ForEach with Unstable IDs

    func checkForEachStability(file: String, lines: [String]) {
        for (index, line) in lines.enumerated() {
            if line.contains("ForEach") && !line.contains(".id:") {
                issues.append(Issue(
                    file: file,
                    line: index + 1,
                    severity: .critical,
                    category: .ui,
                    message: "ForEach 缺少稳定的 ID",
                    fix: "添加 .id: \\.\\.id"
                ))
            }
        }
    }

    // MARK: - Rule 6: Frequent Body Evaluations

    func checkBodyComputations(file: String, lines: [String]) {
        let expensiveOperations = [
            "filteredNotes()",
            "sorted",
            "filter",
            "reduce",
            "map"
        ]

        var inBody = false
        var bodyIndent = 0

        for (index, line) in lines.enumerated() {
            if line.contains("var body:") {
                inBody = true
                bodyIndent = getIndentLevel(line)
                continue
            }

            if inBody {
                let currentIndent = getIndentLevel(line)
                if currentIndent <= bodyIndent && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    inBody = false
                    continue
                }

                for operation in expensiveOperations {
                    if line.contains(operation) && !line.contains("//") {
                        issues.append(Issue(
                            file: file,
                            line: index + 1,
                            severity: .info,
                            category: .ui,
                            message: "View body 中执行昂贵的操作: \(operation)",
                            fix: "考虑缓存或移到 computed property"
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func extractVariableName(from line: String) -> String {
        let components = line.components(separatedBy: "=")
        guard let lhs = components.first else { return "" }
        let varPart = lhs.trimmingCharacters(in: .whitespaces)
        return varPart.components(separatedBy: " ").last ?? ""
    }

    private func getIndentLevel(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " || char == "\t" {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    // MARK: - Run Analysis

    func run() {
        let sourcesPath = "\(projectRoot)/Sources"

        guard let enumerator = FileManager.default.enumerator(atPath: sourcesPath) else {
            print("❌ Cannot enumerate Sources directory")
            return
        }

        print("🔍 Scanning \(sourcesPath)...")
        print("")

        for case let file as String in enumerator {
            guard file.hasSuffix(".swift") else { continue }

            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else {
                print("⚠️  Cannot read: \(file)")
                continue
            }

            let lines = content.components(separatedBy: .newlines)
            let relativePath = file.replacingOccurrences(of: projectRoot + "/", with: "")

            checkMainThreadBlocking(file: relativePath, lines: lines)
            checkGlobalInvalidation(file: relativePath, lines: lines)
            checkUnboundedGrowth(file: relativePath, lines: lines)
            checkTaskManagement(file: relativePath, lines: lines)
            checkForEachStability(file: relativePath, lines: lines)
            checkBodyComputations(file: relativePath, lines: lines)
        }

        printResults()
    }

    // MARK: - Report Generation

    func printResults() {
        let grouped = Dictionary(grouping: issues) { $0.category }
        let sortedCategories = grouped.keys.sorted { lhs, rhs in
            let lhsCount = grouped[lhs]?.count ?? 0
            let rhsCount = grouped[rhs]?.count ?? 0
            return lhsCount > rhsCount
        }

        print("╔══════════════════════════════════════════════════════════════╗")
        print("║           AGENDADA STATIC ANALYSIS REPORT                    ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print("")

        print("📊 Summary: \(issues.count) issues found")
        print("")

        for category in sortedCategories {
            let categoryIssues = grouped[category] ?? []
            let icon = getCategoryIcon(category)
            print("\(icon) \(category.rawValue): \(categoryIssues.count) issues")
            print(String(repeating: "─", count: 60))

            for issue in categoryIssues.sorted(by: { $0.line < $1.line }) {
                let severityIcon = getSeverityIcon(issue.severity)
                print("  \(severityIcon) \(issue.file):\(issue.line)")
                print("     → \(issue.message)")
                if let fix = issue.fix {
                    print("     💡 Fix: \(fix)")
                }
                print("")
            }
            print("")
        }

        print("═══════════════════════════════════════════════════════════════")
        print("Analysis complete!")
    }

    private func getCategoryIcon(_ category: Issue.Category) -> String {
        switch category {
        case .mainThread: return "🧵"
        case .memory: return "💾"
        case .ui: return "🎨"
        case .cascade: return "🔄"
        case .task: return "⚡"
        }
    }

    private func getSeverityIcon(_ severity: Issue.Severity) -> String {
        switch severity {
        case .critical: return "🔴"
        case .warning: return "⚠️ "
        case .info: return "ℹ️ "
        }
    }
}

// MARK: - Main

if CommandLine.arguments.count < 2 {
    print("Usage: swift StaticAnalysis.swift <project-root>")
    exit(1)
}

let projectRoot = CommandLine.arguments[1]
let analyzer = Analyzer(projectRoot: projectRoot)
analyzer.run()
