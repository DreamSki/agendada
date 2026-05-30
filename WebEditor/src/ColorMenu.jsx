import React from "react";

// ── Color definitions ──
// Text colors: vivid foreground values.
// Highlight colors: saturated for visibility (like fluorescent highlighter pens).
const COLORS = {
  red:    { hex: "#e03e3e", bg: "#ff8787", label: "红", alias: "r"   },
  orange: { hex: "#d9730d", bg: "#ffa94d", label: "橙", alias: "o"   },
  yellow: { hex: "#dfab00", bg: "#ffec99", label: "黄", alias: "y"   },
  green:  { hex: "#0d7c0d", bg: "#8ce99a", label: "绿", alias: "g"   },
  blue:   { hex: "#0b6bcb", bg: "#74c0fc", label: "蓝", alias: "b"   },
  purple: { hex: "#6940a5", bg: "#b197fc", label: "紫", alias: "p"   },
  pink:   { hex: "#c9406d", bg: "#f783ac", label: "粉", alias: "pi"  },
  gray:   { hex: "#9b9a97", bg: "#ced4da", label: "灰", alias: "gr"  },
  brown:  { hex: "#64473a", bg: "#e6b88a", label: "棕", alias: "br"  },
};

// ── Component ──

function ColorMenu(props) {
  const { items, selectedIndex, onItemClick, loadingState, styleType } = props;
  const toolbarRef = React.useRef(null);
  const isHighlight = styleType === "highlight";

  React.useEffect(() => {
    if (selectedIndex === undefined || selectedIndex === null) return;
    const el = document.getElementById(`bn-suggestion-menu-item-${selectedIndex}`);
    if (el) {
      el.scrollIntoView({ block: "nearest", inline: "nearest" });
    }
  }, [selectedIndex]);

  if (loadingState === "loading-initial") return null;
  if (!items || items.length === 0) {
    return <div className="mini-slash-empty">无匹配</div>;
  }

  return (
    <div className="color-dot-toolbar" ref={toolbarRef} role="listbox">
      {items.map((item, i) => {
        const meta = COLORS[item.key];
        const isDefault = item.key === "default";
        const circleStyle = isDefault
          ? { background: "none", borderStyle: "dashed" }
          : meta
          ? { backgroundColor: isHighlight ? meta.bg : meta.hex }
          : {};

        return (
          <button
            key={item.key}
            id={`bn-suggestion-menu-item-${i}`}
            className={
              "color-dot-item" +
              (i === selectedIndex ? " color-dot-item-selected" : "")
            }
            role="option"
            aria-selected={i === selectedIndex}
            onClick={() => onItemClick?.(item)}
          >
            <span className="color-dot-circle" style={circleStyle}>
              {isDefault && (
                <svg
                  width="10" height="10" viewBox="0 0 10 10"
                  style={{ display: "block" }}
                >
                  <line
                    x1="1" y1="1" x2="9" y2="9"
                    stroke="#8E8E93" strokeWidth="1.2"
                  />
                </svg>
              )}
            </span>
            <span className="color-dot-label">
              {isDefault ? "去除" : meta ? meta.label : item.title}
            </span>
          </button>
        );
      })}
    </div>
  );
}

// ── Item factories ──

function createColorItems(editor) {
  const removeItem = {
    key: "default",
    title: "去除",
    aliases: ["清除", "默认", "取消", "reset", "none", "off", "d", "0"],
    onItemClick: () => {
      const active = editor.getActiveStyles?.() || {};
      if (active.textColor && active.textColor !== "default") {
        editor.removeStyles?.({ textColor: active.textColor });
      }
    },
  };

  const colorItems = Object.entries(COLORS).map(([key, { label, alias }]) => ({
    key,
    title: label,
    aliases: [alias, key, label],
    onItemClick: () => {
      const active = editor.getActiveStyles?.() || {};
      if (active.textColor && active.textColor !== "default") {
        editor.removeStyles?.({ textColor: active.textColor });
      }
      editor.addStyles?.({ textColor: key });
    },
  }));

  return [removeItem, ...colorItems];
}

function createHighlightItems(editor) {
  const removeItem = {
    key: "default",
    title: "去除",
    aliases: ["清除", "默认", "取消", "reset", "none", "off", "d", "0"],
    onItemClick: () => {
      const active = editor.getActiveStyles?.() || {};
      if (active.backgroundColor && active.backgroundColor !== "default") {
        editor.removeStyles?.({ backgroundColor: active.backgroundColor });
      }
    },
  };

  const colorItems = Object.entries(COLORS).map(([key, { label, alias }]) => ({
    key,
    title: label,
    aliases: [alias, key, label],
    onItemClick: () => {
      const active = editor.getActiveStyles?.() || {};
      if (active.backgroundColor && active.backgroundColor !== "default") {
        editor.removeStyles?.({ backgroundColor: active.backgroundColor });
      }
      editor.addStyles?.({ backgroundColor: key });
    },
  }));

  return [removeItem, ...colorItems];
}

function HighlightMenu(props) {
  return React.createElement(ColorMenu, { ...props, styleType: "highlight" });
}

export { ColorMenu, HighlightMenu, createColorItems, createHighlightItems };
