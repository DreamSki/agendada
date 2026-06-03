import Foundation
import OSLog

/// 简化的性能监控 - 主线程安全
public class AutoPerformanceMonitor {
    private let logger = Logger(subsystem: "com.agendada", category: "AutoPerf")
    private var startTime: Date
    private var startMemory: Double = 0
    private var operationCount: Int = 0

    public init() {
        self.startTime = Date()
        self.startMemory = getCurrentMemorySync()
        self.logger.info("📊 [MONITOR] Performance monitoring started - Initial memory: \(String(format: "%.1f", self.startMemory)) MB")
    }

    public func logOperation(_ operation: String) {
        self.operationCount += 1
        let currentMemory = getCurrentMemorySync()
        let elapsed = Date().timeIntervalSince(self.startTime)
        let growth = currentMemory - self.startMemory

        let growthStr = growth >= 0 ? "+\(String(format: "%.1f", growth))" : String(format: "%.1f", growth)

        self.logger.info("📊 [OP #\(self.operationCount)] \(operation) - Memory: \(String(format: "%.1f", currentMemory)) MB (\(growthStr) MB, \(String(format: "%.0f", elapsed))s)")

        // 警告内存增长
        if growth > 30 {
            self.logger.warning("⚠️ Memory grew \(String(format: "%.1f", growth)) MB since start")
        }
    }

    private func getCurrentMemorySync() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return 0
    }
}
