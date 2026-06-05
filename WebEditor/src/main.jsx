import "@blocknote/core/fonts/inter.css";
import "@blocknote/mantine/style.css";
import "./styles.css";

import React from "react";
import { createRoot } from "react-dom/client";
import { createPortal } from "react-dom";
import { useCreateBlockNote, GridSuggestionMenuController, getDefaultReactSlashMenuItems } from "@blocknote/react";
import { BlockNoteView } from "@blocknote/mantine";
import { filterSuggestionItems } from "@blocknote/core/extensions";
import { zh } from "@blocknote/core/locales";
import { MiniSlashMenu } from "./MiniSlashMenu";
import { ColorMenu, HighlightMenu, createColorItems, createHighlightItems } from "./ColorMenu";
import { NoteLinkPopup } from "./NoteLinkMenu";

window.__agendada = {
  currentCardId: null,
  editor: null,
  fallback: false,
  readOnly: false,
  saveTimer: null,
  pendingLoad: null,
  suppressChange: false,
  isComposing: false,
  pendingCompositionChange: false,
  compositionBaselineBlocks: null,
  compositionFinalizationTimer: null,
  assetImportResolvers: {},
  noteLinkResolvers: {}
};

function post(name, payload) {
  try {
    window.webkit.messageHandlers[name].postMessage(payload);
  } catch {
    // Running outside WKWebView during local bundle checks.
  }
}

function randomRequestId() {
  if (window.crypto && typeof window.crypto.randomUUID === "function") {
    return window.crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const value = String(reader.result || "");
      resolve(value.includes(",") ? value.split(",").pop() : value);
    };
    reader.onerror = () => reject(reader.error || new Error("Unable to read file"));
    reader.readAsDataURL(file);
  });
}

async function uploadLocalAsset(file) {
  const bridge = window.webkit?.messageHandlers?.requestAssetImport;
  if (!bridge) {
    throw new Error("Agendada asset bridge is unavailable");
  }

  const requestId = randomRequestId();
  const base64 = await fileToBase64(file);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      delete window.__agendada.assetImportResolvers[requestId];
      reject(new Error("Asset import timed out"));
    }, 30000);

    window.__agendada.assetImportResolvers[requestId] = { resolve, reject, timer };
    bridge.postMessage({
      requestId,
      cardId: window.__agendada.currentCardId,
      fileName: file.name || "image",
      mimeType: file.type || "application/octet-stream",
      base64
    });
  });
}

const resolvedUrlCache = new Map();

async function copyLocalFileToAssets(filePath) {
  const bridge = window.webkit?.messageHandlers?.requestAssetImport;
  if (!bridge) throw new Error("Agendada asset bridge is unavailable");
  const requestId = randomRequestId();
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      delete window.__agendada.assetImportResolvers[requestId];
      reject(new Error("File copy timed out"));
    }, 15000);
    window.__agendada.assetImportResolvers[requestId] = {
      resolve: (result) => resolve(result.url),
      reject,
      timer
    };
    bridge.postMessage({
      requestId,
      cardId: window.__agendada.currentCardId,
      filePath,
      copyFromFile: true
    });
  });
}

window.__agendadaAssetImported = function agendadaAssetImported(requestId, result) {
  const pending = window.__agendada.assetImportResolvers[requestId];
  if (!pending) {
    return;
  }

  clearTimeout(pending.timer);
  delete window.__agendada.assetImportResolvers[requestId];

  if (result && result.ok && result.url) {
    pending.resolve({
      url: result.url,
      name: result.name || "图片",
      caption: result.caption || "",
      showPreview: true
    });
    return;
  }

  pending.reject(new Error(result?.error || "Asset import failed"));
};

// Note link search callback from Swift
window.__agendadaNoteLinkResults = function(requestId, results) {
  const pending = window.__agendada.noteLinkResolvers[requestId];
  if (!pending) return;

  clearTimeout(pending.timer);
  delete window.__agendada.noteLinkResolvers[requestId];
  pending.resolve(results || []);
};

