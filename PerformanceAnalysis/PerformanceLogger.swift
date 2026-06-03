import Foundation
import OSLog

/// Performance logging utility for tracking execution times of critical operations.
/// Use this to identify bottlenecks in production-like scenarios.
public actor PerformanceLogger {
    private let log = Logger(subsystem: "com.agendada", category: "Performance")

    // MARK: - Configuration

    /// Threshold in seconds above which a warning is logged.
    var warningThreshold: TimeInterval = 0.05  // 50ms

    /// Enable/disable detailed logging.
    var isEnabled: Bool = true

    // MARK: - Metrics Storage

    private var measurements: [String: [TimeInterval]] = [:]
    private var activeSpans: [String: TimeInterval] = [:]

    // MARK: - Public API

    /// Measure the execution time of a block of code.
    /// - Parameters:
    ///   - name: Unique identifier for this operation
    ///   - operation: The code to measure
    public func measure<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        guard isEnabled else { return try await operation() }

        let start = Date()
        defer {
            let elapsed = Date().timeIntervalSince(start)
            recordMeasurement(name, duration: elapsed)

            if elapsed > warningThreshold {
                log.warning("⚠️ \(name) took \(String(format: "%.3f", elapsed))s (threshold: \(warningThreshold)s)")
            } else {
                log.debug("✓ \(name) took \(String(format: "%.3f", elapsed))s")
            }
        }

        return try await operation()
    }

    /// Measure a synchronous operation.
    public func measureSync<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        guard isEnabled else { return try operation() }

        let start = Date()
        let result = try operation()
        let elapsed = Date().timeIntervalSince(start)

        recordMeasurement(name, duration: elapsed)

        if elapsed > warningThreshold {
            log.warning("⚠️ [SYNC] \(name) took \(String(format: "%.3f", elapsed))s")
        } else {
            log.debug("✓ [SYNC] \(name) took \(String(format: "%.3f", elapsed))s")
        }

        return result
    }

    /// Begin a manual span measurement. Returns a span ID that must be passed to `endSpan()`.
    public func beginSpan(_ name: String) -> String {
        guard isEnabled else { return "" }

        let spanID = "\(name)_\(UUID().uuidString.prefix(8))"
        activeSpans[spanID] = Date().timeIntervalSince1970
        log.debug("↔️ Span started: \(name)")
        return spanID
    }

    /// End a manual span measurement.
    public func endSpan(_ spanID: String, name: String) {
        guard isEnabled, let startTime = activeSpans[spanID] else { return }

        let elapsed = Date().timeIntervalSince1970 - startTime
        activeSpans.removeValue(forKey: spanID)
        recordMeasurement(name, duration: elapsed)

        if elapsed > warningThreshold {
            log.warning("⚠️ Span '\(name)' took \(String(format: "%.3f", elapsed))s")
        } else {
            log.debug("✓ Span '\(name)' took \(String(format: "%.3f", elapsed))s")
        }
    }

    // MARK: - Statistics

    /// Get statistics for a specific operation.
    public func statistics(for name: String) -> PerformanceStats? {
        guard let timings = measurements[name], !timings.isEmpty else { return nil }

        let sorted = timings.sorted()
        let count = timings.count
        let total = timings.reduce(0, +)
        let avg = total / Double(count)
        let min = sorted.first!
        let max = sorted.last!
        let median = sorted[count / 2]

        return PerformanceStats(
            name: name,
            count: count,
            average: avg,
            median: median,
            min: min,
            max: max
        )
    }

    /// Get all recorded statistics.
    public func allStatistics() -> [PerformanceStats] {
        measurements.keys.compactMap { statistics(for: $0) }
        .sorted { $0.average > $1.average }
    }

    /// Reset all measurements.
    public func reset() {
        measurements.removeAll()
        activeSpans.removeAll()
    }

    /// Print a summary report.
    public func printSummary() {
        let stats = allStatistics()
        guard !stats.isEmpty else {
            log.info("No performance data collected.")
            return
        }

        log.info("🔍 Performance Summary:")
        log.info("==========================================")
        for stat in stats where stat.count > 0 {
            log.info("""
            \(stat.name):
              Calls: \(stat.count)
              Avg:   \(String(format: "%.3f", stat.average))s
              Med:   \(String(format: "%.3f", stat.median))s
              Min:   \(String(format: "%.3f", stat.min))s
              Max:   \(String(format: "%.3f", stat.max))s
            """)
        }
        log.info("==========================================")
    }

    // MARK: - Private

    private func recordMeasurement(_ name: String, duration: TimeInterval) {
        if measurements[name] == nil {
            measurements[name] = []
        }
        measurements[name]?.append(duration)

        // Keep only the last 1000 measurements per operation to prevent unbounded growth
        if let count = measurements[name]?.count, count > 1000 {
            measurements[name]?.removeFirst(count - 1000)
        }
    }
}

/// Statistics for a measured operation.
public struct PerformanceStats {
    public let name: String
    public let count: Int
    public let average: TimeInterval
    public let median: TimeInterval
    public let min: TimeInterval
    public let max: TimeInterval
}

// MARK: - Global Shared Instance

public extension PerformanceLogger {
    static let shared = PerformanceLogger()
}

// MARK: - Convenience Wrappers

/// Property wrapper for measuring async operations.
@propertyWrapper
public struct MeasuredAsync<T> {
    private let name: String
    private let logger: PerformanceLogger

    public init(_ name: String, logger: PerformanceLogger = .shared) {
        self.name = name
        self.logger = logger
    }

    public func wrap(_ operation: @escaping () async throws -> T) -> () async throws -> T {
        return {
            try await logger.measure(name, operation: operation)
        }
    }
}

/// Convenience functions for quick measurements.
public extension PerformanceLogger {
    /// Log a one-off measurement without wrapping.
    func log(_ name: String, duration: TimeInterval) {
        guard isEnabled else { return }

        recordMeasurement(name, duration: duration)

        if duration > warningThreshold {
            log.warning("⚠️ \(name) took \(String(format: "%.3f", duration))s")
        } else {
            log.debug("✓ \(name) took \(String(format: "%.3f", duration))s")
        }
    }
}
