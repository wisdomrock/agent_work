---
name: explain-selection
description: Explain the currently selected/highlighted lines in the editor, in the context of the surrounding file. Answers directly in chat (no file written). Triggers on: explain the selected lines, explain this selection, explain highlighted code, what does this selected code do, explain these lines.
---

# /explain-selection

Explains a selection of lines from the editor in plain terms, grounded in the surrounding file/notebook so the explanation isn't just a restatement of syntax.

## Usage

```
/explain-selection             # explain whatever is currently selected in the editor
/explain-selection <path>#L10-L20   # explain a specific range if no live selection is available
```

## What You Must Do When Invoked

### 1. Resolve the selection

This must work across whichever IDE/editor integration is active (VS Code, JetBrains, or any other) — never hardcode one editor's tool names.

- First check this conversation for an `<ide_selection>` tag of the form "The user selected the lines `<start>` to `<end>` from `<path>`" (often followed by the literal selected text). This is a push-based editor-event tag: the harness injects it automatically for whichever IDE extension is connected (VS Code, JetBrains, etc.) whenever the user makes a selection — you never call a tool to get it. Treat it as authoritative and current, and prefer the **most recent** one if several appear. Note there's a separate `<ide_opened_file>` tag for "file opened, no selection" — that's a signal for *which file*, not a line range, so it's not sufficient on its own here (see `/explain-file` for that case).
- **Important:** this tag is a one-shot *change* event, not a live poll — it fires once when the selection changes and rides along with the next message, but is NOT resent on later messages just because the same selection is still highlighted (the IDE's own status bar can show "N lines selected" while the harness has nothing new to deliver). So if `/explain-selection` is invoked and no tag appears, don't assume nothing is selected — ask the user to reselect (even the exact same lines) right before retrying, rather than immediately falling back to asking for a pasted snippet or line range.
- If no such tag exists and no explicit `<path>#L..-L..` argument was given, an MCP-based editor server (e.g. JetBrains `mcp__idea-sse-mcp__*`) may still be connected — but as of writing, none of these servers expose a tool that reads the live selection range or caret position from the editor (JetBrains' `get_symbol_info` needs a line+column you must already know; `get_all_open_file_paths` gives only the active file, not a range). **Do not spend a ToolSearch call hunting for a selection-reading tool — it doesn't exist in these servers.** Instead:
  1. If an editor MCP server is connected, call its "list open files" tool (e.g. `mcp__idea-sse-mcp__get_all_open_file_paths`) to get the active file path for free, so the user doesn't have to type it.
  2. Ask the user for the line range on that file (or to paste the snippet directly) — one question, pre-filled with the file you already resolved, e.g. "Which lines of `session1/Hello.py` should I explain?"
  3. If no editor MCP server is connected either, ask the user to paste the selected code or state `path#L..-L..` directly.
- Once you have a file path + line range, read the file with the Read tool (use `offset`/`limit` if the file is large) to get line-numbered content and confirm the exact text of the selection.

### 2. Gather enough surrounding context

The selection is rarely self-contained. Before explaining, look for what it depends on and what depends on it:

- If `.codegraph/` exists at the repo root, use `codegraph_explore` (or shell `codegraph explore "<symbol>"`) on any non-trivial symbols referenced in the selection — this is faster and more precise than grepping.
- Otherwise, use Grep/Read to find: definitions of any classes/functions/variables referenced in the selection, and (briefly) how the result of this code is used afterward, if that's readily discoverable nearby.
- For notebooks (`.ipynb`), pull in the defining cell for any class/function used in the selected cell, and any hyperparameters/variables set earlier that the selection consumes — don't limit yourself to the single cell.
- Don't over-fetch: pull in only what's needed to explain the selected lines, not a full-file tour (that's what `/explain-file` is for).

### 3. Write the explanation

Respond directly in chat — do not write a file. Structure:

- One sentence of orientation: what this selection is part of (e.g. "this instantiates the `TokenDataset` class defined above").
- A statement (in code fence, using the correct language) of the selected lines, if not already visible above your response.
- For each meaningful line or tightly-coupled group: what it does, why it's there, and anything non-obvious (side effects, invariants, why this approach). Skip filler for trivial lines.
- Reference definitions pulled in for context with `file:line`.

Keep it proportional to the selection size — a 2-line selection gets a short, dense explanation, not a full walkthrough. Do not modify any files.