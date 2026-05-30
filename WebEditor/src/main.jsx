import "@blocknote/core/fonts/inter.css";
import "@blocknote/mantine/style.css";
import "./styles.css";

import React from "react";
import { createRoot } from "react-dom/client";
import { useCreateBlockNote, GridSuggestionMenuController, getDefaultReactSlashMenuItems } from "@blocknote/react";
import { BlockNoteView } from "@blocknote/mantine";
import { filterSuggestionItems } from "@blocknote/core/extensions";
import { zh } from "@blocknote/core/locales";
import { MiniSlashMenu } from "./MiniSlashMenu";

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
  assetImportResolvers: {}
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

  React.useEffect(() => {
    window.__agendada.editor = editor;
    post("editorReady", "ready");
    if (window.__agendada.pendingLoad) {
      const pending = window.__agendada.pendingLoad;
      window.__agendada.pendingLoad = null;
      window.loadCard(pending.cardId, pending.blockJSONText);
    }
    const observer = new ResizeObserver(requestHeight);
    observer.observe(document.getElementById("root"));
    requestHeight();
    return () => {
      observer.disconnect();
    };
  }, [editor]);

  return (
    <div className="editor-shell">
      <BlockNoteView
        editor={editor}
        editable={!window.__agendada.readOnly}
        theme="light"
        slashMenu={false}
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
      </BlockNoteView>
    </div>
  );
}

createRoot(document.getElementById("root")).render(<EditorApp />);
