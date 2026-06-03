# Agendada

macOS 笔记与项目管理应用，SwiftUI + SPM 两 target 结构。

## 构建命令

```bash
swift build          # 编译
swift test           # 运行 77 个测试
open .build/debug/Agendada  # 启动
```

## 项目结构

```
Sources/
  AgendadaCore/                        # 数据模型 + 业务逻辑
    Models.swift                       # Note, Project, ProjectCategory, NoteColor, PinState, NoteStatus 等
    LibraryStore.swift                 # 核心状态管理、过滤、搜索、排序
    LibrarySnapshot.swift              # Codable 持久化快照
    FileLibraryRepository.swift        # JSON 文件读写，Actor 隔离 (~/Library/Application Support/Agendada/Library.json)
    CalendarModels.swift               # DaySchedule, CalendarSource, TimelineItem 等日历数据模型
    CalendarRepository.swift           # EventKit 封装：读取日历事件、提醒事项，支持源过滤
    DragPayload.swift                  # 拖拽排序数据载荷
    AutoPerformanceMonitor.swift       # 核心层性能监控

  Agendada/                            # SwiftUI 界面
    AgendadaApp.swift                  # 应用入口，WebView 预热，异步加载
    ContentView.swift                  # 三栏 HStack 布局（侧栏260 + 内容flex + 右侧面板340）
    SidebarView.swift                  # 左侧导航（概览/分类/项目/底栏胶囊）
    NoteStreamView.swift               # 中间内容区（笔记卡片流、展开/紧凑双态、自定义日期面板）
    RelatedPanelContentView.swift      # 右侧面板（时间轴 2/5 + 最近编辑 3/10 + 相关笔记 3/10，三区独立滚动）
    BlockNoteCardEditorView.swift      # 卡片内嵌 BlockNote 富文本编辑器（WKWebView）
    BlockNotePreviewView.swift         # 块级预览渲染
    NoteEditorView.swift               # 编辑器容器视图
    StyleCalculator.swift              # 预览-编辑器样式同步计算
    StyleMeasurementView.swift         # 样式度量
    CalendarStore.swift                # @Observable 日历状态管理（排期笔记、源筛选、无限滚动加载）
    TimelineView.swift                 # 时间轴主视图（ScrollView + LazyVStack 无限滚动）
    TimelineDateRow.swift              # 日期行（笔记图标+popover、日历事件色条、提醒事项空心圆）
    TimelineEventRow.swift             # 日历事件行
    TimelineReminderRow.swift          # 提醒事项行
    TagManagerView.swift               # 标签管理器（新建/重命名/删除/合并/搜索）
    DateAgendaPanelView.swift          # 日期排期面板（月历网格 + 今天跳转 + 月份导航）
    AgendadaFloatingMenu.swift         # 浮动快捷菜单
    AgendadaPopoverChrome.swift        # 玻璃拟态弹出层样式
    CollapsibleSection.swift           # 可折叠区段
    ContextMenuItem.swift              # 上下文菜单项
    PanelEmptyStateView.swift          # 空状态占位
    PlainGrowingTextView.swift         # 自适应高度文本输入
    SharedViews.swift                  # 共享 UI 组件
    NotesListView.swift                # 笔记列表视图
    EditorView.swift                   # 独立编辑器视图（备用）
    DesignTokens.swift                 # AgendaColor/AgendaFont/AgendaSpacing/AgendaIcon
    ObservableLibraryStore.swift       # @Observable 状态包装层
    AutoPerformanceMonitor.swift       # 界面层性能监控

  Agendada/Resources/BlockNoteEditor/  # 富文本编辑器前端资源
    index.html
    assets/                            # 编辑器 JS/CSS 资源（21 个文件）

Tests/
  AgendadaTests/                       # Swift Testing 框架测试（77 个用例）
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
- 置顶/置底（PinState: none/pinnedTop/pinnedBottom，排序优先级最高，拖拽设置边界）
- 完成/已归档笔记视觉变灰（.secondary 前景色）
- 笔记排期（自定义日历面板 + 笔记卡片日期显示，今天 amber 加粗）
- BlockNote 富文本编辑器集成（嵌入式 WKWebView，支持段落/标题/列表/引用等块级元素）
- 卡片预览-编辑器实时对齐（StyleCalculator + StyleMeasurementView 自动同步高度与样式）
- 搜索高亮（全文搜索命中关键词高亮显示）
- 批量操作（多选后批量修改颜色、状态、排期、移动项目）
- 模板选择器（从模板库新建笔记）
- 浮动快捷菜单 + 玻璃拟态弹出层
- 拖拽排序（DragPayload，sparse-gap 位置系统，项目内排序）
- 右侧面板时间轴（日历事件 + 提醒事项 + 排期笔记 混合显示，无限滚动，源筛选）
- 日历事件关联（EventKit 读取系统日历，Exchange/iCloud/Google 账户均支持）
- 提醒事项集成（EventKit 读取系统提醒，带日期/无日期分开处理）
- 时间轴笔记图标 + popover 笔记列表（点击跳转到对应笔记）
- 时间轴上下文菜单
- 标签管理器（新建/重命名/删除/合并/搜索）
- CalendarStore（@Observable 状态管理，排期笔记合并，来源筛选，无限滚动加载）
- Actor 并发模型（FileLibraryRepository Actor 隔离，Swift Concurrency async/await）
- WebView 生命周期管理（generation-based 防竞态，预加载预热）
- 本地 JSON 持久化 + 自动备份（保存时创建 .previous 备份）

---

## 任务清单

### P1 — 核心交互

- [x] **右侧面板时间轴** — 日历事件 + 提醒事项 + 排期笔记混合显示，无限滚动，源筛选，笔记图标 popover
- [x] **日历事件集成** — EventKit 读取系统日历（Exchange/iCloud/Google），含事件色条、时间显示
- [x] **提醒事项集成** — EventKit 读取系统提醒，含空心圆图标、到期状态
- [x] **标签管理器** — 标签浏览器窗口（创建/重命名/删除/合并/搜索），从工具栏入口打开（🔄 后续需重新规划增强）
- [x] **日期导航** — ~~展开笔记中前一天/后一天翻页按钮、回到今天按钮~~（已废弃，由时间轴点击跳转取代）

### P2 — 编辑器与集成

- [ ] **右键上下文菜单** — 文本样式、字符样式、列表类型、插入（日期/链接/表格/代码块）、复制格式（纯文本/Markdown/HTML）
- [ ] **模板管理 UI** — 模板列表、从笔记保存为模板、新建模板、模板预览
- [ ] **搜索增强** — 搜索语法提示、高级筛选（段落类型/列表类型/内容类型）、排序切换
- [ ] **智能概览创建** — 在 NoteStreamView 搜索弹出框中添加"保存为智能概览"按钮（参考 NotesListView.swift 实现）
- [ ] **时间轴无权限降级** — 未授权日历/提醒事项时仍展示本地排期笔记时间轴，仅在顶部或空状态提示连接系统日历/提醒可显示更多
- [ ] **笔记间链接** — 键入 `[[` 触发搜索自动完成、插入链接、应用内链接 `app://`、反向链接显示
- [ ] **双向同步（笔记↔日历/提醒）** — 写笔记时如有待办可直接创建提醒事项或日历事件，标记完成时同步回笔记

### P3 — 高级功能

- [ ] **标签管理器增强** — 重新规划交互设计，提升标签管理体验
- [ ] **外部对象关联模型** — 建立 Agendada 的通用关系层，让笔记、日历事件、提醒事项、URL、附件、联系人、项目等对象可以互相关联，形成"万物皆可互联"的工作网络。核心原则：关联不等于排期，`scheduledDate` 只表达"这条笔记属于/安排在哪一天"，ExternalLink/Relation 表达"这条笔记与哪个外部对象有关"。例如 27 号要找老师讨论，今天写的大纲可以关联到 27 号的日程，但这份大纲仍然是今天的笔记；一个笔记可以关联多个日程/提醒，单个日程/提醒也可以关联多条准备材料、会议记录、后续行动。需要支持多对多、双向查看、关系类型（准备材料/会议记录/后续行动/参考资料/阻塞/自定义）、来源快照（标题、日期、URL、日历/列表名称）、失效恢复（外部 ID 变化或对象删除后仍保留可读线索）、搜索/筛选、时间轴中的关联提示，以及未来 AI 基于关系图自动推荐关联、补全上下文、生成会前材料和会后行动项。
- [ ] **导入导出** — Markdown/PDF/RTF/HTML/TextBundle 导出、Markdown 导入、批量导出
- [ ] **偏好设置窗口** — 通用/外观/日历/账户四个标签页
- [ ] **附件系统** — 拖放上传、显示模式（缩略图/内嵌/全宽）、文件链接（Control+拖放）、大文件警告
- [ ] **笔记锁定** — Touch ID/密码锁定、私密笔记隐藏（isLocked 字段已有，缺 UI）
- [ ] **导航快捷键** — 底栏胶囊前后导航启用、Cmd+F 笔记内搜索、搜索高亮
- [ ] **笔记高级操作** — 拆分/合并、单独窗口打开、~~多选批量操作~~（已完成）、撤销/重做

### P4 — 生态系统

- [ ] **系统集成** — AppleScript、URL Scheme（app://）、分享扩展、Web Clipper
- [ ] **Widget/Spotlight/Siri** — 菜单栏小组件、桌面 Widget、Spotlight 索引、Siri 快捷指令
- [ ] **云同步** — iCloud（CloudKit）、Dropbox、端到端加密提示、冲突解决
