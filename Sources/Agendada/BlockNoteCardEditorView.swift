import AgendadaCore
import AppKit
import SwiftUI
import WebKit

struct BlockNoteEditorContent: Equatable {
    var noteID: Note.ID
    var blockJSON: Data
    var plainTextPreview: String
    var previewHTML: String?
}

struct NoteLinkSearchResult {
    let id: Note.ID
    let title: String
    let project: String
}

@MainActor
struct BlockNoteCardEditor: NSViewRepresentable {
    let noteID: Note.ID
    let blockJSON: Data
    @Binding var editorHeight: CGFloat
    var onChange: (BlockNoteEditorContent) -> Void
    var onDebouncedSave: (BlockNoteEditorContent) -> Void
    var onReady: (() -> Void)?
    var onNoteLinkSearch: ((String, Note.ID?) -> [NoteLinkSearchResult])?
    var onNoteLinkNavigate: ((Note.ID) -> Void)?

    func makeNSView(context: Context) -> NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let bridge = SharedBlockNoteWebView.shared
        let didAttach = bridge.attach(to: nsView)
        bridge.onChange = onChange
        bridge.onDebouncedSave = onDebouncedSave
        bridge.onReady = onReady
        bridge.onNoteLinkSearch = onNoteLinkSearch
        bridge.onNoteLinkNavigate = onNoteLinkNavigate
        bridge.onHeightChange = { height in
            guard bridge.readyForHeight else { return }
            let h = max(1, height)
            if abs(editorHeight - h) > 1 { editorHeight = h }
        }
        bridge.loadCard(noteID: noteID, blockJSON: blockJSON, didAttach: didAttach)
        bridge.setReadOnly(false)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        SharedBlockNoteWebView.shared.detach(from: nsView)
    }
}

private let agdEditorVerboseLoggingEnabled = false

private func agdEditorLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    if agdEditorVerboseLoggingEnabled {
        print(message())
    }
    #endif
}

