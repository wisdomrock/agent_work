---
name: explain-file
description: Explain a file in detail, line by line (skipping import/require statements), and write the explanation to a markdown file next to it. Triggers on: explain this file, explain current file, walk me through this file, line by line explanation, document this file, generate documentation for this file, annotate this file.
---

# /explain-file

Produces a line-by-line explanation of a source file and writes it to a `.$.md` file in the same folder (same filename, extension swapped to `.$.md`). The `.$.md` suffix marks it as a generated artifact, so it's easy to exclude from git with a single `**/*.$.md` gitignore pattern.

## Usage

```
/explain-file                 # explain the file currently under discussion / open in the editor
/explain-file <path>          # explain a specific file
/explain-file --force         # regenerate even if a .$.md already exists for the target
/explain-file <path> --force  # same, for a specific file
```

If a `.$.md` file already exists for the resolved target and the invocation contains no force signal, the skill reports an error and stops instead of regenerating (see step 2).

## What You Must Do When Invoked

### 1. Resolve the target file

This must work across whichever IDE/editor integration is active (VS Code, JetBrains, or any other) — never hardcode one editor's tool names.

- If a path was given as an argument, use it (resolve relative to the current working directory) and skip the IDE lookup below.
- Otherwise, first check this conversation for a push-based editor-event tag naming the relevant file — the harness injects these automatically for whichever IDE extension is connected (VS Code, JetBrains, etc.), you never call a tool to get them. Look for, in order of preference: `<ide_selection>` (a selection implies that file is the target), then `<ide_opened_file>` (fires when a file is opened, even with no selection), then any other `<system-reminder>` naming an active/open file. Treat the **most recent** such tag in the conversation as authoritative.
- If no such tag exists, look for a connected IDE/editor MCP server generically — do not assume a specific vendor. Run `ToolSearch` with a broad query like `"ide editor open file"` and inspect whatever comes back (e.g. a JetBrains `mcp__idea_sse_mcp__*` server, a VS Code server, or another editor's server). Then:
  1. Call whatever tool reports the active editor's open file(s) (pass a project-path parameter as the current working directory if the tool wants one) to get the active file path.
  2. **If it returns a usable file path** — resolve it against the project root to an absolute path and use that as the target file (handle it exactly like an explicit `<path>` argument: Read it with the Read tool in the next step).
  3. **Else, if no path comes back but the tool can supply the full text content directly** (e.g. an unsaved/untitled buffer) — take that returned text as the file content directly and skip the Read tool for this file. Since there's no on-disk path in this case, ask the user for a filename/output location before writing the explanation (step 4 needs somewhere to put the `.md` file).
  4. **If no IDE tools are found, the call fails, or it returns nothing usable** — fall back to the file most recently opened/edited/discussed in this conversation. If that's still ambiguous or nothing qualifies, ask the user which file to explain — do not guess silently.
- Once resolved via path, read the file with the Read tool before doing anything else (skip this if step 3 already supplied the text directly).

### 2. Guard against unexplainable targets

Before proceeding, check the resolved file against both of these — stop and report an error to the user instead of explaining it if either applies. Do not silently pick a different file or proceed anyway.

- **This skill's own output:** the filename matches `*.$.md`. This is a generated artifact (see step 5), not a source file — name the file and suggest the likely intended source (same path with `.$.md` stripped down to the original extension, if it exists nearby).
- **Binary content:** the file is not text. Judge this from the Read tool's result (e.g. it errors, refuses, or returns non-text/garbled content instead of line-numbered text — images, compiled artifacts, archives, etc. all surface this way) or an unambiguous binary extension (`.png`, `.jpg`, `.pdf`, `.zip`, `.exe`, `.pyc`, `.so`, `.dll`, `.db`, and similar). Report that the file is binary and can't be explained line by line — don't attempt to paraphrase raw bytes.
- **Explanation already exists:** compute the would-be output path (same rule as step 5: same directory/basename, extension replaced by `.$.md`) and check whether it already exists. If it does, only proceed when the user's invocation carries an explicit force signal — a flag (`--force`, `-f`) or wording in the same message like "force", "regenerate", "re-generate", "refresh", "redo", or "overwrite" (applied to this file or to explain-file generally). Absent that signal, stop and report an error: name the existing `.$.md` path and tell the user to re-invoke with `--force` (or equivalent wording) if they want it regenerated. Do not silently skip this check just because the file looks stale or the source changed — staleness alone is not a force signal.

### 3. Identify and skip the import block

Detect the file's leading import/include/using/package statements (exact syntax depends on language: `import`/`from ... import` in Python, `import`/`require` in JS/TS, `#include` in C/C++, `using` in C#, `use` in Rust, `package`/`import` in Go/Java, etc.). These lines are excluded from the line-by-line commentary entirely — do not quote or explain them individually. It's fine to mention in the overview that the file has N imports and briefly name the notable dependencies, but nothing more.

### 4. Walk the rest of the file in order

For every remaining line (or a tightly-coupled multi-line statement — e.g. a function signature spanning several lines, a multi-line object literal — treated as one unit), write an explanation covering:

- What it does, in plain terms.
- Why it's there / what role it plays in the surrounding logic (not just a restatement of the syntax).
- Anything non-obvious: side effects, mutation, edge cases, invariants it relies on or establishes, why a particular approach was chosen if inferable from context.

Do not skip lines because they look trivial (e.g. a closing brace, a simple return) — cover the whole body, but keep each explanation proportional: a one-line summary for a simple statement, a few sentences for a complex one. Don't pad simple lines with filler.

Go through the file top to bottom, exactly once. Don't reorder, group by topic, or skip around — the reader should be able to follow the markdown output alongside the source file line for line.

**Notebooks (`.ipynb`):** treat each cell as the unit of traversal. If a cell is empty (no source at all, or source that is entirely whitespace) skip it completely — do not create a section, heading, or line-number entry for it, and don't mention it in the overview. This applies regardless of cell type (code or markdown).

### 5. Write the markdown file

Output path: same directory as the source file, same base filename, with the original extension replaced by `.$.md`. If the filename has multiple suffixes (e.g. `foo.test.js`), replace only the last one (→ `foo.test.$.md`). By the time you reach this step, an existing file at that path only happens if the user gave an explicit force signal (checked in step 2) — go ahead and overwrite it, since it's a generated artifact, not hand-authored content.

If the target was resolved from text content only (no on-disk path, per step 1.3), use the filename/location the user gave you when asked, with the extension replaced by `.$.md` the same way.

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

### 6. Report back

After writing the file, tell the user the output path and how many line-groups/sections it covers. Do not paste the full markdown content into the chat — the file itself is the deliverable. Do not modify the original source file.