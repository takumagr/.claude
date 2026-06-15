# Hermes Agent — install & usage

[Hermes Agent](https://github.com/NousResearch/hermes-agent) is Nous Research's
**self-improving AI agent**: it creates skills from experience, improves them
during use, keeps persistent memory across sessions, and runs on many platforms
(CLI/TUI, Telegram, Discord, Slack, WhatsApp, Signal). It works with 200+ models
via OpenRouter, Nous Portal, OpenAI, Anthropic, and other providers. MIT licensed.

This repo ships a `/install-hermes` slash command that automates the source
install. This doc is the reference behind it.

## Why install from source

The official one-liner is:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

On some networks and sandboxes (including **Claude Code on the web**), the
`hermes-agent.nousresearch.com` host is blocked by the egress policy
(`HTTP 403 x-deny-reason: host_not_allowed`), so that installer can't run.
GitHub and PyPI are reachable, so we install from the cloned source instead —
functionally equivalent and with no `nousresearch.com` dependency.

## Requirements

- **Python** `>=3.11,<3.14` (upstream pins this; 3.14 has no wheels yet for some Rust transitives)
- **git**
- **uv** (recommended). If absent and `astral.sh` is reachable, the script installs it;
  otherwise install via your package manager (`pipx install uv`, `brew install uv`, …).
- Optional system tools used at runtime: `ripgrep`, `ffmpeg`, Node.js (for some features).

## Quick install (this repo's command)

Inside Claude Code:

```
/install-hermes                  # installs to ~/hermes with the "all" extra
/install-hermes ~/apps/hermes    # custom directory
/install-hermes ~/hermes termux  # Android/Termux (avoids voice deps)
/install-hermes ~/hermes cli,messaging   # pick specific extras
```

## Manual install (equivalent)

```bash
# 1. Clone
git clone https://github.com/NousResearch/hermes-agent.git ~/hermes
cd ~/hermes

# 2. venv + install (force Python 3.11 so uv doesn't grab 3.14)
uv venv .venv --python 3.11
source .venv/bin/activate
uv pip install -e ".[all]"        # or .[termux] / .[cli,messaging] / .[all,dev]

# 3. Put `hermes` on PATH (the ./hermes launcher auto-detects .venv)
ln -sf ~/hermes/hermes ~/.local/bin/hermes
#   ensure ~/.local/bin is on PATH

# 4. Configure
cp .env.example .env
hermes doctor
hermes setup            # full wizard  (or: hermes setup --portal)
hermes                  # start chatting
```

## Dependency extras

The full set lives in `pyproject.toml` under `[project.optional-dependencies]`.
Common ones:

| Extra | Pulls in |
|---|---|
| `all` | everything (default for desktop/server) |
| `termux` | curated Android-safe set (no voice) |
| `cli` | terminal menu niceties |
| `messaging` | Telegram + Discord + Slack |
| `slack` / `matrix` | individual chat platforms |
| `anthropic` | Claude provider SDK |
| `voice` / `tts-premium` | speech in/out |
| `dev` | pytest, ruff, ty, debugpy (contributors) |

## Configuration

- `.env` (copied from `.env.example`) holds API keys and settings.
- `hermes setup` — interactive wizard that configures provider, model, keys, and tools.
- `hermes setup --portal` — log in to **Nous Portal** via OAuth for one subscription
  covering models + web search + image gen + TTS + cloud browser (no separate keys).
- `hermes model` / `hermes tools` / `hermes config set` — adjust individual settings later.

## Everyday commands

| Command | Purpose |
|---|---|
| `hermes` | Interactive CLI / TUI |
| `hermes gateway` | Start messaging gateway (Telegram, Discord, Slack, …) |
| `hermes model` | Choose LLM provider/model |
| `hermes tools` | Enable/disable tools |
| `hermes update` | Update (source install: `git pull` + reinstall) |
| `hermes doctor` | Diagnose problems |

## Updating a source install

```bash
cd ~/hermes
git pull --ff-only
source .venv/bin/activate
uv pip install -e ".[all]"        # match the extras you originally used
```

## Notes for ephemeral environments

Hermes is a long-running personal agent meant for your own machine, VPS, or a
container you control. **It does not belong in an ephemeral sandbox** (like a
Claude Code web session container), which is reclaimed after inactivity — any
install there disappears with the container. Run the install on a host you keep.

## Links

- Repo: https://github.com/NousResearch/hermes-agent
- Docs: https://hermes-agent.nousresearch.com/docs/ (may be blocked on restricted networks)
- Nous Portal: https://portal.nousresearch.com
