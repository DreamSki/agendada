# Agendada 性能问题检查清单

## 📋 检查流程（按顺序执行）

### 第一阶段：确认问题现象

#### 1.1 描述卡顿情况
- [ ] 卡顿发生在哪个操作？
  - 新建笔记
  - 编辑笔记
  - 切换笔记
  - 滚动笔记流
  - 搜索
  - 其他: _____________
- [ ] 卡顿持续多久？
  - < 100ms（轻微）
  - 100-500ms（明显）
  - > 500ms（严重）
  - > 1s（无法接受）
- [ ] 卡顿是否累积？
  - 否，每次操作卡顿时间相同
  - 是，使用时间越长越卡

---

### 第二阶段：使用 Instruments 定位热点

#### 2.1 启动 Time Profiler
```bash
# 方式 1: 命令行
cd /Users/oosun/Documents/03\ Resources/Agendada
swift build
instruments -t Time\ Profiler -c "Launch" .build/debug/Agendada

# 方式 2: Xcode
# Product → Profile → Time Profiler
```

#### 2.2 执行复现步骤
1. 开始录制
2. 执行导致卡顿的操作（重复 20-30 次）
3. 停止录制

#### 2.3 分析 Call Tree
在 Instruments 中：
- 点击 "Call Tree"
- 勾选 "Invert Call Tree"（查看调用栈顶部）
- 勾选 "Hide System Libraries"
- 按照按 "Weight %" 排序

**检查这些函数**:

| 函数名 | 预期调用频率 | 实际调用频率 | 结论 |
|--------|-------------|-------------|------|
| `publishChange()` | < 10/秒 | _________ | ⚠️ 过高 |
| `filteredNotes()` | < 50/秒 | _________ | ⚠️ 过高 |
| `persist()` | < 1/秒 | _________ | ⚠️ 过高 |
| `snapshot()` | < 1/秒 | _________ | ⚠️ 过高 |
| `scheduleSearchCalculation()` | < 5/秒 | _________ | ⚠️ 过高 |
| `mergeScheduledNotes()` | < 5/秒 | _________ | ⚠️ 过高 |

#### 2.4 检查主线程占用
- 切换到 "Thread State" 视图
- 查看 "Main Thread" 的占用时间
- **危险信号**: 主线程连续执行 > 16ms（意味着掉帧）

---

### 第三阶段：内存分析

#### 3.1 启动 Allocations
```bash
instruments -t Allocations -c "Launch" .build/debug/Agendada
```

#### 3.2 执行压力测试
1. 录制 baseline（应用启动后 10 秒）
2. 执行 100 次笔记操作（新建/编辑/删除）
3. 录制结束

#### 3.3 检查内存增长

**查看这些对象的数量**:

| 对象类型 | 初始数量 | 结束数量 | 增长 | 结论 |
|---------|---------|---------|------|------|
| `Note` | _______ | _______ | _____ | ⚠️ 过多 |
| `DaySchedule` | _______ | _______ | _____ | ⚠️ 增长 |
| `Task` | _______ | _______ | _____ | ⚠️ 泄漏 |
| `WKWebView` | _______ | _______ | _____ | ✅ 应为 1 |

**内存趋势图应该**:
- ✅ 稳定后有轻微波动
- ❌ 持续单调上升

---

### 第四阶段：视图刷新分析

#### 4.1 检查 SwiftUI 视图更新频率
在关键视图中添加日志：

```swift
// 在 NoteStreamView.swift 的 body 中添加
var body: some View {
    let start = Date()
    defer {
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0.016 {
            print("⚠️ NoteStreamView.body took \(elapsed)s")
        }
    }
    // ... 原有代码
}
```

#### 4.2 检查 @Observable 属性访问频率
```swift
// 在 ObservableLibraryStore.swift 中
func observeRevision() {
    let caller = Thread.callStackSymbols[1]
    print("🔍 observeRevision called from: \(caller)")
    _ = revision
}
```

**运行 30 秒后检查日志**:
- 统计 `observeRevision` 的调用次数
- 如果 > 1000/秒，说明有过度订阅问题

---

### 第五阶段：依赖关系分析

#### 5.1 追踪 `publishChange()` 的来源

在 `ObservableLibraryStore.swift` 中添加：

```swift
private func publishChange() {
    let caller = Thread.callStackSymbols.dropFirst().first ?? "unknown"
    print("📢 publishChange from: \(caller)")
    revision &+= 1
    invalidateFilteredNotesCache()
}
```

**执行操作后检查日志**:
- 哪个函数调用了 `publishChange()` 最多？
- 是否有级联调用（A → B → A）？

#### 5.2 检查缓存失效

```swift
private func invalidateFilteredNotesCache() {
    print("🗑️ Cache invalidated - revision: \(revision)")
    cachedFilteredNotes = nil
    cachedFilteredNotesRevision = -1
    cachedFilteredNotesSearchText = ""
}
```

