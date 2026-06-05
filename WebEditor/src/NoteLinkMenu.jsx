import React from "react";

function NoteLinkPopup({ editor, visible, query, position, onSelect, onClose }) {
  const [results, setResults] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [selectedIndex, setSelectedIndex] = React.useState(0);
  const [searchText, setSearchText] = React.useState("");
  const inputRef = React.useRef(null);

  React.useEffect(() => {
    if (visible) {
      setSearchText("");
      setSelectedIndex(0);
      setResults([]);
      // Focus input after render
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [visible]);

  React.useEffect(() => {
    if (!visible || !searchText.trim()) {
      setResults([]);
      return;
    }

    let cancelled = false;
    setLoading(true);

    searchNotesForLink(searchText).then((notes) => {
      if (!cancelled) {
        setResults(notes);
        setSelectedIndex(0);
        setLoading(false);
      }
    });

    return () => { cancelled = true; };
  }, [visible, searchText]);

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
      if (note) {
        onSelect(note.id, note.title);
      }
    }
  };

  if (!visible) return null;

  const style = position
    ? { position: "fixed", left: position.x, top: position.y, zIndex: 9999 }
    : { position: "fixed", top: "50%", left: "50%", transform: "translate(-50%, -50%)", zIndex: 9999 };

  return (
    <div style={style} className="note-link-overlay" onClick={(e) => e.stopPropagation()}>
      <div className="note-link-popup">
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
      </div>
    </div>
  );
}

export { NoteLinkPopup };
