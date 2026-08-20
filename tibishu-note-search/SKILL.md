---
name: tibishu-note-search
description: Find and read Markdown notes in the knowledge base configured by TIBISHU_NOTES_PATH through a fast, layered search. Use when a user asks to locate, identify, list, inspect, or summarize existing Tibishu notes, especially when the note's folder, filename, Blog front matter, or body text may identify it.
---

# Tibishu Note Search

Resolve the note root from `TIBISHU_NOTES_PATH`: read the process environment
variable first, then the Windows user environment value when the process value
is empty. If neither is set, stop and ask the user to configure **笔记库 →
笔记路径** in the desktop app. Search the resolved root read-only. Minimize file
content loaded into the conversation: paths and filenames first, Blog front
matter second, and body text only as a fallback. Do not create indexes, edit
notes, or open unrelated complete files.

## Search Order

1. Run the `Names` stage. It lists Markdown paths whose folder or filename
   matches the query without reading file contents.
2. Run the `Headers` stage only when filenames leave several plausible choices
   or no match. It reads only the opening YAML front matter of filename matches;
   when there are no filename matches, it scans only all note headers.
3. Run the `Content` stage only when the first two stages cannot identify the
   note. It uses `rg` to find matching files but does not load their full text.
4. Read the complete Markdown of the selected file only when needed to answer
   the request, then cite its path and distinguish recorded facts from inference.

Run the stages with the bundled helper. Replace the query with the user's
keywords and stop as soon as the result is unambiguous.

```powershell
& "$PSScriptRoot\scripts\Find-TibishuNotes.ps1" -Stage Names -Query "HTTPS"
& "$PSScriptRoot\scripts\Find-TibishuNotes.ps1" -Stage Headers -Query "HTTPS"
& "$PSScriptRoot\scripts\Find-TibishuNotes.ps1" -Stage Content -Query "HTTPS"
```

The helper returns only paths and short metadata. It is read-only and uses
`rg --files` plus `rg --files-with-matches` when ripgrep is available, with a
PowerShell fallback.

## Reading Rules

- Treat directory names and filenames as the primary taxonomy. Search exact
  project, product, protocol, or topic terms before using broad natural-language
  questions.
- Treat Blog front matter (`title`, `description`, `date`, `categories`, and
  `tags`) as the second-level index. Do not read past its closing `---` during
  the header stage.
- On a body match, inspect the header before reading the full note so similarly
  named notes remain distinguishable.
- For a list request, return matching paths and metadata rather than complete
  note bodies. For a question that requires content, read the smallest selected
  set of notes.
- Preserve Markdown, unknown extensions, and personal content exactly. This
  skill never modifies the resolved note root.

## Indexing Boundary

Do not maintain a persistent index for the current small library: it adds
invalidation work and can become stale while yielding little speed benefit.
Consider a regenerated header-only index only after measuring a real latency
problem with a much larger collection.