// Request note search from Swift
async function searchNotesForLink(query) {
  const bridge = window.webkit?.messageHandlers?.noteLinkSearch;
  if (!bridge) {
    return [];
  }

  const requestId = randomRequestId();
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      delete window.__agendada.noteLinkResolvers[requestId];
      resolve([]);
    }, 3000);

    window.__agendada.noteLinkResolvers[requestId] = { resolve, timer };
    bridge.postMessage({
      requestId,
      query,
      currentNoteId: window.__agendada.currentCardId
    });
  });
}

// Insert note link into editor
function insertNoteLink(editor, noteId, noteTitle) {
  const href = `agendada://note/${noteId}`;
  // Use BlockNote's insertInlineContent with link type
  // BlockNote supports "link" as a built-in inline content type
  try {
    editor.insertInlineContent([
      {
        type: "link",
        href: href,
        content: noteTitle,
      },
      " "
    ]);
  } catch (e) {
    // Fallback: just insert the text with a custom data attribute
    console.warn("Agendada: link inline content failed, falling back to styled text", e);
    editor.insertInlineContent(noteTitle + " ");
  }
}

// Handle Cmd+Click on note links inside the editor.
// Uses ProseMirror's API to resolve the clicked position and check for link marks.
function setupNoteLinkClickHandler(editor) {
  const view = editor._tiptapEditor?.view || editor.view;
  if (!view) {
    console.warn("Agendada: no ProseMirror view found for link click handler");
    return;
  }

  // Intercept clicks at the editor DOM level
  const editorDom = view.dom;
  editorDom.addEventListener("mousedown", (e) => {
    // Only Cmd+Click or Ctrl+Click
    if (!e.metaKey && !e.ctrlKey) return;

    // Get the ProseMirror position at the click point
    const pos = view.posAtCoords({ left: e.clientX, top: e.clientY });
    if (!pos) return;

    // Check if there's a link mark at this position
    const $pos = view.state.doc.resolve(pos.pos);
    const marks = $pos.marks();
    const linkMark = marks.find((m) => m.type.name === "link");
    if (!linkMark) return;

    const href = linkMark.attrs?.href || "";
    if (href.startsWith("agendada://note/")) {
      e.preventDefault();
      e.stopPropagation();
      const noteId = href.replace("agendada://note/", "");
      try {
        window.webkit.messageHandlers.noteLinkNavigate.postMessage(noteId);
      } catch {
        // Not in WKWebView
      }
    }
  }, true);
}

function emptyBlocks() {
  return [{ type: "paragraph", content: "" }];
}

function normalizeBlocks(value) {
  if (!Array.isArray(value) || value.length === 0) {
    return emptyBlocks();
  }
  return sanitizeBlocks(value);
}

function sanitizeBlocks(blocks) {
  return blocks.map((block) => {
    const copy = JSON.parse(JSON.stringify(block));
    delete copy.id;
    if (!Array.isArray(copy.children)) {
      copy.children = [];
    }
    if (copy.type === "image" && copy.props) {
      const url = copy.props.url || copy.props.src || "";
      if (typeof url === "string" && url.startsWith("data:")) {
        post("requestAssetImport", {
          cardId: window.__agendada.currentCardId,
          reason: "base64-image"
        });
        copy.props.url = "";
        copy.props.src = "";
      } else if (typeof url === "string" && url && !/^[a-z][a-z0-9+.-]*:/i.test(url)) {
        copy.props.url = "";
        copy.props.src = "";
      }
    }
    if (Array.isArray(copy.children)) {
      copy.children = sanitizeBlocks(copy.children);
    }
    return copy;
  });
}

function textFromContent(content) {
  if (typeof content === "string") {
    return content;
  }
  if (!Array.isArray(content)) {
    return "";
  }
  return content.map((part) => {
    if (typeof part === "string") {
      return part;
    }
    return part.text || "";
  }).join("");
}

function blocksToPlainText(blocks) {
  const lines = [];

  function walk(items) {
    items.forEach((block) => {
      const text = textFromContent(block.content).trim();
      if (text) {
        lines.push(text);
      }
      if (Array.isArray(block.children) && block.children.length) {
        walk(block.children);
      }
    });
  }

  walk(blocks || []);
  return lines.join("\n").trim();
}

function hasCJKText(value) {
  return /[\u3400-\u9FFF\uF900-\uFAFF]/.test(value);
}

