import AgendadaCore
import AppKit
import SwiftUI

@main
struct AgendadaMain {
    @MainActor
    private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.finishLaunching()

        // Load store asynchronously, then finish UI setup.
        // No DispatchGroup blocking — the event loop is running,
        // and the Task executes on MainActor via the run loop.
        Task { @MainActor in
            delegate.store = await delegate.loadStore()
            // Pre-warm editor WebView so the first card tap is instant
            _ = SharedBlockNoteWebView.shared.webView
            delegate.showMainWindow()
        }

        app.run()
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var measurementWindow: NSWindow?
    var store: ObservableLibraryStore!
    private let calendarStore = CalendarStore()

    nonisolated func loadStore() async -> ObservableLibraryStore {
        await ObservableLibraryStore.load()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        // WebView pre-warming and window display are deferred until the
        // store finishes loading (see Task in AgendadaMain.main()).
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "关于 Agendada", action: #selector(NSApp.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "样式测量工具", action: #selector(AppDelegate.showMeasurementWindow), keyEquivalent: "m"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "退出 Agendada", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

        // Edit menu
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        let selectAllItem = NSMenuItem(title: "全选", action: #selector(AppDelegate.selectAllOrBatch), keyEquivalent: "a")
        selectAllItem.target = self
        editMenu.addItem(selectAllItem)
        editMenu.addItem(.separator())
        let deleteNoteItem = NSMenuItem(title: "移到废纸篓", action: #selector(AppDelegate.deleteSelectedOrBatch), keyEquivalent: "\u{0008}")
        deleteNoteItem.keyEquivalentModifierMask = .command
        deleteNoteItem.target = self
        editMenu.addItem(deleteNoteItem)

        // Format menu
        let formatItem = NSMenuItem()
        mainMenu.addItem(formatItem)
        let formatMenu = NSMenu(title: "格式")
        formatItem.submenu = formatMenu

        let fontMenu = NSMenu(title: "字体")
        let fontItem = NSMenuItem(title: "字体", action: nil, keyEquivalent: "")
        fontItem.submenu = fontMenu
        formatMenu.addItem(fontItem)

        fontMenu.addItem(NSMenuItem(title: "显示字体面板", action: #selector(NSFontManager.orderFrontFontPanel(_:)), keyEquivalent: "t"))
        fontMenu.addItem(.separator())

        let boldItem = NSMenuItem(title: "粗体", action: #selector(AppDelegate.toggleBoldViaFontManager), keyEquivalent: "b")
        boldItem.keyEquivalentModifierMask = .command
        fontMenu.addItem(boldItem)

        let italicItem = NSMenuItem(title: "斜体", action: #selector(AppDelegate.toggleItalicViaFontManager), keyEquivalent: "i")
        italicItem.keyEquivalentModifierMask = .command
        fontMenu.addItem(italicItem)

        let underlineItem = NSMenuItem(title: "下划线", action: #selector(AppDelegate.toggleUnderlineViaFontManager), keyEquivalent: "u")
        underlineItem.keyEquivalentModifierMask = .command
        fontMenu.addItem(underlineItem)

        fontMenu.addItem(.separator())
        fontMenu.addItem(NSMenuItem(title: "更大", action: #selector(NSFontManager.modifyFont(_:)), keyEquivalent: "="))
        fontMenu.addItem(NSMenuItem(title: "更小", action: #selector(NSFontManager.modifyFont(_:)), keyEquivalent: "-"))

        // Lists submenu
        let listMenu = NSMenu(title: "列表")
        let listItem = NSMenuItem(title: "列表", action: nil, keyEquivalent: "")
        listItem.submenu = listMenu
        formatMenu.addItem(listItem)
        listMenu.addItem(NSMenuItem(title: "无序列表", action: #selector(AppDelegate.insertBulletList), keyEquivalent: "l"))
        listMenu.addItem(NSMenuItem(title: "有序列表", action: #selector(AppDelegate.insertNumberedList), keyEquivalent: "o"))
        listMenu.addItem(NSMenuItem(title: "任务列表", action: #selector(AppDelegate.insertChecklist), keyEquivalent: "t"))
    }

    // Menu action helpers — operate on first-responder NSTextView

    @objc private func toggleBoldViaFontManager() {
        toggleTrait(.boldFontMask)
    }

    @objc private func toggleItalicViaFontManager() {
        toggleTrait(.italicFontMask)
    }

    @objc private func toggleUnderlineViaFontManager() {
        guard let tv = currentEditor else { return }
        toggleUnderline(on: tv)
    }

    @objc private func insertBulletList() { addListMarkerToEditor("\u{2022} ") }
    @objc private func insertNumberedList() { addListMarkerToEditor("1. ") }
    @objc private func insertChecklist() { addListMarkerToEditor("- [ ] ") }

    private var currentEditor: NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }

    private func toggleTrait(_ trait: NSFontTraitMask) {
        guard let tv = currentEditor, let ts = tv.textStorage else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }
        let fm = NSFontManager.shared
        ts.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            if fm.traits(of: font).contains(trait) {
                ts.addAttribute(.font, value: fm.convert(font, toNotHaveTrait: trait), range: attrRange)
            } else {
                ts.addAttribute(.font, value: fm.convert(font, toHaveTrait: trait), range: attrRange)
            }
        }
        tv.didChangeText()
    }

    private func toggleUnderline(on tv: NSTextView) {
        guard let ts = tv.textStorage else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }
        ts.enumerateAttribute(.underlineStyle, in: range) { value, attrRange, _ in
            let cur = (value as? Int) ?? 0
            if cur == NSUnderlineStyle.single.rawValue {
                ts.removeAttribute(.underlineStyle, range: attrRange)
            } else {
                ts.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: attrRange)
            }
        }
        tv.didChangeText()
    }

    private func addListMarkerToEditor(_ marker: String) {
        guard let tv = currentEditor else { return }
        let text = tv.string as NSString
        let range = tv.selectedRange()
        let lineRange = text.lineRange(for: range)
        let lineText = text.substring(with: lineRange)
        if lineText.hasPrefix(marker) { return }
        tv.setSelectedRange(lineRange)
        tv.insertText(marker, replacementRange: NSRange(location: lineRange.location, length: 0))
    }

    @objc private func deleteSelectedOrBatch() {
        if !store.batchSelectedNoteIDs.isEmpty {
            store.batchDeleteNotes(store.batchSelectedNoteIDs)
        } else if let selectedID = store.selectedNoteID {
            store.deleteNote(selectedID)
        }
    }

    @objc private func selectAllOrBatch() {
        if let firstResponder = NSApp.keyWindow?.firstResponder,
           firstResponder is NSTextView || firstResponder is NSTextField {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            return
        }
        store.selectAllFilteredNotes()
    }

    @objc private func showMeasurementWindow() {
        if let measurementWindow {
            measurementWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = StyleMeasurementView()
            .frame(width: 600, height: 700)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "样式测量工具"
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        self.measurementWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func showMainWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = ContentView()
            .environment(store)
            .environment(calendarStore)
            .frame(minWidth: 1060, minHeight: 680)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1160, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Agendada"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flushPendingSaveSync()
    }
}
