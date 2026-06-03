# 🎯 Agendada 性能分析完整执行指南

## 📋 你现在需要做的（按顺序）

### 第 1 步：准备工作（5 分钟）

```bash
# 1. 确保应用可以构建
cd /Users/oosun/Documents/03\ Resources/Agendada
swift build

# 2. 创建结果目录
mkdir -p PerformanceResults

# 3. 打开这份指南的副本
open PerformanceAnalysis/ANALYSIS_REPORT_TEMPLATE.md
```

### 第 2 步：启动 Instruments（10 分钟）

```bash
# 方式 A：使用 Xcode（推荐）
# 1. 打开 Xcode
open /Applications/Xcode.app

# 2. 选择 Xcode 菜单 → Open Developer Tool → Instruments

# 方式 B：使用命令行
instruments
```

### 第 3 步：配置 Time Profiler（5 分钟）

在 Instruments 中：

1. 选择 **Time Profiler** 模板
2. 点击 Target 选择按钮
3. 浏览到 `/Users/oosun/Documents/03 Resources/Agendada/.build/debug/Agendada`
4. 点击 **Choose**
5. 确认配置：
   - ✅ Record sampled instructions
   - ✅ Separate by Thread
   - ✅ Invert Call Tree (录制后勾选)

### 第 4 步：执行场景测试（30 分钟）

#### 场景 1：基线测量（5 分钟）

1. 点击红色录制按钮
2. 什么都不做，等待 30 秒
3. 停止录制
4. **保存**：`File → Save As → PerformanceResults/baseline_IDLE.trace`
5. **记录数据**：
   - 查看 CPU 占用（应该 < 5%）
   - 查看内存占用（应该 < 100MB）

在报告模板中记录：
```
场景 1：基线测量
✅ 平均 CPU: ___ %
✅ 峰值内存: ___ MB
```

#### 场景 2：笔记操作（10 分钟）

1. 点击录制按钮
2. 执行以下操作 **20 次**：
   - 点击 + 按钮
   - 输入标题 "Test N"
   - 输入 "test content"
   - 按 ESC 退出编辑
   - 点击下一笔记
3. 停止录制
4. **保存**：`PerformanceResults/notes_operations.trace`
5. **分析 Call Tree**：
   - 勾选 "Invert Call Tree"
   - 勾选 "Hide System Libraries"
   - 按 "Weight" 排序

在报告模板中记录：
```
场景 2：笔记操作
✅ 创建笔记平均耗时: ___ ms
⚠️  persist() 耗时: ___ ms (目标 < 50ms)
🔴 snapshot() 耗时: ___ ms (如果 > 50ms 则有问题)
```

**关键检查点**：
- 🔍 搜索 `publishChange` - 查看调用次数和耗时
- 🔍 搜索 `snapshot()` - 查看执行时间
- 🔍 搜索 `filteredNotes` - 查看调用频率

#### 场景 3：无限滚动（5 分钟）

1. 如果笔记少于 50 个，先创建更多
2. 点击录制按钮
3. 在笔记流中快速上下滚动 2 分钟
4. 停止录制
5. **保存**：`PerformanceResults/scrolling.trace`

在报告模板中记录：
```
场景 3：无限滚动
✅ 平均 FPS: ___ (目标 60)
⚠️  掉帧次数: ___
⚠️  内存增长: ___ MB
```

#### 场景 4：搜索性能（3 分钟）

1. 点击录制按钮
2. 打开搜索框
3. 快速输入 "agendada performance test search query"
4. 停止录制
5. **保存**：`PerformanceResults/search.trace`

在报告模板中记录：
```
场景 4：搜索
✅ 输入延迟: ___ ms
✅ debounce 效果: ___ 次调用（目标 < 20）
```

#### 场景 5：长时间运行（10 分钟）

1. 点击录制按钮
2. 混合执行之前的操作 10 分钟
3. 每 2 分钟记录一次内存快照（使用 Mark Heap 功能）
4. 停止录制
5. **保存**：`PerformanceResults/longrun.trace`

在报告模板中记录：
```
场景 5：长时间运行
⚠️  内存增长: ___ MB (如果 > 50MB 则有泄漏)
```