function isLikelyPinyinScratch(value) {
  const text = value.trim();
  if (text.length < 2 || text.length > 80) {
    return false;
  }
  return /^[a-zA-ZüÜvV'\s]+$/.test(text) && /[a-zA-ZüÜvV]/.test(text);
}

function blockSignature(block) {
  if (!block) {
    return "";
  }
  return `${block.type || ""}\u0000${textFromContent(block.content).trim()}`;
}

function removeCompositionArtifacts(blocks, baselineBlocks = []) {
  let changed = false;
  const source = Array.isArray(blocks) ? blocks : [];
  const baseline = Array.isArray(baselineBlocks) ? baselineBlocks : [];
  const result = [];

  source.forEach((block, index) => {
    const copy = JSON.parse(JSON.stringify(block));
    if (Array.isArray(copy.children) && copy.children.length) {
      const childBaseline = baseline[index]?.children || [];
      const cleanedChildren = removeCompositionArtifacts(copy.children, childBaseline);
      copy.children = cleanedChildren.blocks;
      changed = changed || cleanedChildren.changed;
    } else {
      copy.children = [];
    }

    const text = textFromContent(copy.content).trim();
    const nextText = textFromContent(source[index + 1]?.content).trim();
    const existedAtThisPosition = blockSignature(copy) === blockSignature(baseline[index]);
    if (!existedAtThisPosition && isLikelyPinyinScratch(text) && hasCJKText(nextText)) {
      changed = true;
      return;
    }

    result.push(copy);
  });

  return {
    blocks: result.length ? result : emptyBlocks(),
    changed
  };
}

function compositionArtifactBlockIds(blocks, baselineBlocks = []) {
  const source = Array.isArray(blocks) ? blocks : [];
  const baseline = Array.isArray(baselineBlocks) ? baselineBlocks : [];
  const ids = [];

  source.forEach((block, index) => {
    if (Array.isArray(block.children) && block.children.length) {
      ids.push(...compositionArtifactBlockIds(block.children, baseline[index]?.children || []));
    }

    const text = textFromContent(block.content).trim();
    const nextText = textFromContent(source[index + 1]?.content).trim();
    const existedAtThisPosition = blockSignature(block) === blockSignature(baseline[index]);
    if (!existedAtThisPosition && block.id && isLikelyPinyinScratch(text) && hasCJKText(nextText)) {
      ids.push(block.id);
    }
  });

  return ids;
}

function cleanupCompositionArtifacts(editor) {
  if (!editor) {
    return false;
  }
  const artifactIds = compositionArtifactBlockIds(
    editor.document || emptyBlocks(),
    window.__agendada.compositionBaselineBlocks || []
  );
  if (!artifactIds.length) {
    return false;
  }

  window.__agendada.suppressChange = true;
  try {
    editor.removeBlocks(artifactIds);
  } catch (error) {
    console.warn("Agendada composition cleanup failed", error);
    window.__agendada.suppressChange = false;
    return false;
  }
  setTimeout(() => {
    window.__agendada.suppressChange = false;
    requestHeight();
  }, 0);
  return true;
}

function escapeHTML(value) {
  return String(value).replace(/[&<>"']/g, (ch) => {
    if (ch === "&") {
      return "&amp;";
    }
    if (ch === "<") {
      return "&lt;";
    }
    if (ch === ">") {
      return "&gt;";
    }
    if (ch === '"') {
      return "&quot;";
    }
    return "&#39;";
  });
}

function fallbackHTML(blocks) {
  return (blocks || []).map((block) => {
    const text = escapeHTML(textFromContent(block.content));
    switch (block.type) {
      case "heading":
        return `<h2>${text}</h2>`;
      case "bulletListItem":
        return `<ul><li>${text}</li></ul>`;
      case "numberedListItem":
        return `<ol><li>${text}</li></ol>`;
      case "checkListItem":
        return `<ul data-type="taskList"><li data-type="taskItem" data-checked="${block.props?.checked ? "true" : "false"}"><div><p>${text}</p></div></li></ul>`;
      case "quote":
        return `<blockquote>${text}</blockquote>`;
      case "codeBlock":
        return `<pre><code>${text}</code></pre>`;
      case "image":
        return "";
      default:
        return text ? `<p>${text}</p>` : "";
    }
  }).join("");
}

async function snapshot(editor) {
  const blocks = sanitizeBlocks(editor ? editor.document : emptyBlocks());
  let previewHTML = fallbackHTML(blocks);
  if (editor && typeof editor.blocksToHTMLLossy === "function") {
    try {
      previewHTML = await editor.blocksToHTMLLossy(blocks);
    } catch {
      // Keep the local fallback HTML.
    }
  }
  return {
    cardId: window.__agendada.currentCardId,
    blockJSON: JSON.stringify(blocks),
    plainTextPreview: blocksToPlainText(blocks),
    previewHTML
  };
}

async function emitChanged(editor) {
  if (window.__agendada.suppressChange || !window.__agendada.currentCardId) {
    return;
  }
  if (window.__agendada.isComposing) {
    window.__agendada.pendingCompositionChange = true;
    requestHeight();
    return;
  }
  const payload = await snapshot(editor);
  post("cardChanged", payload);
  clearTimeout(window.__agendada.saveTimer);
  window.__agendada.saveTimer = setTimeout(async () => {
    post("cardSaved", await snapshot(editor));
  }, 500);
  requestHeight();
}

function isIMEEnterEvent(event) {
  const composing = window.__agendada.isComposing
    || event.isComposing
    || event.keyCode === 229;
  if (!composing) {
    return false;
  }

  if (event.type === "beforeinput") {
    return event.inputType === "insertParagraph" || event.inputType === "insertLineBreak";
  }

  return event.key === "Enter" || event.code === "Enter" || event.keyCode === 13;
}

function guardIMEListCommit(event) {
  if (!isIMEEnterEvent(event)) {
    return;
  }

  // Chinese IME confirmation can surface as Enter/paragraph insertion to
  // ProseMirror. In nested lists that may split the item before composition
  // commits, leaving a pinyin-only list item above the committed Chinese text.
  event.stopImmediatePropagation();
  if (event.type === "beforeinput") {
    event.preventDefault();
  }
}

function markCompositionStart() {
  window.__agendada.isComposing = true;
  window.__agendada.pendingCompositionChange = false;
  clearTimeout(window.__agendada.compositionFinalizationTimer);
  window.__agendada.compositionBaselineBlocks = window.__agendada.editor
    ? sanitizeBlocks(window.__agendada.editor.document || emptyBlocks())
    : null;
  clearTimeout(window.__agendada.saveTimer);
}

function markCompositionEnd() {
  window.__agendada.isComposing = false;
  clearTimeout(window.__agendada.compositionFinalizationTimer);

  const finalize = (remainingPasses, changedSoFar = false) => {
    if (!window.__agendada.editor) {
      window.__agendada.pendingCompositionChange = false;
      window.__agendada.compositionBaselineBlocks = null;
      return;
    }

    const cleaned = cleanupCompositionArtifacts(window.__agendada.editor);
    const changed = changedSoFar || cleaned;
    if (remainingPasses > 0) {
      window.__agendada.compositionFinalizationTimer = setTimeout(() => {
        finalize(remainingPasses - 1, changed);
      }, 24);
      return;
    }

    const shouldEmit = window.__agendada.pendingCompositionChange || changed;
    window.__agendada.pendingCompositionChange = false;
    window.__agendada.compositionBaselineBlocks = null;
    if (shouldEmit) {
      setTimeout(() => {
        emitChanged(window.__agendada.editor);
      }, changed ? 16 : 0);
    }
  };

  window.__agendada.compositionFinalizationTimer = setTimeout(() => {
    finalize(3);
  }, 0);
}

document.addEventListener("keydown", guardIMEListCommit, true);
document.addEventListener("beforeinput", guardIMEListCommit, true);
document.addEventListener("compositionstart", markCompositionStart, true);
document.addEventListener("compositionend", markCompositionEnd, true);

function requestHeight() {
  requestAnimationFrame(() => {
    const root = document.getElementById("root");
    const height = Math.max(180, Math.ceil(root.scrollHeight + 12));
    post("editorHeight", height);
  });
}

window.loadCard = function loadCard(cardId, blockJSONText) {
  clearTimeout(window.__agendada.saveTimer);
  window.__agendada.currentCardId = cardId;
  let blocks = emptyBlocks();
  try {
    blocks = normalizeBlocks(JSON.parse(blockJSONText));
  } catch {
    blocks = emptyBlocks();
  }

  if (!window.__agendada.editor && !window.__agendada.fallback) {
    window.__agendada.pendingLoad = { cardId, blockJSONText };
    return;
  }

  if (window.__agendada.fallback) {
    const fallback = document.querySelector(".fallback-editor");
    if (fallback) {
      fallback.innerText = blocksToPlainText(blocks);
    }
    requestHeight();
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
  setTimeout(() => {
    window.__agendada.suppressChange = false;
    requestHeight();
  }, 0);
};

window.flushCurrentContent = async function flushCurrentContent() {
  clearTimeout(window.__agendada.saveTimer);
  if (!window.__agendada.currentCardId) {
    return null;
  }
  if (window.__agendada.fallback) {
    const fallback = document.querySelector(".fallback-editor");
    const text = fallback ? (fallback.innerText || "") : "";
    const blocks = text.split(/\n+/).filter(Boolean).map((line) => ({
      type: "paragraph",
      content: line,
      children: []
    }));
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

window.focusEditor = function focusEditor() {
  if (window.__agendada.editor && typeof window.__agendada.editor.focus === "function") {
    window.__agendada.editor.focus();
  } else {
    const fallback = document.querySelector(".fallback-editor");
    if (fallback) {
      fallback.focus();
    }
  }
};

window.setReadOnly = function setReadOnly(readOnly) {
  window.__agendada.readOnly = !!readOnly;
  const fallback = document.querySelector(".fallback-editor");
  if (fallback) {
    fallback.contentEditable = readOnly ? "false" : "true";
  }
};

function startFallback() {
  if (window.__agendada.editor || window.__agendada.fallback) {
    return;
  }
  window.__agendada.fallback = true;
  const root = document.getElementById("root");
  root.innerHTML = '<div class="fallback-editor" contenteditable="true"></div>';
  const fallback = root.querySelector(".fallback-editor");
  fallback.addEventListener("input", () => {
    if (window.__agendada.isComposing) {
      window.__agendada.pendingCompositionChange = true;
      requestHeight();
      return;
    }
    const text = fallback.innerText || "";
    const blocks = text.split(/\n+/).filter(Boolean).map((line) => ({
      type: "paragraph",
      content: line,
      children: []
    }));
    const payload = {
      cardId: window.__agendada.currentCardId,
      blockJSON: JSON.stringify(blocks.length ? blocks : emptyBlocks()),
      plainTextPreview: text.trim(),
      previewHTML: fallbackHTML(blocks)
    };
    post("cardChanged", payload);
    clearTimeout(window.__agendada.saveTimer);
    window.__agendada.saveTimer = setTimeout(() => {
      post("cardSaved", payload);
    }, 500);
    requestHeight();
  });
  post("editorReady", "fallback");
  if (window.__agendada.pendingLoad) {
    const pending = window.__agendada.pendingLoad;
    window.__agendada.pendingLoad = null;
    window.loadCard(pending.cardId, pending.blockJSONText);
  }
  requestHeight();
}
setTimeout(startFallback, 5000);

function EditorApp() {
  const lastBracketTime = React.useRef(0);

  const editor = useCreateBlockNote({
    initialContent: emptyBlocks(),
    dictionary: zh,
    placeholders: {
      default: "空白笔记",
      emptyDocument: "空白笔记"
    },
    uploadFile: uploadLocalAsset,
    resolveFileUrl: async (url) => {
      if (!url) return url;
      if (url.startsWith("data:") || url.startsWith("blob:")) return url;
      if (url.startsWith("http://") || url.startsWith("https://")) return url;

      const cached = resolvedUrlCache.get(url);
      if (cached) return cached;

      if (url.startsWith("file://") && url.includes("/Agendada/Assets/")) return url;

      let filePath = url;
      if (url.startsWith("file://")) {
        try { filePath = decodeURIComponent(new URL(url).pathname); }
        catch { filePath = decodeURIComponent(url.substring(7)); }
      }
      filePath = filePath.replace(/^['"]+|['"]+$/g, "");
      if (filePath.includes("/Agendada/Assets/")) {
        const resolved = "file://" + filePath;
        resolvedUrlCache.set(url, resolved);
        return resolved;
      }
      try {
        const resolved = await copyLocalFileToAssets(filePath);
        resolvedUrlCache.set(url, resolved);
        return resolved;
      } catch (error) {
        console.warn("Agendada failed to resolve local file URL:", error);
        return url;
      }
    }
  });

  // Debounced height request to avoid excessive bridge calls
  const debouncedRequestHeight = React.useMemo(() => {
    let timeout = null;
    return () => {
      if (timeout) clearTimeout(timeout);
      timeout = setTimeout(() => {
        timeout = null;
        requestHeight();
      }, 50);
    };
  }, []);

  React.useEffect(() => {
    window.__agendada.editor = editor;
    post("editorReady", "ready");
    // Delay click handler setup to ensure editor DOM is ready
    setTimeout(() => setupNoteLinkClickHandler(editor), 500);
    if (window.__agendada.pendingLoad) {
      const pending = window.__agendada.pendingLoad;
      window.__agendada.pendingLoad = null;
      window.loadCard(pending.cardId, pending.blockJSONText);
    }
    const observer = new ResizeObserver(debouncedRequestHeight);
    observer.observe(document.getElementById("root"));
    requestHeight(); // Initial height immediately
    return () => {
      observer.disconnect();
    };
  }, [editor, debouncedRequestHeight]);

  // Listen for [[ to trigger note link popup
  React.useEffect(() => {
    const handleKeyDown = (e) => {
      if (!editor) return;

      if (e.key === "[" && !e.metaKey && !e.ctrlKey && !e.altKey) {
        const now = Date.now();
        if (now - lastBracketTime.current < 500) {
          // Double bracket detected
          e.preventDefault();
          lastBracketTime.current = 0;

          // Delete the first [ that was already typed
          const sel = window.getSelection();
          if (sel && sel.rangeCount > 0) {
            const range = sel.getRangeAt(0);
            range.collapse(true);
            range.setStart(range.startContainer, Math.max(0, range.startOffset - 1));
            range.deleteContents();
          }

          // Get cursor position for popup placement
          let position = null;
          if (sel && sel.rangeCount > 0) {
            const range = sel.getRangeAt(0).cloneRange();
            range.collapse(false);
            const rect = range.getBoundingClientRect();
            position = { x: rect.left, y: rect.bottom + 4 };
          }

          if (window.__agendada.showNoteLinkPopup) {
            window.__agendada.showNoteLinkPopup(position);
          }
        } else {
          lastBracketTime.current = now;
        }
      } else {
        lastBracketTime.current = 0;
      }
    };

    document.addEventListener("keydown", handleKeyDown, true);
    return () => document.removeEventListener("keydown", handleKeyDown, true);
  }, [editor]);

  return (
    <div className="editor-shell">
      <BlockNoteView
        editor={editor}
        editable={!window.__agendada.readOnly}
        theme="light"
        slashMenu={false}
        formattingToolbar={true}
        onChange={() => emitChanged(editor)}
        onFocus={() => post("editorFocused", window.__agendada.currentCardId || "")}
        onBlur={() => post("editorBlurred", window.__agendada.currentCardId || "")}
      >
        <GridSuggestionMenuController
          triggerCharacter="/"
          gridSuggestionMenuComponent={MiniSlashMenu}
          columns={20}
          getItems={async (query) => {
            const items = getDefaultReactSlashMenuItems(editor);
            return filterSuggestionItems(items, query);
          }}
          floatingUIOptions={{
            useFloatingOptions: {
              placement: "top-start",
            },
          }}
        />
        <GridSuggestionMenuController
          triggerCharacter="!"
          gridSuggestionMenuComponent={ColorMenu}
          columns={20}
          getItems={async (query) => {
            const items = createColorItems(editor);
            const filtered = filterSuggestionItems(items, query);
            return query ? filtered.filter((i) => i.key !== "default") : filtered;
          }}
          floatingUIOptions={{
            useFloatingOptions: {
              placement: "top-start",
            },
          }}
        />
        <GridSuggestionMenuController
          triggerCharacter="«"
          gridSuggestionMenuComponent={HighlightMenu}
          columns={10}
          getItems={async (query) => {
            const items = createHighlightItems(editor);
            const filtered = filterSuggestionItems(items, query);
            return query ? filtered.filter((i) => i.key !== "default") : filtered;
          }}
          floatingUIOptions={{
            useFloatingOptions: {
              placement: "top-start",
            },
          }}
        />
      </BlockNoteView>
    </div>
  );
}

// Render NoteLinkPopup as a separate root to avoid re-rendering the editor
const noteLinkRoot = document.createElement("div");
noteLinkRoot.id = "note-link-root";
document.body.appendChild(noteLinkRoot);

function NoteLinkPopupContainer() {
  const [state, setState] = React.useState({ visible: false, query: "", position: null });

  React.useEffect(() => {
    window.__agendada.showNoteLinkPopup = (position) => {
      setState({ visible: true, query: "", position });
    };
    window.__agendada.hideNoteLinkPopup = () => {
      setState({ visible: false, query: "", position: null });
    };
    return () => {
      delete window.__agendada.showNoteLinkPopup;
      delete window.__agendada.hideNoteLinkPopup;
    };
  }, []);

  if (!state.visible) return null;

  const style = state.position
    ? { position: "fixed", left: state.position.x, top: state.position.y, zIndex: 9999 }
    : { position: "fixed", top: "50%", left: "50%", transform: "translate(-50%, -50%)", zIndex: 9999 };

  return createPortal(
    <div style={style} className="note-link-overlay" onMouseDown={(e) => e.stopPropagation()}>
      <div className="note-link-popup">
        <NoteLinkPopupInner
          onSelect={(noteId, noteTitle) => {
            const editor = window.__agendada.editor;
            setState({ visible: false, query: "", position: null });
            // Restore editor focus before inserting content
            if (editor) {
              editor.focus();
              setTimeout(() => {
                insertNoteLink(editor, noteId, noteTitle);
              }, 10);
            }
          }}
          onClose={() => setState({ visible: false, query: "", position: null })}
        />
      </div>
    </div>,
    document.body
  );
}

function NoteLinkPopupInner({ onSelect, onClose }) {
  const [searchText, setSearchText] = React.useState("");
  const [results, setResults] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [selectedIndex, setSelectedIndex] = React.useState(0);
  const inputRef = React.useRef(null);

  React.useEffect(() => {
    setTimeout(() => inputRef.current?.focus(), 50);
  }, []);

  React.useEffect(() => {
    if (!searchText.trim()) {
      setResults([]);
      return;
    }
    let cancelled = false;
    setLoading(true);
    // Debounce search to avoid excessive bridge calls during fast typing
    const timer = setTimeout(() => {
      searchNotesForLink(searchText).then((notes) => {
        if (!cancelled) {
          setResults(notes);
          setSelectedIndex(0);
          setLoading(false);
        }
      });
    }, 200);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [searchText]);

  const handleKeyDown = (e) => {
    if (e.key === "Escape") {
      e.preventDefault();
      onClose();
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      setSelectedIndex((i) => Math.min(i + 1, results.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSelectedIndex((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter" && results.length > 0) {
      e.preventDefault();
      const note = results[selectedIndex];
      if (note) onSelect(note.id, note.title);
    }
  };

  return (
    <>
      <div className="note-link-search-row">
        <span className="note-link-search-icon">🔗</span>
        <input
          ref={inputRef}
          className="note-link-search-input"
          type="text"
          placeholder="搜索笔记标题..."
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
          onKeyDown={handleKeyDown}
        />
      </div>
      {loading && <div className="note-link-status">搜索中...</div>}
      {!loading && searchText && results.length === 0 && (
        <div className="note-link-status">无匹配笔记</div>
      )}
      {results.length > 0 && (
        <div className="note-link-results">
          {results.map((note, i) => (
            <button
              key={note.id}
              className={
                "note-link-result-item" +
                (i === selectedIndex ? " note-link-result-selected" : "")
              }
              onClick={() => onSelect(note.id, note.title)}
              onMouseEnter={() => setSelectedIndex(i)}
            >
              <span className="note-link-result-icon">📄</span>
              <div className="note-link-result-text">
                <span className="note-link-result-title">{note.title}</span>
                {note.project && (
                  <span className="note-link-result-project">{note.project}</span>
                )}
              </div>
            </button>
          ))}
        </div>
      )}
    </>
  );
}

createRoot(noteLinkRoot).render(<NoteLinkPopupContainer />);

createRoot(document.getElementById("root")).render(<EditorApp />);
