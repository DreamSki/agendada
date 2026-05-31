import React from "react";

// ── Color definitions ──
// Text colors: vivid foreground values.
// Highlight colors: bgSat (saturated) + bgSoft (pastel) for both styles.
const COLORS = {
  red:    { hex: "#e03e3e", bgSat: "#ff8787", bgSoft: "#fccfcf", label: "红", alias: "r"   },
  orange: { hex: "#d9730d", bgSat: "#ffa94d", bgSoft: "#fde2c8", label: "橙", alias: "o"   },
  yellow: { hex: "#dfab00", bgSat: "#ffec99", bgSoft: "#fff6cc", label: "黄", alias: "y"   },
  green:  { hex: "#0d7c0d", bgSat: "#8ce99a", bgSoft: "#d0f0d6", label: "绿", alias: "g"   },
  blue:   { hex: "#0b6bcb", bgSat: "#74c0fc", bgSoft: "#d0e8fc", label: "蓝", alias: "b"   },
  purple: { hex: "#6940a5", bgSat: "#b197fc", bgSoft: "#e0d4fc", label: "紫", alias: "p"   },
  pink:   { hex: "#c9406d", bgSat: "#f783ac", bgSoft: "#fcd0e0", label: "粉", alias: "pi"  },
  gray:   { hex: "#9b9a97", bgSat: "#ced4da", bgSoft: "#e9ecef", label: "灰", alias: "gr"  },
  brown:  { hex: "#64473a", bgSat: "#e6b88a", bgSoft: "#f2dcc8", label: "棕", alias: "br"  },
};

// ── Component ──

function ColorMenu(props) {
  const { items, selectedIndex, onItemClick, loadingState } = props;
  const toolbarRef = React.useRef(null);

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
        const dotColor = item.dotColor
          || (meta?.hex);
        const circleStyle = isDefault
          ? { background: "none", borderStyle: "dashed" }
          : dotColor
          ? { backgroundColor: dotColor }
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
              {isDefault ? "去除" : item.dotLabel || meta?.label || item.title}
            </span>
          </button>
        );
      })}
    </div>
  );
}

// ── Highlight wrapper (two-row layout signaled by class) ──

function HighlightMenu(props) {
  return React.createElement(ColorMenu, { ...props });
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

  const colorItems = Object.entries(COLORS).map(([key, { hex, label, alias }]) => ({
    key,
    title: label,
    dotColor: hex,
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

  // Row 1: saturated (keyed by hex so BlockNote renders exact color)
  const satItems = Object.entries(COLORS).map(([, { bgSat, label, alias }]) => ({
    key: bgSat,
    title: label,
    dotColor: bgSat,
    dotLabel: label,
    aliases: [alias, label, "s"],
    onItemClick: () => {
      const active = editor.getActiveStyles?.() || {};
      if (active.backgroundColor && active.backgroundColor !== "default") {
        editor.removeStyles?.({ backgroundColor: active.backgroundColor });
      }
      editor.addStyles?.({ backgroundColor: bgSat });
    },
  }));

  // Row 2: pastel
  const softItems = Object.entries(COLORS).map(([, { bgSoft, label, alias }]) => ({
    key: bgSoft,
    title: "淡" + label,
    dotColor: bgSoft,
    dotLabel: "淡" + label,
    aliases: [alias + "s", "淡" + label, "soft"],
    onItemClick: () => {
      const active = editor.getActiveStyles?.() || {};
      if (active.backgroundColor && active.backgroundColor !== "default") {
        editor.removeStyles?.({ backgroundColor: active.backgroundColor });
      }
      editor.addStyles?.({ backgroundColor: bgSoft });
    },
  }));

  return [removeItem, ...satItems, ...softItems];
}

export { ColorMenu, HighlightMenu, createColorItems, createHighlightItems };
