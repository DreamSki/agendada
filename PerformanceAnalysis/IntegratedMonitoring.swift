import Foundation
import OSLog

/// Drop-in performance monitoring for Agendada.
/// Copy this file into your project and add calls to track performance.
///
/// Usage:
/// 1. Add this file to Sources/Agendada/
/// 2. In ObservableLibraryStore, add:
///    ```swift
///    private func publishChange() {
///        PerfMonitor.trackPublishChange()
///        revision &+= 1
///        invalidateFilteredNotesCache()
///    }
///    ```
/// 3. In critical paths, add:
///    ```swift
///    PerfMonitor.measureStart("operationName")
///    // ... do work
///    PerfMonitor.measureEnd("operationName")
///    ```

@available(macOS 13.0, *)
public final class PerfMonitor {
    private static let logger = Logger(subsystem: "com.agendada", category: "PerfMonitor")

    // MARK: - Configuration

    public static var isEnabled: Bool = true
    public static var logToConsole: Bool = true

    // MARK: - Metrics

    private static var measurements: [String: [TimeInterval]] = [:]
    private static var callCounts: [String: Int] = [:]
    private static var stackDepths: [String: Int] = [:]
    private static var activeTimings: [String: Date] = [:]

    // MARK: - Call Tracking

    /// Track how many times a function is called per second.
    public static func track(_ name: String, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }

        let key = "\(name):\(file):\(line)"
        let count = (callCounts[key] ?? 0) + 1
        callCounts[key] = count