**运行 30 秒后检查日志**:
- 统计缓存失效次数
- 如果与操作次数不成比例，说明有过度失效

---

### 第六阶段：静态代码审查

#### 6.1 搜索这些危险模式

**主线程阻塞**:
```bash
grep -rn "JSONEncoder\|JSONDecoder\|snapshot()" Sources/ --include="*.swift"
# 检查结果: 如果在 @MainActor 函数中，需要移到后台
```

**全局刷新**:
```bash
grep -rn "publishChange()" Sources/ --include="*.swift"
# 检查结果: 找出所有调用点
```

**ForEach 稳定性**:
```bash
grep -rn "ForEach" Sources/ --include="*.swift" | grep -v "\.id:"
# 检查结果: 确保都有 .id 参数
```

**无限增长的集合**:
```bash
grep -rn "var.*:\[.*\]" Sources/ --include="*.swift"
# 对每个结果，检查是否有清理逻辑
```

#### 6.2 检查这些关键文件

**ObservableLibraryStore.swift**:
- [ ] `persist()` 是否在后台执行？
- [ ] `publishChange()` 调用频率是否合理？
- [ ] `filteredNotes()` 缓存是否有效？

**CalendarStore.swift**:
- [ ] `daySchedules` 是否有清理逻辑？
- [ ] `mergeSchedules()` 是否导致无限增长？

**RelatedPanelContentView.swift**:
- [ ] `rowPositions` 是否持续增长？
- [ ] `processTimelinePositions()` 是否过度调用？

**NoteStreamView.swift**:
- [ ] `scheduleSaveDraft()` 是否正确取消 Task？
- [ ] `StreamNoteRow` 是否有过度刷新？

---

### 第七阶段：验证修复

#### 7.1 修复前基线测试
记录以下指标：
```
场景: 快速创建 50 个笔记
- 总耗时: _____ 秒
- 平均每次: _____ ms
- FPS: _____ (最低)
- 内存峰值: _____ MB
```

#### 7.2 应用修复
实施具体的修复方案

#### 7.3 修复后对比测试
```
场景: 快速创建 50 个笔记
- 总耗时: _____ 秒 (改进: ___%)
- 平均每次: _____ ms (改进: ___%)
- FPS: _____ (最低) (改进: ___%)
- 内存峰值: _____ MB (改进: ___%)
```

---

## 🎯 快速诊断命令

### 查找主线程阻塞点
```bash
grep -rn "@MainActor" Sources/ --include="*.swift" | \
  xargs -I {} sh -c 'echo "=== {} ===" && cat {}' | \
  grep -A 5 "JSONEncoder\|JSONDecoder\|snapshot()"
```

### 查找可能的全局刷新
```bash
grep -rn "revision.*=" Sources/ --include="*.swift"
```

### 查找 Task 创建模式
```bash
grep -rn "Task.*=" Sources/ --include="*.swift" | \
  grep -v "cancel()"
```

### 查找缓存失效
```bash
grep -rn "invalidate\|cache.*=.*nil" Sources/ --include="*.swift"
```

---

## 📊 性能问题分类

| 类型 | 典型症状 | 诊断工具 | 优先级 |
|------|---------|---------|-------|
| 主线程阻塞 | 操作时 UI 冻结 | Time Profiler | P0 |
| 视图过度刷新 | 滚动/输入卡顿 | Time Profiler + 日志 | P0 |
| 内存泄漏 | 长时间使用后变慢 | Allocations | P1 |
| 级联更新 | 一个操作触发多次刷新 | Call Tree | P1 |
| Task 泄漏 | 内存增长 + CPU 占用 | Allocations + Time Profiler | P2 |

---

## 🔧 常见修复模板

### 修复 1: 移到后台 Actor
```swift
// 之前
@MainActor
func persist() {
    let snapshot = store.snapshot()  // 主线程阻塞
    saveTask = Task { try? await repo.save(snapshot) }
}

// 之后
func persist() {
    saveTask = Task {
        let snapshot = await store.snapshot()  // 后台执行
        try? await repo.save(snapshot)
    }
}
```

### 修复 2: 防止级联更新
```swift
// 之前
func updateNote(...) {
    store.updateNote(...)
    publishChange()  // 全局刷新
}

// 之后
func updateNote(...) {
    guard store.updateNote(...) else { return }  // 检查是否真的变化
    publishChange()  // 只在必要时刷新
}
```

### 修复 3: 限制集合增长
```swift
// 之前
private var rowPositions: [Date: CGFloat] = [:]

// 之后
private var rowPositions: [Date: CGFloat] = [:] {
    didSet {
        // 只保留最近 90 天的数据
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, from: Date())!
        rowPositions = rowPositions.filter { $0.key >= cutoff }
    }
}
```

---

## ✅ 完成检查

完成以上步骤后，你应该能够：
- [ ] 明确指出哪个函数/操作是性能瓶颈
- [ ] 提供数据支持（Instruments 截图、日志）
- [ ] 提出具体的修复方案
- [ ] 验证修复效果
