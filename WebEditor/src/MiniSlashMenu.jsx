import React from "react";

const SHORT_LABELS = {
  heading: "H1",
  heading_2: "H2",
  heading_3: "H3",
  heading_4: "H4",
  heading_5: "H5",
  heading_6: "H6",
  toggle_heading: "折叠",
  toggle_heading_2: "折叠2",
  toggle_heading_3: "折叠3",
  paragraph: "正文",
  bullet_list: "无序",
  numbered_list: "有序",
  check_list: "待办",
  toggle_list: "折叠",
  quote: "引用",
  code_block: "代码",
  page_break: "分页",
  table: "表格",
  image: "图片",
  video: "视频",
  audio: "音频",
  file: "文件",
  emoji: "表情",
  divider: "分割",
  upload: "上传",
  embed: "嵌入",
};

function MiniSlashMenu(props) {
  const { items, selectedIndex, onItemClick, loadingState } = props;
  const toolbarRef = React.useRef(null);

  // Auto-scroll selected item into view
  React.useEffect(() => {
    if (selectedIndex === undefined || selectedIndex === null) return;
    const el = document.getElementById(`bn-suggestion-menu-item-${selectedIndex}`);
    if (el) {
      el.scrollIntoView({ block: "nearest", inline: "nearest" });
    }
  }, [selectedIndex]);

  if (loadingState === "loading-initial") return null;

  if (!items || items.length === 0) {
    return (
      <div className="mini-slash-empty">无匹配</div>
    );
  }

  return (
    <div className="mini-slash-toolbar" ref={toolbarRef} role="listbox">
      {items.map((item, i) => (
        <button
          key={item.key}
          id={`bn-suggestion-menu-item-${i}`}
          className={
            "mini-slash-item" +
            (i === selectedIndex ? " mini-slash-item-selected" : "")
          }
          role="option"
          aria-selected={i === selectedIndex}
          onClick={() => onItemClick?.(item)}
        >
          <span className="mini-slash-icon">{item.icon}</span>
          <span className="mini-slash-label">
            {SHORT_LABELS[item.key] || item.title}
          </span>
        </button>
      ))}
    </div>
  );
}

export { MiniSlashMenu };
