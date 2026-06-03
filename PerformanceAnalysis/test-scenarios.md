# Agendada 性能测试场景

## 测试环境要求

- 确保没有其他应用占用大量 CPU
- 关闭不必要的后台应用
- 确保应用已完全构建（Debug 模式，保留符号）

## 测试场景定义

### 场景 1：基线测量（5 分钟）
**目的**：获取应用空闲时的性能基线

**操作**：
1. 启动应用
2. 什么都不做，让它空闲 30 秒
3. 记录内存占用、CPU 占用

**预期**：
- CPU: < 5%
- 内存: < 100MB
- 无持续增长趋势

---

### 场景 2：快速笔记操作（5 分钟）
**目的**：测量笔记创建/编辑/切换的性能

**操作**（重复 20 次）：
1. 点击 + 按钮创建新笔记
2. 输入标题 "Test Note N"（N 为序号）
3. 输入正文 "This is test note number N"
4. 点击 ESC 键退出编辑
5. 点击下一笔记

**关键指标**：
- `persist()` 调用频率
- `publishChange()` 调用频率
- `filteredNotes()` 调用频率
- 主线程阻塞时间
- 内存增长

---

### 场景 3：无限滚动（5 分钟）
**目的**：测量滚动性能和内存增长

**操作**：
1. 如果笔记少于 50 个，先创建 50 个笔记
2. 在笔记流中快速上下滚动
3. 持续滚动 2 分钟

**关键指标**：
- FPS（应该保持 60）
- `rowPositions` 增长情况
- `daySchedules` 增长情况
- 内存增长趋势

---

### 场景 4：搜索性能（3 分钟）
**目的**：测量搜索输入和结果过滤的性能

**操作**：
1. 点击搜索按钮
2. 快速输入 "agendada performance test search query"
3. 每个字符输入间隔 < 200ms

**关键指标**：
- `calculateSearchOccurrences` 调用频率
- `filteredNotes()` 缓存命中率
- debounce 效果
- 输入延迟

---

### 场景 5：批量操作（3 分钟）
**目的**：测量批量选择和操作的性能

**操作**：
1. 进入批量选择模式
2. 全选当前视图的所有笔记
3. 执行批量删除/恢复
4. 重复 10 次

**关键指标**：
- `batchDeleteNotes` 执行时间
- `publishChange()` 调用次数
- UI 响应时间

---

### 场景 6：长时间运行（10 分钟）
**目的**：检测内存泄漏和性能退化

**操作**：
1. 混合执行场景 2-5 的操作
2. 持续 10 分钟
3. 每 2 分钟记录一次内存快照

**关键指标**：
- 内存趋势（是否持续增长）
- CPU 趋势（是否随时间变慢）
- Task 数量（是否泄漏）

---

## 测试记录模板

### 场景 X：[场景名称]

**测试时间**：YYYY-MM-DD HH:MM:SS

**操作步骤**：
- [ ] 步骤 1
- [ ] 步骤 2
- ...

**Instruments 数据**：
- Time Profiler 截图：`/path/to/screenshot`
- Allocations 截图：`/path/to/screenshot`

**关键发现**：
1. [函数名] 被调用 XXX 次，占总时间的 XX%
2. [操作] 平均耗时 XXX ms
3. 内存从 XXX MB 增长到 XXX MB

**问题记录**：
- 🔴 Critical: [描述]
- ⚠️ Warning: [描述]
- ℹ️ Info: [描述]

---

## 自动化测试脚本（可选）

如果需要可重复的测试，可以考虑：
1. 使用 XCUITest 自动化 UI 操作
2. 使用 AppleScript 控制 UI
3. 记录每个操作的精确时间戳

### 示例：快速操作自动化脚本

```applescript
tell application "System Events"
    tell process "Agendada"
        -- 重复 20 次
        repeat 20 times
            -- 点击 + 按钮
            click button 1 of toolbar 1 of window 1
            delay 0.5

            -- 输入标题
            keystroke "Test Note " & (index as string)
            delay 0.2

            -- 输入正文
            keystroke tab
            keystroke "This is a test note"
            delay 0.2

            -- 退出编辑
            key code 53 -- ESC
            delay 0.3
        end repeat
    end tell
end tell
```