### 第 5 步：切换到 Allocations 分析（15 分钟）

1. 在 Instruments 中，新建 **Allocations** 模板
2. 执行场景 3（滚动）2 分钟
3. 查看 **All Heap & Anonymous VM** 趋势
4. 检查这些对象：
   - `DaySchedule` - 数量应该稳定
   - `Note` - 数量应该稳定
   - 任何持续增长的对象

**关键检查**：
```
Generations → Mark Heap（开始） → 操作 2 分钟 → Mark Heap（结束）
查看两个 Heap Snapshot 的差值
```

### 第 6 步：整理发现（30 分钟）

将所有结果填入 `ANALYSIS_REPORT_TEMPLATE.md`：

1. 整理所有测量值
2. 截图保存关键数据
3. 列出所有发现的问题
4. 按严重程度分类

---

## 🔍 重点检查的函数

在 Time Profiler 的 Call Tree 中，按 `Cmd+F` 搜索：

| 函数 | 预期 | 警告阈值 | 危险阈值 |
|------|------|---------|---------|
| `snapshot()` | < 10ms | 30ms | 50ms |
| `publishChange()` | < 100/秒 | 200/秒 | 500/秒 |
| `filteredNotes()` | < 1ms (缓存命中) | 10ms | 50ms |
| `persist()` | < 20ms | 50ms | 100ms |
| `mergeSchedules()` | < 20ms | 50ms | 100ms |

### 如何检查具体函数

1. **搜索函数名**：在 Call Tree 输入框输入
2. **查看调用次数**：
   - 切换到 "Call Tree" 视图
   - 点击 "Sample Count" 列排序
3. **查看调用者**：
   - 选中函数
   - 查看 "Contributing Callers"
4. **查看总耗时**：
   - 切换到 "Heaviest Stack Trace"
   - 查看该函数在总时间的占比

---

## 📊 预期发现

基于代码审查，你应该发现以下问题：

### 🔴 Critical（必须发现）

1. **`snapshot()` 执行时间 > 50ms**
   - 在 Time Profiler 中搜索 `snapshot()`
   - 查看 "Self" 时间（不含子调用）
   - 如果 > 50ms，确认主线程阻塞

2. **`publishChange()` 调用频率 > 100/秒**
   - 在 Call Tree 中搜索 `publishChange`
   - 查看 "Call Count"
   - 如果过高，说明有过度刷新

3. **内存持续增长**
   - 在 Allocations 中查看 "Net Bytes"
   - 如果持续上升（非阶梯状），说明有泄漏

### ⚠️ Warning（应该发现）

1. **`filteredNotes()` 被频繁调用**
   - 查看调用次数
   - 检查缓存命中率（通过耗时判断）

2. **`rowPositions` 或 `daySchedules` 增长**
   - 在 Allocations 中搜索这些类型
   - 查看实例数量趋势

---

## ✅ 完成检查清单

完成测试后，确保你有：

- [ ] 6 个 trace 文件保存在 `PerformanceResults/`
- [ ] `ANALYSIS_REPORT_TEMPLATE.md` 填写完整
- [ ] 至少 5 张关键截图（Call Tree、内存趋势等）
- [ ] 列出所有发现的问题
- [ ] 为每个问题提供证据（截图/数据）
- [ ] 按优先级分类问题

---

## 🎯 测试完成后

将完成的报告分享给我，我会帮你：
1. 确认问题的严重性
2. 提供具体的修复方案
3. 按优先级排列修复顺序
4. 验证修复效果

---

## 💡 遇到问题？

### Instruments 无法录制？
- 确保应用是 Debug 构建
- 检查是否有权限访问应用
- 尝试以管理员身份运行

### 找不到某个函数？
- 确保在正确的模板中（Time Profiler）
- 取消勾选 "Hide System Libraries"
- 搜索函数名的一部分

### 数据看起来不对？
- 检查是否录制了足够长的时间
- 确认操作是否按步骤执行
- 重新录制一次对比

---

**预计总时间**：2-3 小时（包括测试和整理报告）

**关键提示**：
- 🎯 专注于找全问题，而不是修复
- 📊 用数据说话，截图保存证据
- 📝 详细记录每个发现
