# Agendada

macOS 笔记与项目管理应用，SwiftUI + SPM 两 target 结构。

## 构建命令

```bash
swift build          # 编译
swift test           # 运行 22 个测试
open .build/debug/Agendada  # 启动
```

## 项目结构

```
Sources/
  AgendadaCore/         # 数据模型 + 业务逻辑
    Models.swift        # Note, Project, ProjectCategory, NoteColor, PinState, NoteStatus 等
    LibraryStore.swift  # 核心状态管理、过滤、搜索、排序
    LibrarySnapshot.swift  # Codable 持久化快照
    FileLibraryRepository.swift  # JSON 文件读写 (~/Library/Application Support/Agendada/Library.json)
  Agendada/             # SwiftUI 界面
    ContentView.swift   # 三栏 HStack 布局（侧栏260 + 内容flex + 右侧面板340）
    SidebarView.swift   # 左侧导航（概览/分类/项目/底栏胶囊）
    NoteStreamView.swift  # 中间内容区（笔记卡片流、展开/紧凑双态、自定义日期面板）
    RelatedPanelView.swift  # 右侧面板（旧文件，已废弃，待清理）
    RelatedPanelContentView.swift  # 右侧面板（时间轴统计/快捷日期/日历区/提醒区/最近编辑/相关笔记）
    TagManagerView.swift  # 标签管理器（新建/重命名/删除/合并/搜索）
    EditorView.swift    # 独立编辑器视图（备用）
    DesignTokens.swift  # AgendaColor/AgendaFont/AgendaSpacing/AgendaIcon
    ObservableLibraryStore.swift  # @Observable 包装层
```

## 设计令牌关键值

- 主色 amber: #F5A623 (rgb: 0.961, 0.651, 0.137)
- 侧栏背景: #F5F5F7, 选中: #E3E3E3
- 面板背景: #FAFAFA
- 卡片激活: 填充 #FFFCF5, 边框 #F5E5C0, 拖拽柄 #F0D59B
- 文本: 正文 #333333, 辅助 #8E8E93
- 底栏胶囊: #EEEEEE, Capsule 形状
- 卡片: 圆角 12px, 间距 32px, 内边距 20px

## 已实现功能

- 三栏布局 + 设计令牌体系
- 笔记颜色标记（9色: accent/red/green/blue/yellow/brown/pink/purple/gray）
- 置顶/置底（PinState: none/pinnedTop/pinnedBottom，排序优先级最高）
- 完成/已归档笔记视觉变灰（.secondary 前景色）
- 右侧面板（时间轴信息、集成引导卡、最近编辑、相关笔记）
- 展开笔记卡片的日期文字显示（今天 amber 加粗，其他日期 muted）
- 自定义日历面板（月历网格 + 事件小圆点 + "今天"跳转 + 月份导航 + 指定/取消/清除）
- 右侧面板时间轴统计（今天/明天/昨天/逾期/本周待办笔记数）
- 快捷日期操作（今晚/明天/本周末/下周 一键排期）
- 日历事件 & 提醒事项接入入口（P2 实现实际集成）
- 日期导航（展开笔记前后翻页箭头 + 回到今天按钮）
- 标签管理器（新建/重命名/删除/合并/搜索，工具栏入口）
- TimelineCounts 数据结构 + scheduleDate/clearScheduledDate API
- tagCounts + renameTag/deleteTag/mergeTag API

---

## 任务清单

### P1 — 核心交互

- [x] **右侧面板完善** — 时间轴显示今天/明天/昨天笔记数、即将到期/过期提示；日期快捷操作行（今晚/明天/本周末/下周）；日历事件区；提醒事项区
- [x] **日期导航** — 展开笔记中前一天/后一天翻页按钮、回到今天按钮
- [x] **标签管理器** — 标签浏览器窗口（创建/重命名/删除/合并/搜索），从工具栏入口打开

### P2 — 编辑器与集成

- [ ] **右键上下文菜单** — 文本样式、字符样式、列表类型、插入（日期/链接/表格/代码块）、复制格式（纯文本/Markdown/HTML）
- [ ] **模板管理 UI** — 模板列表、从笔记保存为模板、新建模板、模板预览
- [ ] **搜索增强** — 搜索语法提示、高级筛选（段落类型/列表类型/内容类型）、排序切换、从搜索创建智能概览
- [ ] **日历事件关联** — EventKit 权限、读取系统日历、笔记关联日历事件、新建/编辑日历事件、在日历 App 中打开
- [ ] **提醒事项集成** — Reminders 权限、读取提醒列表、笔记中插入提醒、标记完成、在提醒 App 中打开
- [ ] **笔记间链接** — 键入 `[[` 触发搜索自动完成、插入链接、应用内链接 `app://`、反向链接显示

### P3 — 高级功能

- [ ] **导入导出** — Markdown/PDF/RTF/HTML/TextBundle 导出、Markdown 导入、批量导出
- [ ] **偏好设置窗口** — 通用/外观/日历/账户四个标签页
- [ ] **附件系统** — 拖放上传、显示模式（缩略图/内嵌/全宽）、文件链接（Control+拖放）、大文件警告
- [ ] **笔记锁定** — Touch ID/密码锁定、私密笔记隐藏（isLocked 字段已有，缺 UI）
- [ ] **导航快捷键** — 底栏胶囊前后导航启用、Cmd+F 笔记内搜索、搜索高亮
- [ ] **笔记高级操作** — 拆分/合并、单独窗口打开、多选批量操作、撤销/重做

### P4 — 生态系统

- [ ] **系统集成** — AppleScript、URL Scheme（app://）、分享扩展、Web Clipper
- [ ] **Widget/Spotlight/Siri** — 菜单栏小组件、桌面 Widget、Spotlight 索引、Siri 快捷指令
- [ ] **云同步** — iCloud（CloudKit）、Dropbox、端到端加密提示、冲突解决
