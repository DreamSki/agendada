# 集成性能监控到 Agendada

## 快速开始

### 1. 添加监控文件

```bash
cp PerformanceAnalysis/IntegratedMonitoring.swift Sources/Agendada/
```

### 2. 在关键位置添加监控调用

#### ObservableLibraryStore.swift

```swift
// 在文件顶部添加导入
// import Foundation  // 已有

// 在 publishChange() 中添加
private func publishChange() {
    #if DEBUG
    PerfMonitor.trackPublishChange()
    #endif
    revision &+= 1
    invalidateFilteredNotesCache()
}

// 在 filteredNotes() 中添加
func filteredNotes() -> [Note] {
    #if DEBUG
    let cacheHit = cachedFilteredNotes != nil &&
                   cachedFilteredNotesRevision == revision &&
                   cachedFilteredNotesSearchText == store.searchText
    PerfMonitor.trackFilteredNotes(cacheHit: cacheHit)
    #endif

    observeRevision()
    if let cached = cachedFilteredNotes,
       cachedFilteredNotesRevision == revision,
       cachedFilteredNotesSearchText == store.searchText {
        return cached
    }
    // ... 其余代码
}

// 在 persist() 中添加
private func persist() {
    #if DEBUG
    PerfMonitor.measureStart("persist")
    defer { PerfMonitor.measureEnd("persist", threshold: 0.100) }
    #endif

    saveTask?.cancel()
    let snapshot = store.snapshot()
    saveTask = Task {
        do { try await self.repository.save(snapshot) }
        catch { assertionFailure("Failed to save: \(error)") }
    }
}

// 在 snapshot() 中添加（LibraryStore.swift）
public func snapshot() -> LibrarySnapshot {
    #if DEBUG
    PerfMonitor.measureStart("snapshot")
    defer { PerfMonitor.measureEnd("snapshot", threshold: 0.050) }
    #endif

    return LibrarySnapshot(
        categories: categories,
        projects: projects,
        notes: notes,
        // ... 其余代码
    )
}
```

#### RelatedPanelContentView.swift

```swift
// 在 applyTimelinePositions 中添加
private func applyTimelinePositions(_ positions: [Date: CGFloat]) {
    #if DEBUG
    PerfMonitor.track("applyTimelinePositions")
    PerfMonitor.trackCollectionSize("rowPositions", count: positions.count)
    #endif

    lastScrollProcessTime = Date()
    if shouldUpdateRowPositions(positions) {
        rowPositions = positions
    }
    // ... 其余代码
}
```

#### CalendarStore.swift

```swift
// 在 mergeSchedules 中添加
private func mergeSchedules(_ newSchedules: [DaySchedule], updateRange: Bool) {
    #if DEBUG
    PerfMonitor.measureStart("mergeSchedules")
    defer { PerfMonitor.measureEnd("mergeSchedules", threshold: 0.100) }
    PerfMonitor.trackCollectionSize("daySchedules", count: daySchedules.count)
    #endif

    // ... 原有代码
}
```

#### NoteStreamView.swift

```swift
// 在 scheduleSaveDraft 中添加
private func scheduleSaveDraft() {
    #if DEBUG
    PerfMonitor.track("scheduleSaveDraft")
    #endif

    if draft == initialDraft { return }
    // ... 原有代码
}
```

### 3. 添加查看性能报告的方式

在 AgendadaApp.swift 中添加键盘快捷键：

```swift
// 在 ContentView 或主视图中添加
.onAppear {
    #if DEBUG
    // 注册快捷键查看性能报告
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if event.modifierFlags.contains([.command, .shift]) &&
           event.keyCode == 1 { // Cmd+Shift+P
            PerfMonitor.printSummary()
            return nil
        }
        return event
    }
    #endif
}
```

或者添加一个菜单项：

```swift
// 在开发模式下添加菜单
#if DEBUG
Menu("Debug") {
    Button("Print Performance Summary") {
        PerfMonitor.printSummary()
    }
    Button("Reset Performance Data") {
        PerfMonitor.reset()
    }
}
#endif
```

## 验证监控效果

### 测试场景 1: 快速笔记操作

1. 启动应用
2. 执行 20 次快速操作：新建笔记 → 输入标题 → 切换笔记
3. 按 Cmd+Shift+P 查看性能报告

**预期结果**:
- `publishChange` 应该被调用约 60 次（每个操作 3 次：新建、编辑、切换）
- `filteredNotes` 的 cache hit rate 应该 > 90%
- `persist` 应该被调用约 1-2 次（debounce 后）

### 测试场景 2: 无限滚动

1. 在笔记流中快速滚动
2. 查看性能报告

**预期结果**:
- `applyTimelinePositions` 调用次数应该合理（< 100 次/秒）
- `rowPositions` 大小应该稳定（不持续增长）

### 测试场景 3: 搜索输入

1. 在搜索框中快速输入 "performance test"
2. 查看性能报告

**预期结果**:
- `calculateSearchOccurrences` 应该被 debounce（< 20 次）
- `filteredNotes_cacheMiss` 应该与实际搜索次数匹配

## 性能问题诊断清单

### 如果看到这些警告：

| 警告信息 | 含义 | 下一步 |
|---------|------|--------|
| "called 100+ times" | 函数调用频率过高 | 查看 Call Tree，优化调用点 |
| "Cascade detected" | publishChange 级联调用 | 检查是否有循环依赖 |
| "cache miss" | 缓存失效频繁 | 检查缓存逻辑 |
| "Collection doubled" | 集合无限增长 | 添加清理逻辑 |
| 执行时间 > 100ms | 函数执行过慢 | 使用 Instruments 分析 |

### 关键指标阈值

| 操作 | 警告阈值 | 危险阈值 |
|-----|---------|---------|
| `persist()` | 50ms | 100ms |
| `snapshot()` | 30ms | 50ms |
| `filteredNotes()` (cache miss) | 20ms | 50ms |
| `publishChange()` 调用频率 | 50/秒 | 100/秒 |
| `mergeSchedules()` | 50ms | 100ms |

## 示例报告输出

```
╔══════════════════════════════════════════════════════════════╗
║                  PERFORMANCE SUMMARY                          ║
╚══════════════════════════════════════════════════════════════╝

📊 Top Operations by Average Duration:

⚠️  persist
   Calls: 15, Samples: 15
   Avg: 45.23ms, Med: 42.10ms, P99: 89.50ms, Max: 95.20ms

✅ filteredNotes
   Calls: 2450, Samples: 2450
   Avg: 0.12ms, Med: 0.08ms, P99: 1.50ms, Max: 3.20ms

💀 snapshot
   Calls: 15, Samples: 15
   Avg: 125.45ms, Med: 118.20ms, P99: 245.80ms, Max: 280.10ms

⚠️  publishChange
   Calls: 180, Samples: 180
   Avg: 0.05ms, Med: 0.02ms, P99: 0.50ms, Max: 1.20ms
```

从这份报告可以看出：
- `snapshot()` 执行时间过长（125ms 平均），需要优化
- `filteredNotes()` 调用频繁但执行快（0.12ms），缓存有效
- `persist()` 在可接受范围内但接近警告阈值