@MainActor
final class SharedBlockNoteWebView: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let shared = SharedBlockNoteWebView()

    var onChange: ((BlockNoteEditorContent) -> Void)?
    var onDebouncedSave: ((BlockNoteEditorContent) -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?
    var onReady: (() -> Void)?
    var onNoteLinkSearch: ((String, Note.ID?) -> [NoteLinkSearchResult])?
    var onNoteLinkNavigate: ((Note.ID) -> Void)?
    var hasContentChanges = false
    var readyForHeight = false

    /// An opaque white view placed over the WKWebView while loading.
    /// Removed when the editor signals readiness, guaranteeing no flash.
    private var blockingCover: NSView?

    private var loadedNoteID: Note.ID?
    private var lastLoadedBlockJSON: Data?
    private var pendingLoad: (noteID: Note.ID, blockJSON: Data)?
    private var isReady = false
    private var loadGeneration = 0
    private var selectionRequestGeneration = 0
    private weak var attachedContainer: NSView?
    private weak var currentLoadSuperview: NSView?
    private var pendingSearchNavigation: (noteID: Note.ID, query: String, bodyIndex: Int)?

    private struct PreparedEditorBundle {
        let editorURL: URL
        let readAccessURL: URL
    }

    /// Cached prepared bundle to avoid redundant file copies on every launch
    private var cachedPreparedBundle: PreparedEditorBundle?

    private struct AssetImportResponse: Encodable {
        var ok: Bool
        var assetId: String?
        var url: String?
        var name: String?
        var caption: String?
        var showPreview: Bool?
        var error: String?
    }

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
#if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif

        let controller = config.userContentController
        controller.addUserScript(WKUserScript(source: offlineNetworkGuardScript(), injectionTime: .atDocumentStart, forMainFrameOnly: false))
        ["cardChanged", "cardSaved", "editorFocused", "editorBlurred", "requestAssetImport", "editorHeight", "editorReady", "cardLoaded", "noteLinkSearch", "noteLinkNavigate"].forEach {
            controller.add(self, name: $0)
        }

        let view = PasteInterceptWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.wantsLayer = true
        view.clipsToBounds = false
        view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.allowsMagnification = false
        view.magnification = 1.0
        if #available(macOS 11.0, *) {
            view.pageZoom = 1.0
        }
        view.pasteHandler = { [weak self] in self?.handleFinderPaste() ?? false }
        if let bundle = preparedEditorBundle() {
            agdEditorLog("Agendada BlockNote editor loading local bundle: \(bundle.editorURL.path)")
            view.loadFileURL(bundle.editorURL, allowingReadAccessTo: bundle.readAccessURL)
        } else {
            assertionFailure("Missing bundled BlockNote editor resources")
            view.loadHTMLString(blockNoteHTML(), baseURL: nil)
        }
        return view
    }()

    @discardableResult
    func attach(to container: NSView) -> Bool {
        guard webView.superview !== container else {
            agdEditorLog("[AGD] attach SKIP (same container)")
            return false
        }
        loadGeneration += 1
        attachedContainer = container
        agdEditorLog("[AGD] attach webView to new container, wasHidden=\(webView.isHidden)")
        webView.isHidden = true
        webView.alphaValue = 0
        webView.removeFromSuperview()
        // Remove any leftover blocking cover from a previous attach.
        blockingCover?.removeFromSuperview()
        blockingCover = nil

        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Place an opaque cover *above* the WKWebView so that even if the
        // WKWebView paints before SwiftUI removes the preview, nothing leaks
        // through.  The cover is removed when the card is truly ready.
        let cover = NSView()
        cover.wantsLayer = true
        cover.layer?.backgroundColor = NSColor.white.cgColor
        cover.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cover, positioned: .above, relativeTo: webView)
        NSLayoutConstraint.activate([
            cover.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cover.topAnchor.constraint(equalTo: container.topAnchor),
            cover.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        blockingCover = cover

        container.needsLayout = true
        container.layoutSubtreeIfNeeded()
        return true
    }

    func detach(from container: NSView) {
        if webView.superview === container {
            loadGeneration += 1
            if attachedContainer === container {
                attachedContainer = nil
            }
            agdEditorLog("[AGD] detach webView, removing cover")
            webView.isHidden = true
            webView.alphaValue = 0
            blockingCover?.removeFromSuperview()
            blockingCover = nil
            webView.removeFromSuperview()
        }
    }

    func loadCard(noteID: Note.ID, blockJSON: Data, didAttach: Bool = false) {
        let expectedSuperview = webView.superview
        agdEditorLog("[AGD] loadCard note=\(noteID.uuidString.prefix(8)) didAttach=\(didAttach) isReady=\(isReady) loadedNoteID=\(loadedNoteID?.uuidString.prefix(8) ?? "nil")")
        guard isReady else {
            agdEditorLog("[AGD] NOT ready, storing pendingLoad")
            pendingLoad = (noteID, blockJSON)
            return
        }

        guard loadedNoteID != noteID || lastLoadedBlockJSON != blockJSON else {
            currentLoadSuperview = expectedSuperview
            if didAttach {
                let generation = loadGeneration
                DispatchQueue.main.async { [weak self] in
                    self?.revealEditorIfCurrent(noteID: noteID, generation: generation, expectedSuperview: expectedSuperview)
                }
            }
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        currentLoadSuperview = expectedSuperview

        // Gate height reports briefly so BlockNote's initial 122→53 px
        // jitter doesn't resize the card. Reduced from 250ms→120ms for snappier feel.
        readyForHeight = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, generation == self.loadGeneration else { return }
            self.readyForHeight = true
        }

        loadedNoteID = noteID
        lastLoadedBlockJSON = blockJSON
        hasContentChanges = false
        let blockJSONString = String(data: blockJSON, encoding: .utf8) ?? Note.emptyBlockJSONString
        let script = "window.loadCard(\(jsString(noteID.uuidString)), \(jsString(blockJSONString)), \(generation));"
        webView.evaluateJavaScript(script) { [weak self] _, error in
            guard let self else { return }
            if error != nil {
                self.revealEditorIfCurrent(noteID: noteID, generation: generation, expectedSuperview: expectedSuperview)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.revealEditorIfCurrent(noteID: noteID, generation: generation, expectedSuperview: expectedSuperview)
        }
    }

    private func revealEditorIfCurrent(noteID: Note.ID, generation: Int, expectedSuperview: NSView?) {
        guard let expectedSuperview else { return }
        guard generation == loadGeneration else { return }
        guard loadedNoteID == noteID else { return }
        guard webView.superview === expectedSuperview else { return }
        guard expectedSuperview === attachedContainer else { return }

        let shouldNotifyReady = blockingCover != nil || webView.isHidden || webView.alphaValue < 1
        blockingCover?.removeFromSuperview()
        blockingCover = nil
        webView.isHidden = false
        webView.alphaValue = 1
        webView.needsDisplay = true
        if shouldNotifyReady {
            onReady?()
        }
    }

    func beginSelectionRequest() -> Int {
        selectionRequestGeneration += 1
        return selectionRequestGeneration
    }

    func isCurrentSelectionRequest(_ generation: Int) -> Bool {
        generation == selectionRequestGeneration
    }

    func prepareSearchNavigation(noteID: Note.ID, query: String, bodyIndex: Int) {
        pendingSearchNavigation = (noteID, query, bodyIndex)
    }

    func clearPendingSearchNavigation() {
        pendingSearchNavigation = nil
    }

    func consumeSearchNavigation(for noteID: Note.ID) -> (query: String, bodyIndex: Int)? {
        guard let pending = pendingSearchNavigation, pending.noteID == noteID else { return nil }
        pendingSearchNavigation = nil
        return (pending.query, pending.bodyIndex)
    }

    func focusEditor() {
        webView.evaluateJavaScript("window.focusEditor && window.focusEditor();")
    }

    func setReadOnly(_ isReadOnly: Bool) {
        webView.evaluateJavaScript("window.setReadOnly && window.setReadOnly(\(isReadOnly ? "true" : "false"));")
    }

    var pendingSearchQuery: String?
    var pendingSearchCompletion: ((Int) -> Void)?

    func searchInEditor(query: String, completion: @escaping (Int) -> Void) {
        guard isReady else {
            pendingSearchQuery = query
            pendingSearchCompletion = completion
            return
        }
        let safe = query.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.searchInEditor && window.searchInEditor('\(safe)')") { result, _ in
            completion((result as? Int) ?? 0)
        }
    }

    func navigateMatch(direction: Int, scroll: Bool = true, completion: @escaping (_ current: Int, _ total: Int, _ atBoundary: Bool) -> Void) {
        let shouldScroll = scroll ? "true" : "false"
        webView.evaluateJavaScript("window.navigateMatch && window.navigateMatch(\(direction), \(shouldScroll))") { result, _ in
            if let dict = result as? [String: Any],
               let c = dict["current"] as? Int,
               let t = dict["total"] as? Int {
                let atBoundary = dict["atBoundary"] as? Bool ?? false
                completion(c, t, atBoundary)
            } else {
                completion(0, 0, true)
            }
        }
    }

    func navigateToMatch(index: Int, scroll: Bool = true, completion: @escaping (_ current: Int, _ total: Int) -> Void) {
        let shouldScroll = scroll ? "true" : "false"
        webView.evaluateJavaScript("window.navigateToMatch && window.navigateToMatch(\(index), \(shouldScroll))") { result, _ in
            if let dict = result as? [String: Any],
               let c = dict["current"] as? Int,
               let t = dict["total"] as? Int {
                completion(c, t)
            } else {
                completion(0, 0)
            }
        }
    }

    func clearSearch() {
        pendingSearchQuery = nil
        pendingSearchCompletion = nil
        webView.evaluateJavaScript("window.clearSearch && window.clearSearch();")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""

            // Handle agendada://note/ links for note navigation
            if scheme == "agendada", url.host == "note" {
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let noteID = UUID(uuidString: path) {
                    onNoteLinkNavigate?(noteID)
                }
                decisionHandler(.cancel)
                return
            }

            if scheme == "http" || scheme == "https" {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func saveCurrentContentNow(completion: @escaping (BlockNoteEditorContent?) -> Void) {
        agdEditorLog("[AGD] saveCurrentContentNow isReady=\(isReady) loadedNoteID=\(loadedNoteID?.uuidString.prefix(8) ?? "nil")")
        guard isReady, loadedNoteID != nil else {
            agdEditorLog("[AGD] NOT ready, returning nil")
            completion(nil)
            return
        }

        agdEditorLog("[AGD] evaluating flushCurrentContent JS")
        webView.evaluateJavaScript("window.flushCurrentContent && window.flushCurrentContent();") { [weak self] result, _ in
            Task { @MainActor in
                completion(self?.content(from: result as Any))
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "editorReady":
            agdEditorLog("[AGD] editorReady isReady->true, pendingLoad=\(pendingLoad != nil ? "yes" : "no")")
            isReady = true
            injectMeasurementFunction()
            if let pendingLoad {
                self.pendingLoad = nil
                loadCard(noteID: pendingLoad.noteID, blockJSON: pendingLoad.blockJSON)
            }
            if let q = pendingSearchQuery, !q.isEmpty {
                let cb = pendingSearchCompletion ?? { _ in }
                pendingSearchQuery = nil
                pendingSearchCompletion = nil
                let safe = q.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                webView.evaluateJavaScript("window.searchInEditor && window.searchInEditor('\(safe)')") { result, _ in
                    cb((result as? Int) ?? 0)
                }
            }

        case "cardLoaded":
            guard let dictionary = message.body as? [String: Any],
                  let cardIDString = dictionary["cardId"] as? String,
                  let noteID = UUID(uuidString: cardIDString),
                  let generation = integerValue(from: dictionary["generation"]) else {
                return
            }
            revealEditorIfCurrent(noteID: noteID, generation: generation, expectedSuperview: currentLoadSuperview)

        case "cardChanged":
            guard let content = content(from: message.body), content.noteID == loadedNoteID else { return }
            hasContentChanges = true
            lastLoadedBlockJSON = content.blockJSON
            onChange?(content)

        case "cardSaved":
            guard let content = content(from: message.body), content.noteID == loadedNoteID else { return }
            onDebouncedSave?(content)

        case "editorHeight":
            if let value = message.body as? CGFloat {
                onHeightChange?(value)
            } else if let value = message.body as? Double {
                onHeightChange?(CGFloat(value))
            } else if let value = message.body as? Int {
                onHeightChange?(CGFloat(value))
            }

        case "requestAssetImport":
            handleAssetImport(message.body)

        case "noteLinkSearch":
            handleNoteLinkSearch(message.body)

        case "noteLinkNavigate":
            if let noteIDString = message.body as? String,
               let noteID = UUID(uuidString: noteIDString) {
                onNoteLinkNavigate?(noteID)
            }

        default:
            break
        }
    }

    private func preparedEditorBundle() -> PreparedEditorBundle? {
        // Return cached bundle if available
        if let cached = cachedPreparedBundle {
            return cached
        }

        guard let resourceURL = blockNoteResourceBundleURL() else {
            return nil
        }

        let bundledEditorURL = resourceURL.appending(path: "BlockNoteEditor", directoryHint: .isDirectory)
        let bundledIndexURL = bundledEditorURL.appending(path: "index.html")
        guard FileManager.default.fileExists(atPath: bundledIndexURL.path) else {
            return nil
        }

        let appSupportURL = appSupportDirectory()
        let localEditorURL = appSupportURL.appending(path: "BlockNoteEditor", directoryHint: .isDirectory)
        let localIndexURL = localEditorURL.appending(path: "index.html")
        let versionFile = localEditorURL.appending(path: ".bundle-version")

        // Check if we can skip copying by comparing bundle modification dates
        let fm = FileManager.default
        let bundledModDate = (try? fm.attributesOfItem(atPath: bundledIndexURL.path)[.modificationDate] as? Date) ?? .distantPast
        let localVersionDate = (try? String(contentsOf: versionFile, encoding: .utf8)).flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }

        let needsCopy = localVersionDate == nil || bundledModDate > (localVersionDate ?? .distantPast) || !fm.fileExists(atPath: localIndexURL.path)

        if needsCopy {
            do {
                try fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
                if fm.fileExists(atPath: localEditorURL.path) {
                    try fm.removeItem(at: localEditorURL)
                }
                try fm.copyItem(at: bundledEditorURL, to: localEditorURL)
                // Write version marker
                try String(bundledModDate.timeIntervalSince1970).write(to: versionFile, atomically: true, encoding: .utf8)
            } catch {
                print("Agendada failed to prepare writable BlockNote editor bundle: \(error)")
                let fallback = PreparedEditorBundle(editorURL: bundledIndexURL, readAccessURL: bundledEditorURL)
                cachedPreparedBundle = fallback
                return fallback
            }
        }

        let bundle = PreparedEditorBundle(editorURL: localIndexURL, readAccessURL: appSupportURL)
        cachedPreparedBundle = bundle
        return bundle
    }

    private func blockNoteResourceBundleURL() -> URL? {
        let fileManager = FileManager.default
        let bundleName = "Agendada_Agendada.bundle"
        var candidates: [URL] = []

        candidates.append(Bundle.main.bundleURL.appending(path: bundleName, directoryHint: .isDirectory))

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appending(path: bundleName, directoryHint: .isDirectory))
        }

        if let executableURL = Bundle.main.executableURL {
            candidates.append(executableURL.deletingLastPathComponent().appending(path: bundleName, directoryHint: .isDirectory))
        }

        for candidate in candidates {
            let indexURL = candidate.appending(path: "BlockNoteEditor/index.html")
            if fileManager.fileExists(atPath: indexURL.path) {
                return candidate
            }
        }

        return nil
    }

    private func injectMeasurementFunction() {
        let script = """
        (function() {
          if (window.__agendadaInjected) return;
          window.__agendadaInjected = true;

          var styleEl = document.createElement('style');
          styleEl.id = 'agendada-editor-runtime-styles';
          styleEl.textContent = `
            html, body, #root, .editor-shell { overflow: visible !important; }
            html { font-size: 14px !important; -webkit-text-size-adjust: none !important; }

            /* ── Font baseline: override BlockNote CSS-in-JS ── */
            /* Target ALL possible text elements so font-size is consistent at every level */
            .bn-editor, .bn-editor *,
            .bn-default-styles, .bn-default-styles *,
            .ProseMirror, .ProseMirror * {
              font-family: "Avenir Next", -apple-system, sans-serif !important;
              font-size: 14.12px !important;
              font-weight: 400 !important;
              line-height: 1.65 !important;
              -webkit-font-smoothing: auto !important;
              font-kerning: normal !important;
              font-variant-ligatures: normal !important;
              font-feature-settings: "liga" 1, "kern" 1 !important;
            }
            /* ── Zero out all Mantine/BlockNote/ProseMirror container padding ── */
            .mantine-RichTextEditor-root,
            .mantine-RichTextEditor-content,
            .mantine-RichTextEditor-inner,
            .mantine-RichTextEditor-wrapper,
            .mantine-RichTextEditor-input,
            .bn-container,
            .bn-editor,
            .bn-block-outer, .bn-block, .bn-inline-content,
            .ProseMirror {
              padding: 0 !important;
              margin: 0 !important;
            }

            /* Restore intentional vertical block padding */
            .bn-block-content { padding: 6px 0 !important; }
            /* Restore intentional editor inline padding (0 left, 8px right) */
            .bn-editor { padding-left: 0 !important; padding-right: 8px !important; overflow: visible !important; }

            /* ── Block styles matching SwiftUI preview ── */
            .bn-block-content[data-content-type="codeBlock"],
            .bn-block-content[data-content-type="codeBlock"] * {
              font-family: Menlo, monospace !important;
              font-size: 13px !important;
              font-weight: 400 !important;
              color: #2E2E30 !important;
              background: rgba(0,0,0,0.045) !important;
              border-radius: 6px !important;
              padding: 8px 10px !important;
              line-height: 1.4 !important;
            }
            .bn-block-content[data-content-type="quote"] {
              border-left: 3px solid #F5E5C0 !important;
              padding-left: 10px !important;
            }
            .bn-block-content[data-content-type="divider"] hr {
              border: none !important;
              height: 1px !important;
              background: rgba(0,0,0,0.10) !important;
              margin: 10px 0 !important;
            }
            .bn-block-content[data-content-type="heading"],
            .bn-block-content[data-content-type="heading"] * {
              color: #1A1A1A !important;
              padding-top: 5.5px !important;
              padding-bottom: 5.5px !important;
              font-weight: 700 !important;
              font-size: 17px !important;
            }
            .bn-block-content[data-content-type="heading"][data-level="1"],
            .bn-block-content[data-content-type="heading"][data-level="1"] * {
              padding-top: 18.3px !important;
            }
            .bn-block-content[data-content-type="heading"][data-level="3"],
            .bn-block-content[data-content-type="heading"][data-level="3"] * {
              font-size: 15px !important;
            }
            .bn-editor img { max-width: 100% !important; max-height: 260px !important; object-fit: contain !important; }
            .bn-editor table { width: 100% !important; max-width: 100% !important; table-layout: fixed !important; border-collapse: collapse; }
            .bn-editor td, .bn-editor th { padding: 10px !important; font-size: 14.12px !important; line-height: 1.65 !important; }

            .bn-suggestion-menu { max-height: 350px !important; }
          `;
          document.head.appendChild(styleEl);

          var searchStyleEl = document.createElement('style');
          searchStyleEl.id = 'agendada-search-styles';
          searchStyleEl.textContent = '::highlight(agendada-search) { background-color: #FFE066; color: inherit; } ::highlight(agendada-search-active) { background-color: #F5A623; color: inherit; }';
          document.head.appendChild(searchStyleEl);

          window.__agendadaSearch = { matches: [], currentIdx: -1 };

          window.searchInEditor = function(query) {
            try { CSS.highlights.delete('agendada-search'); } catch(e) {}
            try { CSS.highlights.delete('agendada-search-active'); } catch(e) {}
            window.__agendadaSearch = { matches: [], currentIdx: -1 };
            if (!query || !query.trim()) return 0;
            var keywords = query.toLowerCase().split(/\\s+/).filter(function(k) { return k.length > 0; });
            if (keywords.length === 0) return 0;
            var editor = document.querySelector('.bn-editor') || document.querySelector('.mantine-RichTextEditor-root') || document.getElementById('root');
            if (!editor) return 0;
            var walker = document.createTreeWalker(editor, NodeFilter.SHOW_TEXT);
            var ranges = [];
            while (walker.nextNode()) {
              var node = walker.currentNode;
              if (node.parentElement && (node.parentElement.tagName === 'SCRIPT' || node.parentElement.tagName === 'STYLE')) continue;
              var text = node.textContent.toLowerCase();
              for (var ki = 0; ki < keywords.length; ki++) {
                var kw = keywords[ki];
                var idx = 0;
                while ((idx = text.indexOf(kw, idx)) !== -1) {
                  var r = new Range();
                  r.setStart(node, idx);
                  r.setEnd(node, idx + kw.length);
                  ranges.push(r);
                  idx += kw.length;
                }
              }
            }
            // Sort ranges by document position for sequential navigation
            ranges.sort(function(a, b) { return a.compareBoundaryPoints(Range.START_TO_START, b); });
            if (ranges.length > 0) {
              try {
                var h = CSS.highlights.get('agendada-search') || new Highlight();
                h.clear();
                for (var i = 0; i < ranges.length; i++) { h.add(ranges[i]); }
                CSS.highlights.set('agendada-search', h);
              } catch(e) {}
              window.__agendadaSearch = { matches: ranges, currentIdx: -1 };
              // Do NOT set initial active (orange) highlight or scroll here —
              // navigateToMatch is called right after to set the correct active match.
            }
            return ranges.length;
          };

          window.navigateMatch = function(direction, shouldScroll) {
            var s = window.__agendadaSearch;
            if (!s || s.matches.length === 0) return { current: 0, total: 0 };
            var nextIdx = s.currentIdx + direction;
            // Return boundary info without wrapping — Swift handles note transitions
            if (nextIdx < 0 || nextIdx >= s.matches.length) {
              return { current: s.currentIdx + 1, total: s.matches.length, atBoundary: true };
            }
            s.currentIdx = nextIdx;
            var range = s.matches[s.currentIdx];
            try {
              var ah = CSS.highlights.get('agendada-search-active');
              if (!ah) { ah = new Highlight(); CSS.highlights.set('agendada-search-active', ah); }
              ah.clear(); ah.add(range);
            } catch(e) {}
            if (shouldScroll !== false) {
              try { range.startContainer.parentElement.scrollIntoView({ block: 'center', behavior: 'smooth' }); } catch(e) {}
            }
            return { current: s.currentIdx + 1, total: s.matches.length, atBoundary: false };
          };

          window.navigateToMatch = function(index, shouldScroll) {
            var s = window.__agendadaSearch;
            if (!s || s.matches.length === 0) return { current: 0, total: 0 };
            if (index < 0) index = 0;
            if (index >= s.matches.length) index = s.matches.length - 1;
            s.currentIdx = index;
            var range = s.matches[index];
            try {
              var ah = CSS.highlights.get('agendada-search-active');
              if (!ah) { ah = new Highlight(); CSS.highlights.set('agendada-search-active', ah); }
              ah.clear(); ah.add(range);
            } catch(e) {}
            if (shouldScroll !== false) {
              try { range.startContainer.parentElement.scrollIntoView({ block: 'center', behavior: 'smooth' }); } catch(e) {}
            }
            return { current: index + 1, total: s.matches.length };
          };

          window.clearSearch = function() {
            try { CSS.highlights.clear(); } catch(e) {}
            try { CSS.highlights.delete('agendada-search'); } catch(e) {}
            try { CSS.highlights.delete('agendada-search-active'); } catch(e) {}
            window.__agendadaSearch = { matches: [], currentIdx: -1 };
            try {
              var root = document.getElementById('root');
              if (root) { root.style.willChange = 'auto'; void root.offsetHeight; }
            } catch(e) {}
          };

          /* ── Debug layout measurement ── */
          window.__agdMeasureEditorLayout = function() {
            var selectors = [
              "html", "body", "#root", ".editor-shell",
              ".bn-editor", ".bn-block-group", ".bn-block-outer",
              ".bn-block", ".bn-block-content", ".bn-inline-content"
            ];
            return selectors.map(function(sel) {
              var el = document.querySelector(sel);
              if (!el) return { selector: sel, missing: true };
              var cs = getComputedStyle(el);
              var rect = el.getBoundingClientRect();
              return {
                selector: sel, width: rect.width, clientWidth: el.clientWidth,
                paddingLeft: cs.paddingLeft, paddingRight: cs.paddingRight,
                boxSizing: cs.boxSizing, fontSize: cs.fontSize,
                letterSpacing: cs.letterSpacing, fontWeight: cs.fontWeight
              };
            });
          };

          window.__agdMeasureTextAdvance = function(text) {
            var host = document.createElement("span");
            host.style.cssText = 'position:absolute;left:-99999px;top:-99999px;white-space:nowrap;' +
              'font-family:"Avenir Next",-apple-system,sans-serif;font-size:14px;font-weight:400;' +
              'line-height:23.1px;letter-spacing:normal;font-kerning:normal;' +
              'font-variant-ligatures:common-ligatures contextual;';
            host.textContent = text;
            document.body.appendChild(host);
            var w = host.getBoundingClientRect().width;
            host.remove();
            return w;
          };

          console.log("Agendada: runtime editor helpers + search + layout measurement injected");
        })();
        """
        webView.evaluateJavaScript(script)

        // One-time CJK vs Core Text width comparison
        let testCJK = "你哈哈哈哈哈哈哈哈哈哈哈哈哈" // 12 pure CJK chars
        let font = NSFont(name: "Avenir Next", size: 14) ?? NSFont.systemFont(ofSize: 14)
        let ctWidth = (testCJK as NSString).size(withAttributes: [.font: font]).width
        let safeCJK = testCJK.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.webView.evaluateJavaScript("window.__agdMeasureTextAdvance && window.__agdMeasureTextAdvance('\(safeCJK)')") { result, _ in
                let wkWidth = result as? Double ?? 0
                let diff = wkWidth - ctWidth
                let chars = testCJK.count
                let perChar = chars > 1 ? diff / Double(chars - 1) : 0
                print("=== AGD CJK === CT=\(String(format:"%.2f", ctWidth))px WK=\(String(format:"%.2f", wkWidth))px diff=\(String(format:"%.2f", diff))px perChar=\(String(format:"%.4f", perChar))px (\(chars) chars)")
            }
        }
    }

    private func handleAssetImport(_ body: Any) {
        guard let dictionary = body as? [String: Any],
              let requestID = dictionary["requestId"] as? String else {
            return
        }

        // Handle file copy from local path (pasted from Finder)
        if let filePath = dictionary["filePath"] as? String,
           (dictionary["copyFromFile"] as? Bool == true || dictionary["copyFromFile"] as? Int == 1) {
            let cleanPath = filePath.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            let sourceURL: URL
            if cleanPath.hasPrefix("file://") {
                sourceURL = URL(string: cleanPath) ?? URL(fileURLWithPath: String(cleanPath.dropFirst(7)))
            } else {
                sourceURL = URL(fileURLWithPath: cleanPath)
            }
            let assetID = UUID().uuidString
            let fname = sanitizedFileName(sourceURL.lastPathComponent)
            let targetURL = assetsDirectory().appending(path: "\(assetID)-\(fname)")
            do {
                try FileManager.default.createDirectory(at: assetsDirectory(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourceURL, to: targetURL)
                resolveAssetImport(requestID: requestID, response: AssetImportResponse(
                    ok: true, assetId: assetID, url: targetURL.standardizedFileURL.absoluteString,
                    name: fname, caption: "", showPreview: true, error: nil
                ))
            } catch {
                resolveAssetImport(requestID: requestID, response: AssetImportResponse(ok: false, error: error.localizedDescription))
            }
            return
        }

        guard let base64 = dictionary["base64"] as? String,
              let data = Data(base64Encoded: base64) else {
            resolveAssetImport(
                requestID: requestID,
                response: AssetImportResponse(ok: false, error: "Invalid image data")
            )
            return
        }

        let originalName = dictionary["fileName"] as? String ?? "image"
        let mimeType = dictionary["mimeType"] as? String
        let assetID = UUID().uuidString
        let fileName = fileNameWithExtension(sanitizedFileName(originalName), mimeType: mimeType)
        let targetURL = assetsDirectory().appending(path: "\(assetID)-\(fileName)")

        do {
            try FileManager.default.createDirectory(at: assetsDirectory(), withIntermediateDirectories: true)
            try data.write(to: targetURL, options: [.atomic])
            resolveAssetImport(
                requestID: requestID,
                response: AssetImportResponse(
                    ok: true,
                    assetId: assetID,
                    url: targetURL.standardizedFileURL.absoluteString,
                    name: fileName,
                    caption: "",
                    showPreview: true,
                    error: nil
                )
            )
        } catch {
            resolveAssetImport(
                requestID: requestID,
                response: AssetImportResponse(ok: false, error: error.localizedDescription)
            )
        }
    }

    private func resolveAssetImport(requestID: String, response: AssetImportResponse) {
        guard let data = try? JSONEncoder().encode(response),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        let script = "window.__agendadaAssetImported && window.__agendadaAssetImported(\(jsString(requestID)), \(json));"
        webView.evaluateJavaScript(script)
    }

    private func handleNoteLinkSearch(_ body: Any) {
        guard let dictionary = body as? [String: Any],
              let requestID = dictionary["requestId"] as? String,
              let query = dictionary["query"] as? String else {
            return
        }

        let currentNoteId = dictionary["currentNoteId"] as? String
        let currentNoteUUID = currentNoteId.flatMap { UUID(uuidString: $0) }

        let results = onNoteLinkSearch?(query, currentNoteUUID) ?? []

        var jsonArray: [[String: String]] = []
        for result in results {
            jsonArray.append([
                "id": result.id.uuidString,
                "title": result.title,
                "project": result.project
            ])
        }

        guard let data = try? JSONSerialization.data(withJSONObject: jsonArray),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        let script = "window.__agendadaNoteLinkResults && window.__agendadaNoteLinkResults(\(jsString(requestID)), \(json));"
        webView.evaluateJavaScript(script)
    }

    private func appSupportDirectory() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return baseURL.appending(path: "Agendada", directoryHint: .isDirectory)
    }

    private func assetsDirectory() -> URL {
        appSupportDirectory().appending(path: "Assets", directoryHint: .isDirectory)
    }

    private func sanitizedFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:\0")
        let sanitized = value
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "image" : sanitized
    }

    private func fileNameWithExtension(_ value: String, mimeType: String?) -> String {
        if !URL(fileURLWithPath: value).pathExtension.isEmpty {
            return value
        }

        switch mimeType?.lowercased() {
        case "image/jpeg", "image/jpg":
            return "\(value).jpg"
        case "image/gif":
            return "\(value).gif"
        case "image/webp":
            return "\(value).webp"
        case "image/heic":
            return "\(value).heic"
        default:
            return "\(value).png"
        }
    }

    private func content(from body: Any) -> BlockNoteEditorContent? {
        guard let dictionary = body as? [String: Any],
              let cardIDString = dictionary["cardId"] as? String,
              let noteID = UUID(uuidString: cardIDString),
              let blockJSONString = dictionary["blockJSON"] as? String else {
            return nil
        }

        let blockJSON = Data(blockJSONString.utf8)
        let plainTextPreview = dictionary["plainTextPreview"] as? String ?? ""
        let previewHTML = dictionary["previewHTML"] as? String

        return BlockNoteEditorContent(
            noteID: noteID,
            blockJSON: blockJSON,
            plainTextPreview: plainTextPreview,
            previewHTML: previewHTML
        )
    }

    private func integerValue(from value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func handleFinderPaste() -> Bool {
        guard isReady, webView.window?.isKeyWindow == true else { return false }
        let pasteboard = NSPasteboard.general

        // First try: file URLs (images pasted from Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let exts = Set(["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"])
            let imgURLs = urls.filter { exts.contains($0.pathExtension.lowercased()) }
            if !imgURLs.isEmpty {
                for src in imgURLs {
                    let assetID = UUID().uuidString
                    let fn = sanitizedFileName(src.lastPathComponent)
                    let dst = assetsDirectory().appending(path: "\(assetID)-\(fn)")
                    do {
                        try FileManager.default.createDirectory(at: assetsDirectory(), withIntermediateDirectories: true)
                        try FileManager.default.copyItem(at: src, to: dst)
                        insertImageBlock(dst: dst, fn: fn)
                    } catch {
                        print("Agendada paste import failed: \(error)")
                    }
                }
                return true
            }
        }

        // Second try: raw image data (images copied from websites — clipboard has TIFF/PNG
        // but no file URL)
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png),
           let image = NSImage(data: imageData) {
            // Convert to PNG for consistent storage — TIFF is the clipboard interchange
            // format on macOS; PNG is more portable and preserves transparency.
            guard let tiffRep = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffRep),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return false
            }
            let assetID = UUID().uuidString
            let fn = "pasted-image-\(assetID.prefix(8)).png"
            let dst = assetsDirectory().appending(path: "\(assetID)-\(fn)")
            do {
                try FileManager.default.createDirectory(at: assetsDirectory(), withIntermediateDirectories: true)
                try pngData.write(to: dst, options: [.atomic])
                insertImageBlock(dst: dst, fn: fn)
                return true
            } catch {
                print("Agendada paste image import failed: \(error)")
                return false
            }
        }

        return false
    }

    private func insertImageBlock(dst: URL, fn: String) {
        let urlStr = dst.standardizedFileURL.absoluteString
        let safe = urlStr.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function(){var e=window.__agendada&&window.__agendada.editor;if(!e)return;var p=e.getTextCursorPosition(),r=p?p.block:e.document[e.document.length-1];var isEmpty=r&&(!r.content||(Array.isArray(r.content)?r.content.length===0:!String(r.content).trim()));if(isEmpty&&r.type!=='image'){e.updateBlock(r,{type:'image',props:{url:'\(safe)',name:'\(fn)',caption:'',showPreview:true}})}else{e.insertBlocks([{type:'image',props:{url:'\(safe)',name:'\(fn)',caption:'',showPreview:true}}],r,'after')}e.focus();})();
        """
        webView.evaluateJavaScript(script)
    }

    private func jsString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return encoded
    }
}

@MainActor
private final class PasteInterceptWebView: WKWebView {
    var pasteHandler: (() -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "v",
               pasteHandler?() == true {
                return true
            }
            if event.charactersIgnoringModifiers == "a" {
                // Cmd+A must select all content inside the BlockNote editor.
                // execCommand('selectAll') doesn't work in React contenteditable.
                // Use the Selection API to create a range covering the whole editor.
                evaluateJavaScript("""
                    (function() {
                        var editor = document.querySelector('.bn-editor');
                        if (!editor) return;
                        var sel = window.getSelection();
                        var range = document.createRange();
                        range.selectNodeContents(editor);
                        sel.removeAllRanges();
                        sel.addRange(range);
                    })();
                    """)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

private func offlineNetworkGuardScript() -> String {
    """
    (() => {
      const isRemoteURL = (value) => {
        try {
          const url = new URL(typeof value === "string" ? value : value?.url || "", window.location.href);
          return url.protocol === "http:" || url.protocol === "https:";
        } catch {
          return false;
        }
      };

      const blockedError = () => new TypeError("Agendada editor runs offline; remote network requests are disabled.");

      const originalFetch = window.fetch;
      window.fetch = function(input, init) {
        if (isRemoteURL(input)) {
          return Promise.reject(blockedError());
        }
        return originalFetch.call(this, input, init);
      };

      const originalOpen = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(method, url, ...rest) {
        if (isRemoteURL(url)) {
          throw blockedError();
        }
        return originalOpen.call(this, method, url, ...rest);
      };
    })();
    """
}

private func blockNoteHTML() -> String {
    """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        :root {
          color-scheme: light;
          --agendada-editor-font-family: "Avenir Next", -apple-system, sans-serif;
        }
        * { box-sizing: border-box; }
        html {
          font-size: 14px !important;
          -webkit-text-size-adjust: none !important;
          text-size-adjust: none !important;
        }
        html, body, #root {
          margin: 0;
          min-height: 100%;
          background: transparent;
          font-family: var(--agendada-editor-font-family);
          color: #333333;
          overflow: visible;
        }
        body { padding: 0; }
        .editor-shell {
          min-height: 180px;
          padding: 0;
          background: transparent;
          overflow: visible;
        }
        .mantine-RichTextEditor-root,
        .mantine-RichTextEditor-content,
        .mantine-RichTextEditor-inner,
        .mantine-RichTextEditor-wrapper,
        .mantine-RichTextEditor-input {
          padding: 0 !important;
          margin: 0 !important;
        }
        /* ── Zero out all BlockNote / ProseMirror container padding ── */
        .bn-container {
          background: transparent !important;
          padding: 0 !important;
        }
        .bn-editor {
          background: transparent !important;
          padding-inline: 0 8px !important;
          font-size: 14px !important;
          line-height: 1.65;
          font-family: var(--agendada-editor-font-family) !important;
          font-weight: 500 !important;
          -webkit-font-smoothing: auto !important;
          -moz-osx-font-smoothing: auto !important;
          overflow: visible !important;
        }
        .bn-default-styles {
          font-family: var(--agendada-editor-font-family) !important;
          font-size: 14px !important;
          line-height: 1.65 !important;
          font-weight: 500 !important;
        }
        /* Vertical block padding — must come AFTER .bn-block-outer/.bn-block reset */
        .bn-block-content {
          padding: 6px 0 !important;
        }
        .bn-block-outer, .bn-block {
          max-width: 100% !important;
          overflow: visible !important;
          padding: 0 !important;
          margin: 0 !important;
        }
        .bn-inline-content {
          min-width: 2px !important;
          max-width: 100% !important;
          overflow-wrap: anywhere;
          padding: 0 !important;
        }
        /* ProseMirror — the underlying contenteditable engine */
        .ProseMirror {
          padding: 0 !important;
          margin: 0 !important;
        }
        .bn-block-content[data-content-type="bulletListItem"]::before,
        .bn-block-content[data-content-type="numberedListItem"]::before {
          color: #8E8E93 !important;
          flex: 0 0 24px !important;
          min-width: 24px !important;
        }
        .bn-block-content[data-content-type="checkListItem"] > div:first-child {
          flex: 0 0 24px !important;
          min-width: 24px !important;
        }
        .bn-block-content[data-content-type="checkListItem"] input[type="checkbox"] {
          accent-color: #F5A623;
          width: 14px;
          height: 14px;
        }
        .bn-editor img {
          max-width: 100% !important;
          max-height: 260px !important;
          object-fit: contain !important;
        }
        .bn-editor table {
          width: 100% !important;
          max-width: 100% !important;
          table-layout: fixed !important;
          border-collapse: collapse;
          overflow: visible;
        }
        .bn-editor td,
        .bn-editor th {
          padding: 10px !important;
          font-size: 14px !important;
          line-height: 1.65 !important;
          overflow-wrap: anywhere;
        }
        .bn-block-content[data-content-type="heading"] {
          color: #1A1A1A !important;
          padding-top: 5.5px !important;
          padding-bottom: 5.5px !important;
          --level: 17px !important;
          font-weight: 700 !important;
        }
        .bn-block-content[data-content-type="heading"]:has(> h1),
        .bn-block-content[data-content-type="heading"][data-level="1"] {
          padding-top: 18.3px !important;
          --level: 17px !important;
        }
        .bn-block-content[data-content-type="heading"][data-level="3"] {
          --level: 15px !important;
        }
        .bn-block-outer[data-prev-type="heading"] > .bn-block > .bn-block-content,
        .bn-block-outer:not([data-prev-type]) > .bn-block > .bn-block-content[data-content-type="heading"] {
          font-size: var(--level) !important;
        }
        /* ── Code block ── */
        .bn-block-content[data-content-type="codeBlock"] {
          font-family: Menlo, "Courier New", monospace !important;
          font-size: 13px !important;
          color: #2E2E30 !important;
          background: rgba(0, 0, 0, 0.045) !important;
          border-radius: 6px !important;
          padding: 8px 10px !important;
          line-height: 1.4 !important;
        }
        /* ── Quote ── */
        .bn-block-content[data-content-type="quote"] {
          border-left: 3px solid #F5E5C0 !important;
          padding-left: 10px !important;
        }
        /* ── Divider ── */
        .bn-block-content[data-content-type="divider"] hr {
          border: none !important;
          height: 1px !important;
          background: rgba(0, 0, 0, 0.10) !important;
          margin: 10px 0 !important;
        }
        .fallback-editor {
          min-height: 180px;
          outline: none;
          font-size: 14px;
          line-height: 1.65;
          caret-color: #F5A623;
          white-space: pre-wrap;
          word-break: break-word;
        }
        .fallback-editor:empty::before {
          content: "笔记正文";
          color: #C7C7CC;
        }
      </style>
    </head>
    <body>
      <div id="root"></div>
      <script>
        window.__agendada = {
          currentCardId: null,
          editor: null,
          fallback: false,
          readOnly: false,
          saveTimer: null,
          pendingLoad: null,
          suppressChange: false
        };

        function post(name, payload) {
          try { window.webkit.messageHandlers[name].postMessage(payload); } catch (error) {}
        }

        function emptyBlocks() {
          return [{ type: "paragraph", content: "" }];
        }

        function normalizeBlocks(value) {
          if (!Array.isArray(value) || value.length === 0) { return emptyBlocks(); }
          return sanitizeBlocks(value);
        }

        function sanitizeBlocks(blocks) {
          return blocks.map(function(block) {
            const copy = JSON.parse(JSON.stringify(block));
            delete copy.id;
            if (!Array.isArray(copy.children)) { copy.children = []; }
            if (Array.isArray(copy.children)) { copy.children = sanitizeBlocks(copy.children); }
            return copy;
          });
        }

        function textFromContent(content) {
          if (typeof content === "string") { return content; }
          if (!Array.isArray(content)) { return ""; }
          return content.map(function(part) {
            if (typeof part === "string") { return part; }
            return part.text || "";
          }).join("");
        }

        function blocksToPlainText(blocks) {
          const lines = [];
          function walk(items) {
            items.forEach(function(block) {
              const text = textFromContent(block.content).trim();
              if (text) { lines.push(text); }
              if (Array.isArray(block.children) && block.children.length) { walk(block.children); }
            });
          }
          walk(blocks || []);
          return lines.join("\\n").trim();
        }

        function escapeHTML(value) {
          return String(value).replace(/[&<>"']/g, function(ch) {
            if (ch === "&") { return "&amp;"; }
            if (ch === "<") { return "&lt;"; }
            if (ch === ">") { return "&gt;"; }
            if (ch === '"') { return "&quot;"; }
            return "&#39;";
          });
        }

        function fallbackHTML(blocks) {
          return (blocks || []).map(function(block) {
            const text = escapeHTML(textFromContent(block.content));
            switch (block.type) {
              case "heading": return "<h2>" + text + "</h2>";
              case "bulletListItem": return "<ul><li>" + text + "</li></ul>";
              case "numberedListItem": return "<ol><li>" + text + "</li></ol>";
              case "checkListItem": return "<ul data-type=\\"taskList\\"><li data-type=\\"taskItem\\" data-checked=\\"false\\"><div><p>" + text + "</p></div></li></ul>";
              case "quote": return "<blockquote>" + text + "</blockquote>";
              case "codeBlock": return "<pre><code>" + text + "</code></pre>";
              case "image": return "";
              default: return text ? "<p>" + text + "</p>" : "";
            }
          }).join("");
        }

        async function snapshot(editor) {
          const blocks = sanitizeBlocks(editor ? editor.document : emptyBlocks());
          let previewHTML = fallbackHTML(blocks);
          if (editor && typeof editor.blocksToHTMLLossy === "function") {
            try { previewHTML = await editor.blocksToHTMLLossy(blocks); } catch (error) {}
          }
          return {
            cardId: window.__agendada.currentCardId,
            blockJSON: JSON.stringify(blocks),
            plainTextPreview: blocksToPlainText(blocks),
            previewHTML: previewHTML
          };
        }

        async function emitChanged(editor) {
          if (window.__agendada.suppressChange || !window.__agendada.currentCardId) { return; }
          const payload = await snapshot(editor);
          post("cardChanged", payload);
          clearTimeout(window.__agendada.saveTimer);
          window.__agendada.saveTimer = setTimeout(async function() {
            post("cardSaved", await snapshot(editor));
          }, 500);
          requestHeight();
        }

        var __heightRAF = 0;
        function requestHeight() {
          if (__heightRAF) return;          // already scheduled this frame
          __heightRAF = requestAnimationFrame(function() {
            __heightRAF = 0;
            const root = document.getElementById("root");
            if (!root) {
              post("editorHeight", 1);
              return;
            }
            const editor = root.querySelector(".bn-editor");
            if (!editor) {
              post("editorHeight", 1);
              return;
            }
            const height = Math.max(1, Math.ceil(editor.scrollHeight));
            post("editorHeight", height);
          });
        }

        var __scheduleHeightTimer = 0;
        function scheduleHeightChecks() {
          requestHeight();
          // Coalesce rapid-fire calls: clear any pending delayed batch first.
          clearTimeout(__scheduleHeightTimer);
          __scheduleHeightTimer = setTimeout(function() {
            requestHeight();
            // One final check after images / async layout settle.
            setTimeout(requestHeight, 500);
          }, 150);
        }

        function signalCardLoaded(cardId, generation) {
          post("cardLoaded", { cardId: cardId, generation: generation });
        }

        var __imgLoadThrottle = 0;
        document.addEventListener("load", function(event) {
          if (event.target && event.target.tagName === "IMG") {
            clearTimeout(__imgLoadThrottle);
            __imgLoadThrottle = setTimeout(scheduleHeightChecks, 100);
          }
        }, true);

        window.loadCard = function(cardId, blockJSONText, generation) {
          clearTimeout(window.__agendada.saveTimer);
          window.clearSearch && window.clearSearch();
          window.__agendada.currentCardId = cardId;
          let blocks = emptyBlocks();
          try { blocks = normalizeBlocks(JSON.parse(blockJSONText)); } catch (error) {}

          if (!window.__agendada.editor && !window.__agendada.fallback) {
            window.__agendada.pendingLoad = { cardId: cardId, blockJSONText: blockJSONText, generation: generation };
            return;
          }

          clearTimeout(window.__agendada.saveTimer);
          if (window.__agendada.fallback) {
            const fallback = document.querySelector(".fallback-editor");
            if (fallback) { fallback.innerText = blocksToPlainText(blocks); }
            requestHeight();
            signalCardLoaded(cardId, generation);
            return;
          }

          const editor = window.__agendada.editor;
          window.__agendada.suppressChange = true;
          try {
            editor.replaceBlocks(editor.document, blocks);
          } catch (error) {
            console.error("Agendada BlockNote loadCard failed", error);
            editor.replaceBlocks(editor.document, emptyBlocks());
          }
          window.__agendada.suppressChange = false;
          scheduleHeightChecks();
          signalCardLoaded(cardId, generation);
        };

        window.flushCurrentContent = async function() {
          clearTimeout(window.__agendada.saveTimer);
          if (!window.__agendada.currentCardId) { return null; }
          if (window.__agendada.fallback) {
            const fallback = document.querySelector(".fallback-editor");
            const text = fallback ? (fallback.innerText || "") : "";
            const blocks = text.split(/\\n+/).filter(Boolean).map(function(line) {
              return { type: "paragraph", content: line, children: [] };
            });
            const payload = {
              cardId: window.__agendada.currentCardId,
              blockJSON: JSON.stringify(blocks.length ? blocks : emptyBlocks()),
              plainTextPreview: text.trim(),
              previewHTML: fallbackHTML(blocks)
            };
            post("cardSaved", payload);
            return payload;
          }
          const payload = await snapshot(window.__agendada.editor);
          post("cardSaved", payload);
          return payload;
        };

        window.focusEditor = function() {
          if (window.__agendada.editor && typeof window.__agendada.editor.focus === "function") {
            window.__agendada.editor.focus();
          } else {
            const fallback = document.querySelector(".fallback-editor");
            if (fallback) { fallback.focus(); }
          }
        };

        window.setReadOnly = function(readOnly) {
          window.__agendada.readOnly = !!readOnly;
          const fallback = document.querySelector(".fallback-editor");
          if (fallback) { fallback.contentEditable = readOnly ? "false" : "true"; }
        };

        function startFallback() {
          if (window.__agendada.editor || window.__agendada.fallback) { return; }
          window.__agendada.fallback = true;
          const root = document.getElementById("root");
          root.innerHTML = '<div class="fallback-editor" contenteditable="true"></div>';
          const fallback = root.querySelector(".fallback-editor");
          fallback.addEventListener("input", async function() {
            const text = fallback.innerText || "";
            const blocks = text.split(/\\n+/).filter(Boolean).map(function(line) {
              return { type: "paragraph", content: line, children: [] };
            });
            const payload = {
              cardId: window.__agendada.currentCardId,
              blockJSON: JSON.stringify(blocks.length ? blocks : emptyBlocks()),
              plainTextPreview: text.trim(),
              previewHTML: fallbackHTML(blocks)
            };
            post("cardChanged", payload);
            clearTimeout(window.__agendada.saveTimer);
            window.__agendada.saveTimer = setTimeout(function() { post("cardSaved", payload); }, 500);
            requestHeight();
          });
          post("editorReady", "fallback");
          if (window.__agendada.pendingLoad) {
            const pending = window.__agendada.pendingLoad;
            window.__agendada.pendingLoad = null;
            window.loadCard(pending.cardId, pending.blockJSONText, pending.generation);
          }
          requestHeight();
        }

        setTimeout(startFallback, 5000);
      </script>
      <script type="importmap">
        {
          "imports": {
            "react": "./offline-fallback/react.js",
            "react/jsx-runtime": "./offline-fallback/react-jsx-runtime.js",
            "react-dom": "./offline-fallback/react-dom.js",
            "react-dom/client": "./offline-fallback/react-dom-client.js",
            "@blocknote/react": "./offline-fallback/blocknote-react.js",
            "@blocknote/mantine": "./offline-fallback/blocknote-mantine.js"
          }
        }
      </script>
      <script type="module">
        import React from "react";
        import { createRoot } from "react-dom/client";
        import { useCreateBlockNote } from "@blocknote/react";
        import { BlockNoteView } from "@blocknote/mantine";

        const e = React.createElement;

        function EditorApp() {
          const editor = useCreateBlockNote({ initialContent: emptyBlocks() });

          React.useEffect(function() {
            window.__agendada.editor = editor;
            post("editorReady", "ready");
            if (window.__agendada.pendingLoad) {
              const pending = window.__agendada.pendingLoad;
              window.__agendada.pendingLoad = null;
              window.loadCard(pending.cardId, pending.blockJSONText, pending.generation);
            }
            const observer = new ResizeObserver(requestHeight);
            const mutationObserver = new MutationObserver(scheduleHeightChecks);
            const root = document.getElementById("root");
            observer.observe(root);
            mutationObserver.observe(root, { subtree: true, childList: true });
            scheduleHeightChecks();
            return function() {
              observer.disconnect();
              mutationObserver.disconnect();
            };
          }, [editor]);

          return e("div", { className: "editor-shell" },
            e(BlockNoteView, {
              editor: editor,
              editable: !window.__agendada.readOnly,
              theme: "light",
              onChange: function() { emitChanged(editor); },
              onFocus: function() { post("editorFocused", window.__agendada.currentCardId || ""); },
              onBlur: function() { post("editorBlurred", window.__agendada.currentCardId || ""); }
            })
          );
        }

        createRoot(document.getElementById("root")).render(e(EditorApp));
      </script>
    </body>
    </html>
    """
}
