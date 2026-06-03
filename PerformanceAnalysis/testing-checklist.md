# Agendada 性能测试检查清单

## 准备阶段

- [ ] 确认应用可以构建：`swift build`
- [ ] 创建结果目录：`mkdir -p PerformanceResults`
- [ ] 打开 Xcode Instruments
- [ ] 打开执行指南：`QUICK_START.md`
- [ ] 打开报告模板：`ANALYSIS_REPORT_TEMPLATE.md`

## 场景 1：基线测量（5 分钟）

- [ ] 启动 Instruments
- [ ] 选择 Time Profiler
- [ ] 选择 Target：`.build/debug/Agendada`
- [ ] 点击录制按钮
- [ ] 等待 30 秒（什么都不做）
- [ ] 停止录制
- [ ] 保存：`PerformanceResults/baseline_IDLE.trace`

**记录数据**：
- [ ] 平均 CPU 占用：___ %
- [ ] 峰值内存：___ MB

## 场景 2：笔记操作（10 分钟）

- [ ] 点击录制
- [ ] 执行 20 次：创建笔记 → 输入标题 → 输入正文 → ESC → 切换
- [ ] 停止录制
- [ ] 保存：`PerformanceResults/notes_operations.trace`

**在 Instruments 中**：
- [ ] 勾选 "Invert Call Tree"
- [ ] 勾选 "Hide System Libraries"
- [ ] 搜索 `snapshot()` 并记录耗时
- [ ] 搜索 `publishChange()` 并记录调用次数
- [ ] 搜索 `filteredNotes()` 并记录调用次数

**记录数据**：
- [ ] `snapshot()` 耗时：___ ms
- [ ] `publishChange()` 调用次数：___
- [ ] `persist()` 耗时：___ ms

## 场景 3：无限滚动（5 分钟）

- [ ] 新建 Time Profiler
- [ ] 点击录制
- [ ] 快速滚动 2 分钟
- [ ] 停止录制
- [ ] 保存：`PerformanceResults/scrolling.trace`

**记录数据**：
- [ ] 平均 FPS：___
- [ ] 内存增长：___ MB

## 场景 4：搜索性能（3 分钟）

- [ ] 新建 Time Profiler
- [ ] 点击录制
- [ ] 打开搜索，快速输入 "agendada performance test"
- [ ] 停止录制
- [ ] 保存：`PerformanceResults/search.trace`

**记录数据**：
- [ ] 输入延迟：___ ms
- [ ] `calculateSearchOccurrences` 调用次数：___

## 场景 5：长时间运行（10 分钟）

- [ ] 切换到 Allocations 模板
- [ ] 点击录制
- [ ] 执行混合操作 10 分钟
- [ ] 每 2 分钟 Mark Heap 一次
- [ ] 停止录制
- [ ] 保存：`PerformanceResults/longrun.trace`

**记录数据**：
- [ ] 初始内存：___ MB
- [ ] 最终内存：___ MB
- [ ] 内存增长：___ MB

## 完成后

- [ ] 填写 `ANALYSIS_REPORT_TEMPLATE.md`
- [ ] 保存关键截图
- [ ] 列出所有发现的问题
- [ ] 按严重程度分类

## 关键函数检查

在 Time Profiler Call Tree 中：

- [ ] `snapshot()` - 预期 < 50ms，如果 > 100ms 则有严重问题
- [ ] `publishChange()` - 预期 < 100/秒，如果 > 500/秒 则有严重问题
- [ ] `filteredNotes()` - 预期 < 1ms（缓存命中）
- [ ] `persist()` - 预期 < 50ms
- [ ] `mergeSchedules()` - 预期 < 50ms

## 内存泄漏检查

在 Allocations 中：

- [ ] `DaySchedule` 实例数量是否持续增长
- [ ] `Note` 实例数量是否持续增长
- [ ] `rowPositions` 字典大小是否持续增长
- [ ] 整体内存趋势（是否稳定）
