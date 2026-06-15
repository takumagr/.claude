#!/usr/bin/env bash
# SkillSpector auto-scan hook (PostToolUse / Bash).
#
# When a Bash command looks like it installed an AI-agent skill or plugin,
# automatically run `skillspector scan` against the freshly added skill(s) and
# surface the verdict. This is a NON-BLOCKING guard: it only warns, it never
# stops the install (the command already ran by the time PostToolUse fires).
#
# Input : hook JSON on stdin (.tool_input.command, .cwd)
# Output: JSON with systemMessage (shown to the user) and
#         hookSpecificOutput.additionalContext (fed back to the model).
# Exits 0 always so a scanner hiccup never breaks the workflow.

set -uo pipefail

# Emit nothing and leave quietly. Used for "not a skill install" / no targets.
quiet_exit() { exit 0; }

command -v jq >/dev/null 2>&1 || quiet_exit

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] || quiet_exit

# Only react to skill/plugin install-shaped commands.
if ! printf '%s' "$cmd" | grep -qiE '(skills[[:space:]]+add)|(claude[[:space:]]+plugin)|(plugin[[:space:]]+(install|add))|(git[[:space:]]+clone)'; then
  quiet_exit
fi

# Resolve the skillspector binary across common install locations.
SS=""
for cand in skillspector "$HOME/.local/bin/skillspector" /root/.local/bin/skillspector; do
  if command -v "$cand" >/dev/null 2>&1; then SS="$(command -v "$cand")"; break; fi
  [ -x "$cand" ] && { SS="$cand"; break; }
done
if [ -z "$SS" ]; then
  printf '%s' '{"systemMessage":"SkillSpector auto-scan: skillspector binary not found on PATH; skipped scan.","suppressOutput":true}'
  exit 0
fi

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

# Collect candidate skill directories.
declare -a candidates=()

# 1) git clone <url> [dir] -> the clone target, if it exists.
if printf '%s' "$cmd" | grep -qiE 'git[[:space:]]+clone'; then
  clonedir="$(printf '%s' "$cmd" | grep -oE 'git[[:space:]]+clone.*' \
    | sed -E 's/git[[:space:]]+clone//; s/--[a-zA-Z-]+(=[^ ]+)?//g' \
    | awk '{for(i=1;i<=NF;i++)print $i}' | tail -n +1)"
  url="$(printf '%s' "$clonedir" | grep -oE '(https?://|git@)[^ ]+' | head -1)"
  explicit="$(printf '%s' "$clonedir" | grep -vE '(https?://|git@)' | grep -E '.' | head -1)"
  if [ -n "$explicit" ] && [ -d "$cwd/$explicit" ]; then
    candidates+=("$cwd/$explicit")
  elif [ -n "$explicit" ] && [ -d "$explicit" ]; then
    candidates+=("$explicit")
  elif [ -n "$url" ]; then
    base="$(basename "$url" .git)"
    [ -d "$cwd/$base" ] && candidates+=("$cwd/$base")
  fi
fi

# 2) Any SKILL.md added/changed in the last 5 minutes under known skill roots.
for root in "$HOME/.claude/skills" "$HOME/.claude/plugins" "$cwd"; do
  [ -d "$root" ] || continue
  while IFS= read -r sk; do
    [ -n "$sk" ] && candidates+=("$(dirname "$sk")")
  done < <(find "$root" -maxdepth 6 -name SKILL.md -newermt '-5 minutes' 2>/dev/null)
done

[ "${#candidates[@]}" -gt 0 ] || quiet_exit

# Dedup, and keep only dirs that actually contain a SKILL.md.
declare -a targets=()
declare -A seen=()
for c in "${candidates[@]}"; do
  [ -n "$c" ] || continue
  rp="$(cd "$c" 2>/dev/null && pwd)" || continue
  [ -n "${seen[$rp]:-}" ] && continue
  seen[$rp]=1
  if find "$rp" -maxdepth 4 -name SKILL.md 2>/dev/null | grep -q .; then
    targets+=("$rp")
  fi
done

[ "${#targets[@]}" -gt 0 ] || quiet_exit

# Scan each target (cap at 5) and collect verdicts.
summary=""
detail=""
risky=0
count=0
for t in "${targets[@]}"; do
  count=$((count + 1))
  [ "$count" -gt 5 ] && break
  out="$(mktemp)"
  timeout 90 "$SS" scan "$t" --no-llm --format json --output "$out" >/dev/null 2>&1
  if [ ! -s "$out" ]; then rm -f "$out"; continue; fi
  name="$(jq -r '.skill.name // "unknown"' "$out" 2>/dev/null)"
  score="$(jq -r '.risk_assessment.score // "?"' "$out" 2>/dev/null)"
  sev="$(jq -r '.risk_assessment.severity // "?"' "$out" 2>/dev/null)"
  rec="$(jq -r '.risk_assessment.recommendation // "?"' "$out" 2>/dev/null)"
  nissues="$(jq -r '.issues | length' "$out" 2>/dev/null)"
  top="$(jq -r '.issues | sort_by(-( .confidence // 0 )) | .[0:3] | map("    - " + ((.severity // "?")|ascii_upcase) + " " + (.id // "") + " " + (.pattern // .category // "") + " (" + (.location.file // "?") + ":" + ((.location.start_line // "?")|tostring) + ")") | join("\n")' "$out" 2>/dev/null)"
  rm -f "$out"

  case "$sev" in HIGH|CRITICAL) risky=1 ;; esac
  case "$rec" in "DO NOT INSTALL"|"REJECT") risky=1 ;; esac

  summary="${summary}\n  • ${name}: ${rec} (${sev}, score ${score}/100, ${nissues} issue(s)) [${t}]"
  detail="${detail}\n- ${name} @ ${t}: recommendation=${rec}, severity=${sev}, score=${score}/100, issues=${nissues}"
  [ -n "$top" ] && detail="${detail}\n${top}"
done

[ -n "$summary" ] || quiet_exit

if [ "$risky" -eq 1 ]; then
  header="⚠️ SkillSpector detected security risks in a newly installed skill:"
  ctx_lead="A skill/plugin was just installed and SkillSpector flagged HIGH/CRITICAL risk. Warn the user clearly, show the findings below, and recommend reviewing or removing the skill before using it. Do NOT silently proceed."
else
  header="✅ SkillSpector scanned the newly installed skill(s):"
  ctx_lead="A skill/plugin was just installed and SkillSpector completed a static scan. Briefly relay the verdict to the user."
fi

sys="$(printf '%b' "${header}${summary}")"
ctx="$(printf '%b' "${ctx_lead}\nSkillSpector results:${detail}")"

jq -n --arg sys "$sys" --arg ctx "$ctx" \
  '{systemMessage: $sys, suppressOutput: true, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
exit 0
