# Agendada Instruments 性能分析指南

## 📱 如何使用 Instruments 进行深度性能分析

### 1. Time Profiler（时间分析器）

**用途**: 找出 CPU 热点函数

**步骤**:
```bash
# 1. 构建 Debug 版本（保留符号信息）
swift build --configuration debug

# 2. 启动 Instruments
instruments -t Time\ Profiler trace.trace .build/debug/Agendada

# 或使用 Xcode:
# Product → Profile → Time Profiler
```

**关键检查点**:
- 🔍 搜索 `publishChange` - 查看调用频率和调用栈
- 🔍 搜索 `filteredNotes()` - 查看是否被频繁调用
- 🔍 搜索 `snapshot()` - 查看执行时间
- 🔍 搜索 `JSONEncoder` / `JSONDecoder` - 查看序列化开销

**关注指标**:
- `Self (ms)`: 函数自身的执行时间
- `Total (ms)`: 包含子调用的总时间
- `Call Count`: 调用次数（>1000/秒需要优化）

---

### 2. Allocations（内存分配）

**用途**: 检测内存泄漏和过度分配

**启动命令**:
```bash
instruments -t Allocations mem.trace .build/debug/Agendada
```

**关键检查**:
- 💾 查看 `All Heap & Anonymous VM` 的总大小趋势
- 💾 搜索 `DaySchedule` - 查看是否无限增长
- 💾 搜索 `Note` - 查看实例数量
- 💾 查看 `Persistent Bytes` - 应该稳定，不应该持续增长

**内存泄漏检测**:
```
使用 "Mark Heap" 功能：
1. 启动应用 → Mark Heap (baseline)
2. 执行 50 次笔记操作（新建、编辑、删除）
3. Mark Heap
4. 执行 GC (使用 "Generate Heap Snapshot")
5. 对比两次 snapshot 的差值
```

---

### 3. Core Animation

**用途**: 检测 UI 掉帧

**关键指标**:
- `FPS`: 应该稳定在 60fps
- `FPS < 60` 的时间段
- 哪个 View 导致的掉帧（查看 Call Tree）

---

### 4. System Trace

**用途**: 分析主线程阻塞

**关键视图**:
- "Main Thread" 轨迹 - 查找 >16ms 的连续执行
- "Thread State" - 分析线程是否被阻塞

---

## 🎯 具体操作场景测试

### 场景 1: 快速连续笔记操作

**测试步骤**:
1. 启动 Time Profiler
2. 快速执行：新建笔记 → 输入标题 → 切换笔记 → 重复 20 次
3. 暂停录制，查看统计

**预期问题**:
- `persist()` 被调用 20+ 次
- `publishChange()` 被调用 20+ 次
- 每次触发大量视图更新

---

### 场景 2: 无限滚动

**测试步骤**:
1. 启动 Allocations
2. 在笔记流中快速滚动
3. 查看 `rowPositions` 和 `daySchedules` 的内存增长

---

### 场景 3: 搜索输入

**测试步骤**:
1. 启动 Time Profiler
2. 在搜索框中快速输入 "agendada performance test"
3. 查看 `calculateSearchOccurrences` 和 `filteredNotes()` 的调用频率

---

## 📊 分析技巧

### 1. 使用 "Invert Call Tree"

**用途**: 查看哪些 UI 操作触发了性能瓶颈

**步骤**:
1. 选中 `filteredNotes()` 的调用
2. 点击 "Invert Call Tree"
3. 查看顶层调用者：
   - `NoteStreamView.body`？
   - `RelatedPanelContentView.body`？
   - `TimelineView.body`？

---

### 2. 使用 "Sample by Thread"

**用途**: 确认主线程 vs 后台线程的执行情况

**检查**:
- 主线程应该只做 UI 渲染
- 耗时操作应该在 `com.apple.root.default-qos` 或自定义 queue

---

### 3. 设置时间过滤器

**用途**: 只分析特定操作期间的性能

**步骤**:
1. 在 Instruments 时间轴上选中一个区间
2. 只看这个区间的 Call Tree

---

## 🔧 常见性能模式识别

### 模式 1: "Bowtie" 调用图

```
UI Event → publishChange() → 视图刷新 → filteredNotes() → 排序 → 视图刷新
                                      ↑____________________________|
```

**问题**: 循环依赖导致无限更新

**解决**: 缓存中间结果，使用 `@State` 隔离

---

### 模式 2: "Thundering Herd"

```
用户输入 → onChange → scheduleSaveDraft (0)
         → onChange → scheduleSaveDraft (1)
         → onChange → scheduleSaveDraft (2)
         ...
```

**问题**: debounce 延迟内创建了大量 Task

**解决**: 确保 Task 被正确取消

---

### 模式 3: "Memory Creep"

```
Time →    0s    10s    20s    30s    40s
Memory:  50MB → 55MB → 65MB → 80MB → 100MB
```

**问题**: 内存持续增长（可能是 rowPositions/daySchedules）

**解决**: 定期清理或设置上限

---

## 📝 报告模板

分析完成后，使用以下模板记录：

```markdown
## 性能分析报告

**日期**: 2024-xx-xx
**测试场景**: [描述测试操作]
**工具**: Instruments [Time Profiler / Allocations / ...]

### 发现的问题

1. **[问题名称]**
   - 严重性: [Critical / Warning / Info]
   - 位置: [文件:行号]
   - 证据:
     - 函数调用次数: N/秒
     - 平均执行时间: X ms
     - 内存增长: Y MB/分钟
   - 建议修复: [具体方案]

### 性能指标

| 指标 | 测前 | 测后 | 目标 |
|------|------|------|------|
| FPS | 45 | ? | 60 |
| 内存 (稳态) | 80MB | ? | <100MB |
| 操作延迟 | 200ms | ? | <100ms |

### 验证方法

- [ ] 在模拟场景中复现问题
- [ ] 使用 Instruments 确认瓶颈
- [ ] 应用修复
- [ ] 重新测量，确认改进
```
