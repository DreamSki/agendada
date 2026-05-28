import AppKit
import SwiftUI
import WebKit

// MARK: - Note Editor

@MainActor
struct NoteEditor: NSViewRepresentable {
    @Binding var html: String
    @Binding var editorHeight: CGFloat
    var placeholder: String = "笔记正文"
    var isEditable: Bool = true
    var minHeight: CGFloat = 40
    var maxHeight: CGFloat = 600

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let userContent = config.userContentController
        userContent.add(context.coordinator, name: "onChange")
        userContent.add(context.coordinator, name: "onHeight")
        userContent.add(context.coordinator, name: "onReady")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.webView = webView
        webView.loadHTMLString(editorHTML(placeholder: placeholder), baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        guard context.coordinator.didLoadEditor else { return }

        if context.coordinator.needsContentLoad {
            context.coordinator.needsContentLoad = false
            let escaped = html
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("window.setContent(`\(escaped)`)")
        }

        if isEditable != context.coordinator.lastEditable {
            context.coordinator.lastEditable = isEditable
            webView.evaluateJavaScript("document.getElementById('editor').contentEditable = \(isEditable)")
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WKWebView, context: Context) -> CGSize {
        let width = proposal.width ?? nsView.bounds.width
        let h = max(minHeight, min(context.coordinator.cachedHeight, maxHeight))
        return CGSize(width: width, height: h)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "onChange")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "onHeight")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "onReady")
        nsView.navigationDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: NoteEditor
        weak var webView: WKWebView?
        var cachedHeight: CGFloat = 40
        var didLoadEditor = false
        var needsContentLoad = false
        var lastEditable = true

        init(_ parent: NoteEditor) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "onReady":
                didLoadEditor = true
                if !parent.html.isEmpty {
                    needsContentLoad = true
                    DispatchQueue.main.async {
                        let escaped = self.parent.html
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "`", with: "\\`")
                            .replacingOccurrences(of: "$", with: "\\$")
                        self.webView?.evaluateJavaScript("window.setContent(`\(escaped)`)")
                    }
                }
                webView?.evaluateJavaScript("window.rh()")

            case "onChange":
                guard let newHTML = message.body as? String,
                      newHTML != parent.html else { return }
                parent.html = newHTML
                DispatchQueue.main.async { [weak self] in
                    self?.webView?.evaluateJavaScript("window.rh()")
                }

            case "onHeight":
                if let height = message.body as? CGFloat, height > 0 {
                    cachedHeight = height + 8
                } else if let height = message.body as? Double, height > 0 {
                    cachedHeight = CGFloat(height) + 8
                }

            default: break
            }
        }
    }
}

// MARK: - Toolbar Actions

enum EditorAction: String {
    case bold, italic, underline, strikethrough, code
    case h1, h2, h3
    case bulletList, orderedList, taskList
    case blockquote, codeBlock
}

@MainActor
func callEditorAction(_ action: EditorAction) {
    guard let wv = findEditorWebView() else { return }
    wv.evaluateJavaScript("window.editorAction('\(action.rawValue)')")
}

@MainActor
private func findEditorWebView() -> WKWebView? {
    var responder: NSResponder? = NSApp.keyWindow?.firstResponder
    while let r = responder {
        if let wv = r as? WKWebView { return wv }
        responder = r.nextResponder
    }
    return nil
}

// MARK: - Toolbar

