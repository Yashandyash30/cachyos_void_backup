# Antigravity Setup Guide: Skills & MCP Servers

Comprehensive guide detailing all installed MCP (Model Context Protocol) servers, helper tools (`tokless`, `rtk`), and custom skills across Google Antigravity environments, including exact step-by-step restoration commands for future installations or new systems.

---

## 1. Installed MCP Servers & Tools Overview

| Component | Type | Binary / Command Location | Purpose |
| :--- | :--- | :--- | :--- |
| **`tokless`** | Standalone Executable | `~/.local/bin/tokless` | Token proxy & executor for token efficiency and MCP management |
| **`rtk`** | Standalone Executable | `~/.local/bin/rtk` | Ultra-compact CLI output proxy (summarizes `ls`, `git`, `read`, etc.) |
| **`codegraph`** | MCP Server (Node.js) | `~/.local/lib/node_modules/@colbymchenry/codegraph` | Codebase structure, call paths, blast radius, symbol exploration |
| **`context-mode`** | MCP Server (Node.js) | `~/.local/lib/node_modules/context-mode` | In-sandbox execution, FTS search, web fetch & indexing without polluting context |
| **`comfyui`** | MCP Server (Node.js) | `~/.local/lib/node_modules/comfyui-mcp` | Workflows, queue, VRAM, and generation bridge to local ComfyUI instance |
| **`confirmtkt`** | MCP Server (Local Git) | `~/confirmtkt-mcp/dist/server.js` | IRCTC train search, seat availability, station code lookup |
| **`brightdata`** | MCP Server (npx) | `@brightdata/mcp` via `npx` | Web scraping, proxying, and SERP queries (optional / API key required) |
| **`humanizer`** | Antigravity Skill | `~/.gemini/config/skills/humanizer/SKILL.md` | Strips AI writing patterns, clichés, staging, and filler from drafted text |

---

## 2. Configuration Files & Discovery Locations

Antigravity checks MCP and Skill configurations at:

1. **Global Configuration:**
   - MCP Server Config: `~/.gemini/config/mcp_config.json` (and `~/.gemini/antigravity-cli/mcp_config.json`)
   - User Skills: `~/.gemini/config/skills/<skill-name>/SKILL.md`
   - User Rules: `~/.gemini/config/rules/` or global instructions in settings.
2. **Local Binaries:**
   - Placed in `~/.local/bin` (must be added to `$PATH`).

---

## 3. Step-by-Step Installation & Restoration Guide

Follow these steps on a fresh system to reinstall all components.

### Step 1: Prerequisites

Ensure Node.js (with npm), Git, and curl are installed:

```bash
# Arch / CachyOS
sudo pacman -S --needed nodejs npm git curl base-devel

# Ubuntu / Debian
sudo apt update && sudo apt install -y nodejs npm git curl build-essential
```

Ensure user binary directory exists and is in `$PATH`:

