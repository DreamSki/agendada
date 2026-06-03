# 性能测试结果目录

## 已保存的测试结果

- `baseline_IDLE.trace` - 场景 1：基线测量（空闲 30 秒）

## 下一步测试

- 场景 2：笔记操作（20 个笔记创建/编辑/切换）
- 场景 3：无限滚动（2 分钟）
- 场景 4：搜索性能（输入测试）
- 场景 5：批量操作
- 场景 6：长时间运行（10 分钟）

## 如何查看结果

在 Instruments 中打开 trace 文件：
```bash
open baseline_IDLE.trace
```

然后按照 `baseline-analysis.md` 的说明查看数据。
