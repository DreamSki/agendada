# Agendada

Agendada is a macOS SwiftUI MVP for a timeline-driven project notes app.

## Current MVP

- Three-column macOS layout: overview/project sidebar, note list, editor.
- Core data model for categories, projects, notes, dates, tags, people, status, and focus.
- Overview filters for Today, Current Focus, and All Notes.
- Search across title, body, tags, and people.
- Basic note editor with title, body, date, tags, people, status, and focus toggle.
- Create, rename, and delete categories and projects from the sidebar.
- Local JSON persistence at `~/Library/Application Support/Agendada/Library.json`.

## Run

```sh
swift run
```

## Build App Bundle

```sh
scripts/build_app.sh
open dist/Agendada.app
```

## Test

```sh
swift test
```

## Next Steps

- Replace the plain text editor with a richer editor.
- Add attachments.
- Add import/export for Markdown and the app archive format.
- Add Calendar and Reminders integration after the local model stabilizes.