```bash
mkdir -p ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
```
*(Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc`, `~/.zshrc`, or `~/.config/fish/config.fish`)*

---

### Step 2: Install CLI Proxies (`tokless` & `rtk`)

#### 1. `tokless`
Automated installer:
```bash
curl -fsSL https://raw.githubusercontent.com/HoangP8/tokless/main/scripts/install.sh | bash
```
*Verifies as:* `~/.local/bin/tokless --version`

#### 2. `rtk`
Download or install the `rtk` binary:
```bash
# Verify installation
rtk --version
```

---

### Step 3: Install Node-Based MCP Servers (`npm -g --prefix ~/.local`)

Install globally into user scope (`~/.local`):

```bash
# 1. codegraph
npm install -g --prefix ~/.local @colbymchenry/codegraph

# 2. context-mode
npm install -g --prefix ~/.local context-mode

# 3. comfyui-mcp
npm install -g --prefix ~/.local comfyui-mcp
```

Make sure the symlinks exist in `~/.local/bin`:
```bash
ls -l ~/.local/bin/codegraph ~/.local/bin/context-mode ~/.local/bin/comfyui-mcp
```

---

### Step 4: Install Local Git MCP Server (`confirmtkt`)

Clone repository and build with TypeScript:

```bash
cd ~
git clone https://github.com/uditya-kumar/confirmtkt-mcp.git
cd confirmtkt-mcp
npm install
npm run build

# Link binary to ~/.local/bin
ln -sf ~/confirmtkt-mcp/dist/server.js ~/.local/bin/confirmtkt-mcp
chmod +x ~/.local/bin/confirmtkt-mcp
```

---

### Step 5: Configure MCP Servers in Antigravity

Create or update both config paths: `~/.gemini/config/mcp_config.json` and `~/.gemini/antigravity-cli/mcp_config.json`.

```bash
mkdir -p ~/.gemini/config ~/.gemini/antigravity-cli
```

Write the following content to `~/.gemini/config/mcp_config.json`:

```json
{
  "mcpServers": {
    "codegraph": {
      "command": "/home/void/.local/bin/codegraph",
      "args": [
        "serve",
        "--mcp"
      ],
      "trust": true
    },
    "context-mode": {
      "command": "/home/void/.local/bin/tokless",
      "args": [
        "run-mcp",
        "--context-mode",
        "/home/void/.local/bin/context-mode"
      ],
      "trust": true
    },
    "comfyui": {
      "command": "/home/void/.local/bin/comfyui-mcp",
      "args": [],
      "env": {
        "COMFYUI_URL": "http://127.0.0.1:8188"
      },
      "trust": true
    },
    "confirmtkt": {
      "command": "/home/void/.local/bin/confirmtkt-mcp",
      "args": [],
      "trust": true
    },
    "brightdata": {
      "command": "/usr/bin/npx",
      "args": [
        "-y",
        "@brightdata/mcp"
      ],
      "env": {
        "API_TOKEN": "YOUR_BRIGHTDATA_API_KEY_HERE"
      },
      "trust": true
    }
  }
}
```

*Note: Replace `/home/void` with your system's `$HOME` path if setting up under another user.*

Sync config to the CLI directory:
```bash
cp ~/.gemini/config/mcp_config.json ~/.gemini/antigravity-cli/mcp_config.json
```

---

### Step 6: Install User Skills (`humanizer`)

Skills live in `~/.gemini/config/skills/<skill-name>/SKILL.md`.

```bash
mkdir -p ~/.gemini/config/skills/humanizer
```

Create `~/.gemini/config/skills/humanizer/SKILL.md`:

```markdown
---
name: humanizer
description: |
  Rewrite AI-sounding text so it reads like the writer without changing what it says.
  Use when editing or reviewing prose for AI tells: not-X-but-Y contrasts, one-line
  closers, staged openers, forced triads, dashes everywhere, inflated claims, sales
  language, stock AI words, bold labels, or filler. Based on Wikipedia's "Signs of AI writing."
license: MIT
metadata:
  version: "3.1.0"
---

# Humanizer: remove AI writing patterns

Rewrite AI-sounding text so it reads like the writer, not a chatbot. Keep what it says. Do not make anything up.

## Patterns to Eliminate
1. Staging: Sentences signaling importance rather than facts.
2. Rule-based rhythm: Triads, em-dashes everywhere.
3. Inflation: Ordinary facts presented as revolutionary or expert-backed.
4. Bold lists everywhere: Every bullet point prefixed with bold words.
5. Conversational wrappers: "Sure! Here is...", "In conclusion...".
```

---

## 4. Verification Check

After installation, verify everything is functional:

1. **Check binaries:**
   ```bash
   tokless --version
   rtk --version
   node ~/.local/bin/codegraph --version 2>/dev/null || which codegraph
   which context-mode
   which comfyui-mcp
   node ~/.local/bin/confirmtkt-mcp --help 2>/dev/null || ls -l ~/.local/bin/confirmtkt-mcp
   ```

2. **Verify in Antigravity session:**
   - Check if skills appear under active skills list.
   - Run `codegraph_explore` or use `ctx_execute` to confirm MCP servers respond.
