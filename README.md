# Explain Tools

Claude Code plugin containing two skills:

- `/explain-file` explains a complete source file and writes a generated `.$.md` explanation beside it.
- `/explain-selection` explains the currently selected code in chat.

## Editor prerequisites

### VS Code

For reliable identification of the active file and selected lines, install the VS Code extension **Editor State**. It continuously writes the editor state used by these skills, including the active file and current selection.

Without Editor State, the skills may need an editor MCP integration or an explicit file path or line range.

### JetBrains IDEs

For reliable use in IntelliJ IDEA, PyCharm, WebStorm, or another JetBrains IDE, configure an **IDEA MCP Server** connected through SSE or streamable HTTP. The server should expose the active-file and open-file capabilities used by the skills.

Without a connected IDEA MCP Server, provide an explicit file path for `/explain-file` or a path and line range for `/explain-selection`.

## Build

Windows PowerShell:

```powershell
.\build-plugin.ps1
```

Linux/macOS:

```bash
chmod +x ./build-plugin.sh
./build-plugin.sh
```

The ZIP is written to `dist/explain-tools-<version>.zip`.