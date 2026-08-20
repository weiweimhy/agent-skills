---
name: tibishu-notes
description: Create, organize, revise, and validate Markdown notes in the knowledge base configured by TIBISHU_NOTES_PATH. Use when a user asks to add, edit, summarize into, or organize a Tibishu note, choose its destination folder, create a new topic folder, or ensure a Tibishu Markdown file passes markdownlint.
---

# Tibishu Notes

Resolve the note root from `TIBISHU_NOTES_PATH`. Read the process environment
variable first, then the Windows user environment value when the process value
is empty. If neither is set, stop and ask the user to configure **笔记库 →
笔记路径** in the desktop app. Treat Markdown files as user-owned content and
`.noteimg*` files as editor metadata, not note sources.

## Workflow

1. Inspect the root folders and the Markdown files most relevant to the request
   before choosing a destination. Read nearby notes to preserve meaningful local
   terminology, but do not copy legacy formatting defects.
2. Place the note in an existing topic folder when its subject clearly matches:
   `大A子盘面分析` for A-share market analysis and `金曲再现` for song-related
   writing. For another distinct topic, create one clear topic folder directly
   under the resolved note root.
3. Choose a filename that follows the selected folder's established convention.
   Where no convention exists, use a concise descriptive Chinese filename. Never
   overwrite a note; disambiguate with a date or meaningful qualifier.
4. Start every newly created note with the required Blog front matter, then
   draft the requested content in standard Markdown. Preserve existing notes
   unless the user explicitly asks to revise them.
5. Lint the exact changed `.md` file, fix all reported errors, then report the
   destination and validation result.

## Markdown Requirements

- Use UTF-8 Markdown with one H1 heading, then descend through heading levels
  one level at a time. Do not use headings merely for visual sizing.
- Use ATX headings (`# Heading`), fenced code blocks with a language where
  applicable, and blank lines around headings, lists, blockquotes, and fences.
- Use `-` for unordered lists, ordered lists only when sequence matters, and
  descriptive link text for URLs.
- Include this Blog front matter at the very beginning of every newly created
  note. Fill `title` and `date`; retain empty strings and empty arrays when the
  user provides no value for the optional fields:

  ```yaml
  ---
  title: "Note title"
  description: ""
  date: "YYYY-MM-DD"
  image: ""
  hidden: false
  draft: false
  categories: []
  tags: []
  ---
  ```

  Place the single H1 after the closing delimiter. Use valid YAML, quote string
  values, and do not omit the Blog header for short notes. Do not add or replace
  Blog front matter in an existing note unless the user explicitly requests it.
- Avoid raw HTML and nonstandard extensions such as `:highlight[...]`. Express
  emphasis with ordinary Markdown instead.
- Write direct, well-structured notes that satisfy the user's stated purpose;
  do not invent facts, citations, or personal observations.

## Linting

Run the repository-available markdownlint command from the note root, preferring
`markdownlint-cli2 "<absolute-note-path>"`. Respect an existing markdownlint
configuration if discovery finds one. If no command is installed, tell the user
instead of silently downloading packages; still perform a manual check against
the Markdown requirements above. Do not add or change a workspace lint
configuration unless the user requests it.

Resolve every markdownlint error in the changed file before delivery. Do not
bulk-reformat unrelated existing notes solely to make them lint-clean.