struct EditorToolbar: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(buttons, id: \.label) { btn in
                if btn.isSeparator {
                    Divider().frame(height: 16).padding(.horizontal, 4)
                } else {
                    Button { callEditorAction(btn.action) } label: {
                        Text(btn.label)
                            .font(.system(size: 12, weight: btn.weight))
                            .italic(btn.italic)
                            .underline(btn.underline)
                            .frame(width: 28, height: 24)
                            .foregroundStyle(.secondary)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain).help(btn.tooltip)
                }
            }
        }
    }

    private struct Btn {
        let label: String; let action: EditorAction; let tooltip: String
        var weight: Font.Weight = .regular; var italic = false; var underline = false; var isSeparator = false
    }

    private let buttons: [Btn] = [
        Btn(label: "B", action: .bold, tooltip: "粗体 ⌘B", weight: .bold),
        Btn(label: "I", action: .italic, tooltip: "斜体 ⌘I", italic: true),
        Btn(label: "U", action: .underline, tooltip: "下划线 ⌘U", underline: true),
        Btn(label: "S", action: .strikethrough, tooltip: "删除线"),
        Btn(label: "<>", action: .code, tooltip: "行内代码"),
        Btn(label: "", action: .bold, tooltip: "", isSeparator: true),
        Btn(label: "H1", action: .h1, tooltip: "一级标题"),
        Btn(label: "H2", action: .h2, tooltip: "二级标题"),
        Btn(label: "H3", action: .h3, tooltip: "三级标题"),
        Btn(label: "", action: .bold, tooltip: "", isSeparator: true),
        Btn(label: "\u{2022}", action: .bulletList, tooltip: "无序列表"),
        Btn(label: "1.", action: .orderedList, tooltip: "有序列表"),
        Btn(label: "\u{2713}", action: .taskList, tooltip: "任务列表"),
        Btn(label: "\u{275D}", action: .blockquote, tooltip: "引用"),
        Btn(label: "</>", action: .codeBlock, tooltip: "代码块"),
    ]
}

// MARK: - HTML Template (minimal placeholder)

func editorHTML(placeholder: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width,initial-scale=1.0">
    <style>
    :root{color-scheme:light}
    *{margin:0;padding:0;box-sizing:border-box}
    html,body{background:transparent;overflow:hidden;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",sans-serif;font-size:14px;line-height:1.7;color:#333}
    #editor{outline:none;min-height:40px;word-wrap:break-word;caret-color:#C98A14}
    #editor:empty::before{content:attr(data-placeholder);color:#C7C7CC;pointer-events:none;display:block}
    </style>
    </head>
    <body>
    <div id="editor" contenteditable="true" data-placeholder="\(placeholder)"></div>
    <script>
    (function(){
      var E=document.getElementById('editor');
      var lastHTML='';

      function rh(){requestAnimationFrame(function(){try{window.webkit.messageHandlers.onHeight.postMessage(Math.max(E.scrollHeight,40))}catch(e){}})}
      window.rh=rh;

      function rc(){var h=E.innerHTML;if(h!==lastHTML){lastHTML=h;try{window.webkit.messageHandlers.onChange.postMessage(h)}catch(e){}}}

      window.setContent=function(html){if(html&&html!==E.innerHTML){E.innerHTML=html;lastHTML=E.innerHTML;rh()}};

      window.editorAction=function(name){
        E.focus();
        var m={bold:'bold',italic:'italic',underline:'underline',strikethrough:'strikeThrough',code:null,h1:null,h2:null,h3:null,bulletList:'insertUnorderedList',orderedList:'insertOrderedList',taskList:null,blockquote:null,codeBlock:null};
        switch(name){
          case 'bold':case 'italic':case 'underline':case 'strikethrough':document.execCommand(m[name]);break;
          case 'h1':document.execCommand('formatBlock',false,'h1');break;
          case 'h2':document.execCommand('formatBlock',false,'h2');break;
          case 'h3':document.execCommand('formatBlock',false,'h3');break;
          case 'bulletList':document.execCommand('insertUnorderedList');break;
          case 'orderedList':document.execCommand('insertOrderedList');break;
          case 'blockquote':document.execCommand('formatBlock',false,'blockquote');break;
          case 'codeBlock':document.execCommand('formatBlock',false,'pre');break;
        }
        rc();rh();
      };

      E.addEventListener('input',function(){rc();rh()});
      E.addEventListener('paste',function(){setTimeout(function(){rc();rh()},10)});

      try{window.webkit.messageHandlers.onReady.postMessage('ready')}catch(e){}
      rh();
    })();
    </script>
    </body>
    </html>
    """
}
