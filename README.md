# Agendada

**macOS 原生笔记与项目管理应用** — SwiftUI + Swift Package Manager，双 target 架构。

Agendada 以时间线驱动的工作流组织笔记与日程：三栏布局中，左侧导航项目与分类，中间是卡片式笔记流，右侧面板整合系统日历事件、提醒事项与排期笔记的时间轴。内置 BlockNote 富文本编辑器，支持多格式文本、颜色标注、拖拽排序和批量操作。

## 功能概览

### 核心布局与导航

- **三栏自适应布局** — 侧栏（240 pt）+ 笔记流（弹性宽度）+ 右侧面板（340 pt）
- **概览过滤器** — 今天 / 当前焦点 / 全部笔记，快速切换视角
- **分类与项目** — 多级组织（分类 → 项目 → 笔记），支持重命名、归档、颜色标记
- **智能概览** — 保存搜索条件为自定义视图

### 笔记与编辑

- **BlockNote 富文本编辑器** — 嵌入式 WebView 编辑器，支持段落、标题、列表、引用等块级元素
- **实时预览对齐** — 卡片预览与编辑器渲染精确同步，高度自动适配
- **9 色颜色标记** — accent / red / green / blue / yellow / brown / pink / purple / gray
- **置顶 / 置底** — PinState 排序，拖拽设置边界位置
- **完成与归档** — 完成笔记视觉变灰，归档笔记从主流中隐藏
- **排期系统** — 自定义日历面板指定日期，卡片日期显示（今天 amber 加粗）
- **批量操作** — 多选后批量修改颜色、状态、排期、移动项目
- **搜索与高亮** — 全文搜索（标题 / 正文 / 标签），命中高亮

### 时间轴与日历集成

- **右侧面板时间轴** — 日历事件 + 提醒事项 + 排期笔记混合显示，无限滚动
- **系统日历接入** — EventKit 读取 Exchange / iCloud / Google 等账户的日历事件
- **提醒事项集成** — EventKit 读取系统提醒，支持有日期 / 无日期分开处理
- **源筛选** — 按日历账户或提醒列表筛选显示
- **时间轴笔记图标** — 点击日期行笔记图标可查看关联笔记列表并跳转
- **上下文菜单** — 时间轴条目右键操作

### 标签系统

- **标签管理器** — 独立窗口，创建 / 重命名 / 删除 / 合并 / 搜索
- **标签着色** — 自动为标签分配视觉样式

### 浮动菜单与交互

- **浮动快捷菜单** — 快速访问常用操作
- **玻璃拟态弹出层** — 自定义 popover 样式

## 项目结构

```
Sources/
  AgendadaCore/                        # 数据模型 + 业务逻辑
    Models.swift                       # Note, Project, ProjectCategory, NoteColor, PinState, NoteStatus
    LibraryStore.swift                 # 核心状态管理、过滤、搜索、排序
    LibrarySnapshot.swift              # Codable 持久化快照
    FileLibraryRepository.swift        # JSON 文件读写（Actor 隔离）
    CalendarModels.swift               # DaySchedule, CalendarSource, TimelineItem
    CalendarRepository.swift           # EventKit 封装：日历事件 + 提醒事项
    DragPayload.swift                  # 拖拽排序数据载荷
    AutoPerformanceMonitor.swift       # 性能监控

  Agendada/                            # SwiftUI 界面
    AgendadaApp.swift                  # 应用入口，WebView 预热，异步加载
    ContentView.swift                  # 三栏 HStack 主布局
    SidebarView.swift                  # 左侧导航（概览 / 分类 / 项目 / 底栏胶囊）
    NoteStreamView.swift               # 中间笔记卡片流（展开 / 紧凑双态）
    RelatedPanelContentView.swift      # 右侧面板（时间轴 + 最近编辑 + 相关笔记）
    BlockNoteCardEditorView.swift      # 卡片内嵌 BlockNote 编辑器
    BlockNotePreviewView.swift         # 块级预览渲染
    NoteEditorView.swift               # 编辑器容器视图
    CalendarStore.swift                # @Observable 日历状态管理
    TimelineDateRow.swift              # 时间轴日期行
    TimelineEventRow.swift             # 日历事件行
    TimelineReminderRow.swift          # 提醒事项行
    TagManagerView.swift               # 标签管理器窗口
    DateAgendaPanelView.swift          # 日期排期面板
    AgendadaFloatingMenu.swift         # 浮动快捷菜单
    AgendadaPopoverChrome.swift        # 玻璃拟态弹出层样式
    DesignTokens.swift                 # AgendaColor / AgendaFont / AgendaSpacing / AgendaIcon
    ObservableLibraryStore.swift       # @Observable 状态包装层
    StyleCalculator.swift              # 预览-编辑器样式计算
    StyleMeasurementView.swift         # 样式度量
    CollapsibleSection.swift           # 可折叠区段
    ContextMenuItem.swift              # 上下文菜单项
    PanelEmptyStateView.swift          # 空状态占位
    PlainGrowingTextView.swift         # 自适应高度文本输入
    SharedViews.swift                  # 共享 UI 组件
    NotesListView.swift                # 笔记列表视图
    EditorView.swift                   # 独立编辑器（备用）
    AutoPerformanceMonitor.swift       # 界面层性能监控

  Agendada/Resources/BlockNoteEditor/  # 富文本编辑器前端资源
    index.html
    assets/                            # 编辑器 JS/CSS 资源

Tests/
  AgendadaTests/                       # Swift Testing 框架测试
```

