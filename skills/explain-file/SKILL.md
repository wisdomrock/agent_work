---
name: explain-file
description: Explain a file in detail, line by line (skipping import/require statements), and write the explanation to a markdown file next to it. Triggers on: explain this file, explain current file, walk me through this file, line by line explanation, document this file, generate documentation for this file, annotate this file.
---

# /explain-file

Produces a line-by-line explanation of a source file and writes it to a `.md` file in the same folder (same filename, extension swapped to `.md`).

## Usage

```
/explain-file                 # explain the file currently under discussion / open in the editor
/explain-file <path>          # explain a specific file
```

## What You Must Do When Invoked

### 1. Resolve the target file

- If a path was given as an argument, use it (resolve relative to the current working directory) and skip the IDE lookup below.
- Otherwise, **always** ask the IDE's MCP server which file is open in the current editor before falling back to anything else. In this environment that's the JetBrains IDE MCP server (`mcp__idea_sse_mcp__*`); if its tools are deferred, load them first via `ToolSearch` with `select:mcp__idea_sse_mcp__get_all_open_file_paths,mcp__idea_sse_mcp__get_file_text_by_path`. Then:
  1. Call `get_all_open_file_paths` (pass `projectPath` as the current working directory if known) to get the active editor's file path.
  2. **If it returns a usable file path** — resolve it against the project root to an absolute path and use that as the target file (handle it exactly like an explicit `<path>` argument: Read it with the Read tool in the next step).
  3. **Else, if no path comes back but the server can supply the full text content** (e.g. via `get_file_text_by_path`, or an unsaved/untitled buffer) — take that returned text as the file content directly and skip the Read tool for this file. Since there's no on-disk path in this case, ask the user for a filename/output location before writing the explanation (step 4 needs somewhere to put the `.md` file).
  4. **If the MCP call fails, the server/tools aren't available, or it returns nothing usable** — fall back to the file most recently opened/edited/discussed in this conversation. If that's still ambiguous or nothing qualifies, ask the user which file to explain — do not guess silently.
- Once resolved via path, read the file with the Read tool before doing anything else (skip this if step 3 already supplied the text directly).

### 2. Identify and skip the import block

Detect the file's leading import/include/using/package statements (exact syntax depends on language: `import`/`from ... import` in Python, `import`/`require` in JS/TS, `#include` in C/C++, `using` in C#, `use` in Rust, `package`/`import` in Go/Java, etc.). These lines are excluded from the line-by-line commentary entirely — do not quote or explain them individually. It's fine to mention in the overview that the file has N imports and briefly name the notable dependencies, but nothing more.

### 3. Walk the rest of the file in order

For every remaining line (or a tightly-coupled multi-line statement — e.g. a function signature spanning several lines, a multi-line object literal — treated as one unit), write an explanation covering:

- What it does, in plain terms.
- Why it's there / what role it plays in the surrounding logic (not just a restatement of the syntax).
- Anything non-obvious: side effects, mutation, edge cases, invariants it relies on or establishes, why a particular approach was chosen if inferable from context.

Do not skip lines because they look trivial (e.g. a closing brace, a simple return) — cover the whole body, but keep each explanation proportional: a one-line summary for a simple statement, a few sentences for a complex one. Don't pad simple lines with filler.

Go through the file top to bottom, exactly once. Don't reorder, group by topic, or skip around — the reader should be able to follow the markdown output alongside the source file line for line.

**Notebooks (`.ipynb`):** treat each cell as the unit of traversal. If a cell is empty (no source at all, or source that is entirely whitespace) skip it completely — do not create a section, heading, or line-number entry for it, and don't mention it in the overview. This applies regardless of cell type (code or markdown).

### 4. Write the markdown file

Output path: same directory as the source file, same base filename, with the original extension replaced by `.md`. If the filename has multiple suffixes (e.g. `foo.test.js`), replace only the last one (→ `foo.test.md`). If a file with that name already exists, overwrite it — this is a generated artifact, not hand-authored content.

If the target was resolved from text content only (no on-disk path, per step 1.3), use the filename/location the user gave you when asked, with the extension replaced by `.md` the same way.

Structure the markdown as:

```markdown
# <filename>

<1-3 sentence overview: what this file is, its role in the codebase, and a note on its imports (count + notable ones) — not explained line by line>

## Line-by-line

### Lines <n>–<m>
​```<language>
<the exact source line(s)>
​```
<explanation>

### Lines <n>–<m>
...
```

Use the file's actual line numbers (from the Read tool's line-numbered output) so the reader can cross-reference. Use the correct fenced-code-block language tag for the file type.

### 5. Report back

After writing the file, tell the user the output path and how many line-groups/sections it covers. Do not paste the full markdown content into the chat — the file itself is the deliverable. Do not modify the original source file.