        // Warn if called more than 100 times in the last second
        if count % 100 == 0 {
            logger.warning("🚨 \(name) called \(count) times - possible hot loop")
        }
    }

    /// Track publishChange to detect cascade updates.
    public static func trackPublishChange() {
        guard isEnabled else { return }

        track("publishChange")

        // Log who called publishChange
        let symbols = Thread.callStackSymbols
        if symbols.count > 3 {
            let caller = symbols[3]  // Skip this function + internal frames
            logger.debug("📢 publishChange from: \(caller.prefix(100))")
        }

        // Check if this might be a cascade
        if let lastCall = activeTimings["publishChange_last"],
           Date().timeIntervalSince(lastCall) < 0.016 {
            logger.warning("⚡ Cascade detected: publishChange called within 16ms")
        }
        activeTimings["publishChange_last"] = Date()
    }

    /// Track filteredNotes access to detect cache misses.
    public static func trackFilteredNotes(cacheHit: Bool) {
        guard isEnabled else { return }

        track("filteredNotes")

        if !cacheHit {
            logger.warning("🔄 filteredNotes cache miss - full recalculation")
            track("filteredNotes_cacheMiss")
        } else {
            track("filteredNotes_cacheHit")
        }
    }

    // MARK: - Timing

    /// Begin timing an operation.
    public static func measureStart(_ name: String) {
        guard isEnabled else { return }
        activeTimings[name] = Date()
    }

    /// End timing an operation and log the result.
    public static func measureEnd(_ name: String, threshold: TimeInterval = 0.050) {
        guard isEnabled, let start = activeTimings[name] else { return }
        activeTimings.removeValue(forKey: name)

        let duration = Date().timeIntervalSince(start)
        recordMeasurement(name, duration: duration)

        if duration > threshold {
            let level: OSLogType = duration > 0.100 ? .error : .warning
            logger.log(level: "⏱️ \(name): \(String(format: "%.2f", duration * 1000))ms")
        }
    }

    /// Measure a block of code.
    public static func measure<T>(_ name: String, threshold: TimeInterval = 0.050, operation: () throws -> T) rethrows -> T {
        guard isEnabled else { return try operation() }

        let start = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(start)

        recordMeasurement(name, duration: duration)

        if duration > threshold {
            logger.warning("⏱️ \(name): \(String(format: "%.2f", duration * 1000))ms")
        }

        return result
    }

    // MARK: - Memory Tracking

    /// Track collection growth to detect unbounded growth.
    public static func trackCollectionSize(_ name: String, count: Int) {
        guard isEnabled else { return }

        let key = "collection_size_\(name)"
        let previous = measurements[key]?.last ?? 0

        if count > previous * 2 && count > 100 {
            logger.warning("📈 Collection '\(name)' doubled to \(count) elements")
        }

        // Store as a "measurement" even though it's not a time
        if measurements[key] == nil {
            measurements[key] = []
        }
        measurements[key]?.append(TimeInterval(count))

        // Keep only last 100 measurements
        if let m = measurements[key], m.count > 100 {
            measurements[key] = Array(m.suffix(100))
        }
    }

    /// Log current memory usage.
    public static func logMemoryUsage(context: String = "") {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            logger.debug("💾 Memory\(context.isEmpty ? "" : " (\(context))"): \(String(format: "%.1f", usedMB))MB")
        }
    }

    // MARK: - Statistics

    /// Get statistics for a specific operation.
    public static func stats(for name: String) -> OperationStats? {
        guard let timings = measurements[name], !timings.isEmpty else { return nil }

        let sorted = timings.sorted()
        let count = timings.count
        let total = timings.reduce(0, +)
        let avg = total / Double(count)
        let median = sorted[count / 2]
        let p99 = sorted[Int(Double(count) * 0.99)]
        let max = sorted.last!

        return OperationStats(
            name: name,
            callCount: callCounts[name] ?? 0,
            count: count,
            average: avg,
            median: median,
            p99: p99,
            max: max
        )
    }

    /// Get all statistics sorted by average duration.
    public static func allStats() -> [OperationStats] {
        measurements.keys.compactMap { stats(for: $0) }
            .sorted { $0.average > $1.average }
    }

    /// Print a summary report.
    public static func printSummary() {
        let stats = allStats()

        print("╔══════════════════════════════════════════════════════════════╗")
        print("║                  PERFORMANCE SUMMARY                          ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print("")

        if stats.isEmpty {
            print("No performance data collected.")
            return
        }

        print("📊 Top Operations by Average Duration:")
        print("")

        for stat in stats.prefix(15) {
            let duration = stat.average
            let icon: String
            if duration < 0.010 {
                icon = "✅"
            } else if duration < 0.050 {
                icon = "⚠️ "
            } else if duration < 0.100 {
                icon = "🔴"
            } else {
                icon = "💀"
            }

            print("\(icon) \(stat.name)")
            print("   Calls: \(stat.callCount), Samples: \(stat.count)")
            print("   Avg: \(ms(stat.average))ms, Med: \(ms(stat.median))ms, P99: \(ms(stat.p99))ms, Max: \(ms(stat.max))ms")
            print("")
        }

        print("──────")
        logMemoryUsage()
    }

    /// Reset all measurements.
    public static func reset() {
        measurements.removeAll()
        callCounts.removeAll()
        activeTimings.removeAll()
    }

    // MARK: - Private

    private static func recordMeasurement(_ name: String, duration: TimeInterval) {
        if measurements[name] == nil {
            measurements[name] = []
        }
        measurements[name]?.append(duration)

        // Keep only last 1000 measurements to prevent unbounded growth
        if let m = measurements[name], m.count > 1000 {
            measurements[name] = Array(m.suffix(1000))
        }
    }

    private static func ms(_ seconds: TimeInterval) -> String {
        String(format: "%.2f", seconds * 1000)
    }
}

/// Statistics for an operation.
public struct OperationStats {
    public let name: String
    public let callCount: Int
    public let count: Int
    public let average: TimeInterval
    public let median: TimeInterval
    public let p99: TimeInterval
    public let max: TimeInterval
}

// MARK: - Convenience Macro

/// Measure a block using defer.
public func measureBlock<T>(_ name: String, threshold: TimeInterval = 0.050, operation: () -> T) -> T {
    PerfMonitor.measureStart(name)
    defer { PerfMonitor.measureEnd(name, threshold: threshold) }
    return operation()
}