## 构建与运行

```bash
# 编译
swift build

# 运行测试
swift test

# 启动应用
open .build/debug/Agendada

# 或构建为 .app 包
scripts/build_app.sh
open dist/Agendada.app
```

**系统要求**：macOS 14.0+ · Swift 6

**数据持久化**：JSON 格式，存储在 `~/Library/Application Support/Agendada/Library.json`，保存时自动创建备份。

## 设计令牌

| 用途 | 值 |
|------|-----|
| 主色 (amber) | `#F5A623` |
| 侧栏背景 | `#F5F5F7` · 选中 `#E3E3E3` |
| 面板背景 | `#FAFAFA` |
| 卡片激活 | 填充 `#FFFCF5` · 边框 `#F5E5C0` · 拖拽柄 `#F0D59B` |
| 正文文本 | `#333333` · 辅助 `#8E8E93` |
| 底栏胶囊 | `#EEEEEE` · Capsule 形状 |
| 卡片样式 | 圆角 12 px · 间距 32 px · 内边距 20 px |

## 路线图

### P2 — 编辑器与集成

- [ ] 右键上下文菜单（文本/字符样式、列表、插入、复制格式）
- [ ] 模板管理 UI
- [ ] 搜索增强（搜索语法、高级筛选、排序切换）
- [ ] 智能概览创建
- [ ] 时间轴无权限降级（未授权仍展示本地排期）
- [ ] 笔记间链接（`[[` 触发自动完成、反向链接）
- [ ] 双向同步（笔记 ↔ 日历/提醒）

### P3 — 高级功能

- [ ] 外部对象关联模型（笔记 ↔ 日历事件 ↔ 提醒 ↔ 附件多对多关联）
- [ ] 导入导出（Markdown / PDF / RTF / HTML / TextBundle）
- [ ] 偏好设置窗口
- [ ] 附件系统（拖放上传、多种显示模式）
- [ ] 笔记锁定（Touch ID / 密码）
- [ ] 导航快捷键
- [ ] 笔记拆分 / 合并、多选批量操作

### P4 — 生态系统

- [ ] 系统集成（AppleScript、URL Scheme、分享扩展、Web Clipper）
- [ ] Widget / Spotlight / Siri
- [ ] 云同步（iCloud CloudKit、Dropbox）

## 技术栈

- **UI 框架**：SwiftUI + AppKit
- **状态管理**：Swift Observation 框架（`@Observable`）
- **编辑器**：BlockNote（嵌入式 WKWebView）
- **日历/提醒**：EventKit
- **持久化**：JSON 文件（Actor 隔离的 FileLibraryRepository）
- **并发模型**：Swift Concurrency（async/await、Actor）
- **构建系统**：Swift Package Manager · Swift 6 语言模式
- **测试**：Swift Testing 框架
