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

- First check this conversation for a `<system-reminder>` of the form "The user selected the lines `<start>` to `<end>` from `<path>`" (often followed by the literal selected text). This is the harness's own selection signal and should be treated as authoritative and current — prefer the **most recent** one if several appear.
- If no such reminder exists and no explicit `<path>#L..-L..` argument was given:
  1. Try the IDE MCP server for the active file. In this environment that's the JetBrains server (`mcp__idea_sse_mcp__*`); if deferred, load it via `ToolSearch` with `select:mcp__idea_sse_mcp__get_all_open_file_paths,mcp__idea_sse_mcp__get_file_text_by_path`. These tools generally expose the *open file*, not the selection range itself — if no selection range is obtainable this way, ask the user to paste the selected code or state the line range rather than guessing.
  2. If IDE tools are unavailable or return nothing usable, ask the user which lines to explain.
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