# 🎯 性能监控测试指南

## 应用已启动 ✅

你的 Agendada 现在运行中（PID: 39107），并且已经启用了性能监控。

---

## 📋 现在执行测试（5 分钟）

### 测试 1：查看启动日志

```bash
# 在终端运行
tail -f /tmp/agendada-perf.log
```

**预期看到**：
- 如果有性能问题，会看到类似：
  ```
  ⚠️ [PERF] snapshot() took 0.125s
  ⚠️ [PERF] filteredNotes took 0.089s
  ```

### 测试 2：执行快速笔记操作

在 Agendada 中执行以下操作 10 次：

1. 点击 **+ 按钮**（新建笔记）
2. 输入标题
3. 输入几个字符的正文
4. 按 **ESC** 退出编辑

**观察终端输出**，你应该看到类似：

```
📢 [PERF] publishChange called from: ...
🔄 [PERF] filteredNotes recalculating...
🔖 [PERF] persist() started
⏱️ [PERF] snapshot() took 0.XXXs
```

### 测试 3：快速切换笔记

1. 创建 5 个笔记
2. 快速点击每个笔记切换

**观察**：
- `publishChange` 调用频率
- `filteredNotes` 是否频繁重新计算

---

## 🔍 关键指标解释

### 你会看到的日志格式：

#### 1. publishChange 调用
```
📢 [PERF] publishChange called from: AgendadaNoteRow.setFocused(_:)
```
- **含义**：状态变化，触发全局刷新
- **频率**：如果每次操作都看到，说明频繁
- **问题**：如果 1 秒内 > 10 次

#### 2. filteredNotes 重新计算
```
🔄 [PERF] filteredNotes recalculating...
⚠️ [PERF] filteredNotes took 0.089s - result count: 50
```
- **含义**：缓存失效，重新计算
- **耗时**：应该 < 10ms，如果 > 50ms 有问题
- **问题**：如果频繁出现，说明缓存策略失效

#### 3. snapshot 执行
```
🔖 [PERF] persist() started
⏱️ [PERF] snapshot() took 0.156s - notes: 25
```
- **含义**：正在保存数据
- **耗时**：应该 < 20ms，如果 > 50ms 说明数据量大或序列化慢
- **问题**：如果每次操作都触发，说明 debounce 失效

---

## 📊 问题判断标准

### 如果看到这些 → 有问题

| 日志模式 | 含义 | 严重性 |
|---------|------|--------|
| `snapshot() took > 0.050s` | 序列化阻塞 | 🔴 Critical |
| `filteredNotes took > 0.050s` | 过滤计算慢 | ⚠️ Warning |
| `publishChange called from:` 每 < 100ms 出现 | 级联刷新 | 🔴 Critical |
| `filteredNotes recalculating...` 频繁出现 | 缓存失效频繁 | ⚠️ Warning |

---

## 🎯 现在立即测试

### 方式 A：在终端中实时查看

```bash
# 实时查看日志
tail -f /tmp/agendada-perf.log

# 然后在 Agendada 中执行操作
```

### 方式 B：使用 Console.app

```bash
# 打开 Console 应用
open -a "Console"

# 在搜索框输入 "PERF"
# 执行 Agendada 操作，实时观察
```

---

## 📝 记录你的观察

执行 10 次笔记操作后，告诉我：

### 问题 1：snapshot() 执行

```
是否出现 "snapshot() took" 日志？
出现次数：____
最大耗时：____ s
```

### 问题 2：publishChange 频率

```
是否频繁看到 "publishChange called from"？
每秒大约出现：____ 次
```

### 问题 3：filteredNotes 重新计算

```
是否频繁看到 "filteredNotes recalculating"？
最大耗时：____ s
```

### 问题 4：总体感受

```
操作时是否卡顿？
- [ ] 是，明显卡顿
- [ ] 偶尔卡顿
- [ ] 不卡顿

卡顿发生在：
- [ ] 创建笔记时
- [ ] 输入标题时
- [ ] 切换笔记时
- [ ] 其他
```

---

## 🚀 快速测试步骤

1. **打开终端**：
   ```bash
   tail -f /tmp/agendada-perf.log
   ```

2. **在 Agendada 中**：
   - 快速执行 10 次：新建 → 输入标题 → ESC

3. **停止终端查看日志**（按 Ctrl+C）

4. **告诉我**：
   - 看到了哪些 `[PERF]` 日志？
   - 哪个函数耗时最长？
   - 是否有卡顿的感觉？

---

**准备好了吗？** 现在就开始测试，然后把日志结果告诉我！
