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

This must work across whichever IDE/editor integration is active (VS Code, JetBrains, or any other) — never hardcode one editor's tool names. Resolve in this order, stopping at the first tier that yields a usable range.

**Tier 1 — IDE-injected harness tags.** Check whether the message that invoked this skill carries `<ide_selection>` (or an equivalent editor-event tag naming the current selection/file) — including one riding inside a `<system-reminder>` block. When present, this is the fastest path: no tool call, no state-file Read, use it straight away.

  1. **Only the tag attached to this invocation's message counts.** Do not mine earlier turns in the conversation for one — a tag from a prior message no longer reflects what's selected now, and using it would be indistinguishable from guessing.
  2. **Absence here is not "nothing is selected."** These tags are one-shot *change* events: the harness attaches one only to the message where the selection changed, and sends nothing on every later message even though that selection may still be highlighted. So if this message carries no such tag, that just means nothing changed on *this* message — fall through to Tier 2, don't treat it as a dead end.
  3. If the tag is present and non-empty, take the file + line range it names as the resolved range and skip Tiers 2–3. Still read the file with the Read tool (see the bullet after Tier 4) to confirm the exact text before explaining — never trust the tag's own text over what's on disk.

**Tier 2 — the editor state file.** If Tier 1 found no tag on this message, an editor extension may continuously mirror live editor state to a JSON file. This is the fallback: always available, no tool call beyond a Read, no session-start ordering problem.

  1. Read `.editor-state/state.json` relative to the current working directory. If it isn't there and the cwd is inside a git repo, try the repo root (`git rev-parse --show-toplevel`). Missing in both → Tier 3. Do not treat "missing" as an error; most projects won't have it.
  2. **Check `schemaVersion`.** If it's greater than `1`, do not guess at the fields — fall through to Tier 3 and say why.
  3. **Confirm it's about this project.** The cwd should be inside one of `workspace.folders`. If it isn't, the file belongs to a different window or project — ignore it and fall through.
  4. **Check freshness** using `updatedAtMs` (epoch ms; get the current time with `date +%s%3N` if you need it precisely):
     - **under 60s** — use it silently.
     - **60s to 30min** — use it, but state the age: *"using the selection from ~4 min ago (lines 3–5 of Hello.py)"*.
     - **over 30min** — treat it as a hint only. Confirm with the user before explaining. If `window.heartbeatPath` is present, Read that file too: a heartbeat older than ~90s means the editor is no longer running, so say that rather than implying live state.
  5. **Pick the range.**
     - `selection` non-null and `isEmpty: false` → use it. This field is always live-or-null, never carried forward, so it needs no staleness caveat of its own beyond step 4.
     - `selection` null or `isEmpty: true` → fall back to `lastDeliberateSelection` and **say so**, using its own `capturedAtMs` for the age: *"nothing is selected now; explaining your last selection, lines 4–4 of Hello.py"*. Silently explaining a stale selection is worse than explaining the right thing out loud.
     - Neither available → Tier 3.
  6. Positions are **1-based and inclusive** for both line and column. (`selection.zeroBased` carries the raw editor values if you ever need them; you normally don't.)
  7. If `window.focused` is `false`, the user may be working in a different window than the one that wrote this. Use it, but if the range looks unrelated to what the user is asking about, say so rather than pressing on.

**Tier 3 — ask a connected editor MCP server.** If Tiers 1–2 found nothing, consult the **Known MCP capability gaps** list below. Each entry names a specific *capability* a specific *server family* lacks — never treat an entry as "skip this server entirely"; a server missing one capability (e.g. live selection reading) may still expose another (e.g. listing the active file) that's worth calling directly.
  1. If live selection/caret reading is not already listed as a gap for the connected server family, run `ToolSearch` for it (e.g. `"ide editor selection caret"`) and try it.
  2. If it returns a usable range, use it directly — treat it like a fresh Tier-1/2 hit.
  3. Separately — regardless of step 1's outcome — if you already know (from the gap list, or from a ToolSearch result earlier this session) the name of an "active file" tool for the connected server, call it directly by name (no ToolSearch needed, you already have it). This is a distinct capability from live-selection reading and is commonly supported even when selection reading isn't (see the JetBrains entry below) — its result feeds Tier 4.
  4. If you confirm a *specific capability* is unsupported by a *specific server family*, record it under **Known MCP capability gaps** below (edit this file): name the capability precisely, not the whole server, so working capabilities on that same server stay discoverable.

**Tier 4 — ask.** If Tiers 1–3 found nothing:
  1. You may still identify the *file* from non-tag evidence: an MCP "active file" result from Tier 3 step 3, or the file most recently read, edited or discussed **in your own tool calls** this session. Treat the range as unconfirmed. Do not mine the conversation for IDE tags to do this.
  2. Ask the user for the line range on that file (or to paste the snippet directly) — one question, pre-filled with the file you already resolved, e.g. "Which lines of `session1/Hello.py` should I explain?"
  3. If nothing above identifies even a file, ask the user to paste the selected code or state `path#L..-L..` directly.
- Once you have a file path + line range, read the file with the Read tool (use `offset`/`limit` if the file is large) to get line-numbered content and confirm the exact text of the selection. **Always do this** — never explain from tag or `selection.text` alone, and never trust that text over what's on disk.

**Known MCP capability gaps** (checked in Tier 3 — skip re-searching for these specific capabilities; add a line whenever you confirm a new one, and never write a blanket "skip this server" entry):
- **Claude Code's built-in `ide` server** (`mcp__ide__*`) — confirmed 2026-08-16: exposes only `getDiagnostics` and `executeCode`. **No** selection, caret or active-file tool of any kind. Don't spend a `ToolSearch` on it.
- **JetBrains IDE MCP** (PyCharm/IntelliJ/WebStorm/etc.; tool-name prefix varies by transport/install, e.g. `mcp__idea-sse-mcp__*` over SSE — match by the server's behavior, not a hardcoded prefix) — confirmed 2026-08-16: **no** live selection-range or caret-position tool (`get_symbol_info` needs a line+column you must already know). It **does** expose a working "list open files" tool (e.g. `get_all_open_file_paths`) that returns the active file — that capability is not a gap; call it directly per Tier 3 step 3 whenever this server is connected, regardless of transport.

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