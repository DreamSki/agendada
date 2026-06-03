import Foundation
import OSLog

/// Runtime performance diagnostics for Agendada.
/// Add calls to this instrument throughout the codebase to track performance.
public enum PerformanceDiagnostics {
    private static let logger = Logger(subsystem: "com.agendada.perf", category: "Diagnostics")

    // MARK: - Configuration

    /// Enable/disable performance tracking.
    public static var isEnabled: Bool = true

    /// Thresholds for warning levels (in seconds)
    public static var thresholds = Thresholds(
        warning: 0.050,      // 50ms
        critical: 0.100,     // 100ms
        catastrophic: 0.500  // 500ms
    )

    public struct Thresholds {
        var warning: TimeInterval
        var critical: TimeInterval
        var catastrophic: TimeInterval
    }

    // MARK: - Call Tracking

    private static var callCounts: [String: Int] = [:]
    private static var lastCallTimes: [String: Date] = [:]

    /// Track a function call. Use at the start of a function to monitor call frequency.
    public static func trackCall(_ function: String, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }

        let key = "\(function):\(file):\(line)"
        callCounts[key, default: 0] += 1
        lastCallTimes[key] = Date()

        // Warn if called more than 100 times in the last second
        let recentCalls = callCounts.values.reduce(0, +)
        if recentCalls > 100 {
            logger.warning("⚠️ High call frequency: \(function) called \(recentCalls) times")
        }
    }

    /// Print call statistics for all tracked functions.
    public static func printCallStats() {
        print("📊 Call Statistics:")
        for (key, count) in callCounts.sorted(by: { $0.value > $1.value }) {
            print("  \(key): \(count) calls")
        }
    }

    /// Reset call tracking.
    public static func resetCallTracking() {
        callCounts.removeAll()
        lastCallTimes.removeAll()
    }

    // MARK: - Execution Timing

    /// Measure the execution time of a synchronous block.
    public static func measure<T>(_ label: String, operation: () throws -> T) rethrows -> T {
        guard isEnabled else { return try operation() }

        let start = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(start)

        logTiming(label: label, duration: duration)
        return result
    }

    /// Measure the execution time of an async block.
    public static func measureAsync<T>(_ label: String, operation: () async throws -> T) async rethrows -> T {
        guard isEnabled else { return try await operation() }

        let start = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)

        await logTimingAsync(label: label, duration: duration)
        return result
    }

    // MARK: - Timing Logging

    private static func logTiming(label: String, duration: TimeInterval) {
        switch duration {
        case 0..<thresholds.warning:
            logger.debug("✅ \(label): \(String(format: "%.2f", duration * 1000))ms")
        case thresholds.warning..<thresholds.critical:
            logger.warning("⚠️ \(label): \(String(format: "%.2f", duration * 1000))ms")
        case thresholds.critical..<thresholds.catastrophic:
            logger.error("🔴 \(label): \(String(format: "%.2f", duration * 1000))ms")
        default:
            logger.critical("💀 \(label): \(String(format: "%.2f", duration * 1000))ms")
        }
    }

    private static func logTimingAsync(label: String, duration: TimeInterval) async {
        logTiming(label: label, duration: duration)
    }

    // MARK: - Stack Trace Analysis

    /// Print the current call stack for debugging.
    public static func printStackTrace() {
        let symbols = Thread.callStackSymbols
        print("📚 Call Stack (last 10 frames):")
        for (index, symbol) in symbols.prefix(10).enumerated() {
            print("  \(index): \(symbol)")
        }
    }

    /// Find who called a specific function.
    public static func printCaller(function: String = #function) {
        let symbols = Thread.callStackSymbols
        guard symbols.count > 2 else { return }

        let caller = symbols[2]  // [0] = printCaller, [1] = calling function, [2] = actual caller
        print("📞 \(function) called from: \(caller)")
    }

    // MARK: - Memory Tracking

    /// Log current memory usage.
    public static func logMemoryUsage(context: String = "") {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Double(info.virtual_size) / 1024.0 / 1024.0

            logger.debug("💾 Memory\(context.isEmpty ? "" : " (\(context))"): \(String(format: "%.1f", usedMB))MB used / \(String(format: "%.1f", totalMB))MB total")
        }
    }

    // MARK: - Specific Instrumentation Points

    /// Instrument a publishChange call to track cascade updates.
    public static func trackPublishChange(caller: String = #function) {
        guard isEnabled else { return }

        printCaller(function: "publishChange")
        trackCall("publishChange")
        logMemoryUsage(context: "after publishChange")
    }

    /// Instrument a filteredNotes call to track cache effectiveness.
    public static func trackFilteredNotesAccess(cacheHit: Bool) {
        guard isEnabled else { return }

        trackCall("filteredNotes")

        if !cacheHit {
            logger.warning("🔄 filteredNotes cache miss - full recalculation")
        }
    }

    /// Instrument a Task creation to detect potential leaks.
    public static func trackTaskCreation(type: String) {
        guard isEnabled else { return }

        trackCall("Task.create[\(type)]")

        // Check if we're creating Tasks too rapidly
        if let lastTime = lastCallTimes["Task.create[\(type)]"] {
            let interval = Date().timeIntervalSince(lastTime)
            if interval < 0.010 {  // 10ms
                logger.warning("⚡ Rapid Task creation: \(type) (\(String(format: "%.1f", interval * 1000))ms apart)")
            }
        }
    }
}

// MARK: - Convenience Macros

/// Measure a block and log if it exceeds the warning threshold.
public func measure<T>(_ label: String, threshold: TimeInterval = 0.050, operation: () throws -> T) rethrows -> T {
    let start = Date()
    let result = try operation()
    let duration = Date().timeIntervalSince(start)

    if duration > threshold {
        print("⚠️ '\(label)' took \(String(format: "%.2f", duration * 1000))ms (threshold: \(String(format: "%.2f", threshold * 1000))ms)")
    }

    return result
}

/// Async version of measure.
public func measureAsync<T>(_ label: String, threshold: TimeInterval = 0.050, operation: () async throws -> T) async rethrows -> T {
    let start = Date()
    let result = try await operation()
    let duration = Date().timeIntervalSince(start)

    if duration > threshold {
        print("⚠️ '\(label)' took \(String(format: "%.2f", duration * 1000))ms (threshold: \(String(format: "%.2f", threshold * 1000))ms)")
    }

    return result
}
