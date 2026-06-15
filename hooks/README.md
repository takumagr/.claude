# Hooks

## skillspector-autoscan.sh

A **PostToolUse / Bash** hook that automatically runs
[SkillSpector](https://github.com/NVIDIA/skillspector) whenever a Bash command
looks like it installed an AI-agent **skill or plugin**
(`skills add`, `claude plugin …`, `git clone …`).

- **Non-blocking**: it only warns. The install already ran by the time the hook
  fires; it never stops a command.
- **Skill-centric**: it scans only directories that actually contain a
  `SKILL.md` (freshly added under `~/.claude/skills`, `~/.claude/plugins`, the
  cwd, or a just-cloned repo). Plain package installs without a skill are
  ignored.
- On a HIGH/CRITICAL finding it surfaces a warning to the user and injects the
  findings back into the model context so the install can be reviewed.

Wired up in `../settings.json` under `hooks.PostToolUse`.

### Requirements

`skillspector` must be installed and on `PATH` (or at `~/.local/bin/skillspector`).
Install with:

```bash
git clone https://github.com/NVIDIA/skillspector.git
cd skillspector && uv tool install .
```

### Activating after first install

The hook only loads once Claude Code is watching `~/.claude/settings.json`. If
you just added it, open `/hooks` once (reloads config) or restart Claude Code.

### Testing manually

```bash
printf '{"tool_name":"Bash","cwd":"/path/with/skill","tool_input":{"command":"git clone https://github.com/foo/bar"}}' \
  | bash ~/.claude/hooks/skillspector-autoscan.sh
```
