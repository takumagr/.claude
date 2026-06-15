---
name: install-hermes
description: Install Nous Research's Hermes Agent from source (no nousresearch.com dependency)
argument-hint: "[install-dir] [extras]  e.g. ~/hermes  all   (defaults: ~/hermes, all)"
allowed-tools: Bash, Read, Edit
---

# /install-hermes

Install [Hermes Agent](https://github.com/NousResearch/hermes-agent) — Nous Research's
self-improving AI agent — **from GitHub source**, without relying on the official
`hermes-agent.nousresearch.com` installer (that host is blocked on some networks/sandboxes,
e.g. Claude Code on the web).

Arguments (both optional):
- `$1` = install directory (default: `~/hermes`)
- `$2` = dependency extras (default: `all`; use `termux` on Android/Termux, or a comma list like `cli,messaging`)

## What to do

Run these steps in order. Stop and report clearly if any step fails.

### 1. Preflight

```bash
# Tools we need
command -v git  >/dev/null || { echo "git is required"; exit 1; }
python3 --version    # must be >= 3.11 and < 3.14

# uv is the recommended installer. Install it if missing.
if ! command -v uv >/dev/null 2>&1; then
  if curl -fsSL -o /dev/null -w '%{http_code}' https://astral.sh/uv/install.sh | grep -q 200; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "astral.sh blocked — install uv via your package manager (e.g. pipx install uv) and re-run."
    exit 1
  fi
fi
uv --version
```

### 2. Clone (or update) the source

```bash
HERMES_DIR="${1:-$HOME/hermes}"
if [ -d "$HERMES_DIR/.git" ]; then
  git -C "$HERMES_DIR" pull --ff-only
else
  git clone https://github.com/NousResearch/hermes-agent.git "$HERMES_DIR"
fi
cd "$HERMES_DIR"
```

### 3. Create the venv and install

```bash
EXTRAS="${2:-all}"          # e.g. all | termux | cli,messaging
uv venv .venv --python 3.11
source .venv/bin/activate
uv pip install -e ".[${EXTRAS}]"
```

> Notes
> - On **Android/Termux**, pass `termux` as the extras — `all` pulls voice deps that don't build there.
> - `requires-python` is pinned to `>=3.11,<3.14`. If `uv` picks 3.14, the `--python 3.11` flag above forces a compatible interpreter.
> - All deps are exact-pinned upstream and pulled from PyPI — no `nousresearch.com` access is needed.

### 4. Put `hermes` on PATH

The repo ships a `./hermes` launcher that auto-detects `.venv`. Symlink it so it's runnable anywhere:

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$HERMES_DIR/hermes" "$HOME/.local/bin/hermes"
# Ensure ~/.local/bin is on PATH (add to ~/.bashrc / ~/.zshrc if missing)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc";; esac
```

### 5. Configure

```bash
cd "$HERMES_DIR"
[ -f .env ] || cp .env.example .env   # template with all settings
hermes doctor                          # diagnose environment
```

Then run the wizard (interactive — tell the user to run it themselves if you're non-interactive):

```bash
hermes setup            # full configuration wizard (provider, API keys, tools)
# or, for Nous Portal one-subscription setup:
hermes setup --portal
```

### 6. Verify and report

```bash
hermes --help | head -20
```

Report back: install dir, Python version used, extras installed, whether `hermes` is on PATH,
and the exact next command the user should run (`hermes setup`, then `hermes`).

## Useful commands after install

| Command | Purpose |
|---|---|
| `hermes` | Start interactive CLI |
| `hermes model` | Choose LLM provider/model |
| `hermes tools` | Configure enabled tools |
| `hermes gateway` | Start messaging gateway (Telegram/Discord/Slack/…) |
| `hermes update` | Update to latest version (`git pull` + reinstall in source installs) |
| `hermes doctor` | Diagnose issues |

See `docs/hermes-agent.md` in this repo for the full reference.
