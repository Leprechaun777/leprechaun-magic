#!/usr/bin/env bash
# Validate every skill under skills/: structure, frontmatter, and a basic
# secret/personal-data scan. Exits non-zero if any check fails.
set -u
top=$(git rev-parse --show-toplevel) || exit 1
cd "$top" || exit 1
fail=0
err() { echo "FAIL: $1"; fail=1; }

shopt -s nullglob
dirs=(skills/*/)
if [ ${#dirs[@]} -eq 0 ]; then
  err "no skills found under skills/"
  exit 1
fi

for dir in "${dirs[@]}"; do
  name=$(basename "$dir")
  f="${dir}SKILL.md"

  if [ ! -f "$f" ]; then
    err "$name: missing SKILL.md"
    continue
  fi

  if ! head -1 "$f" | tr -d '\r' | grep -qE -- '^---[[:space:]]*$'; then
    err "$name: SKILL.md must start with '---' frontmatter"
    continue
  fi

  if ! fm=$(tr -d '\r' < "$f" | awk 'NR==1{next} /^---[[:space:]]*$/{found=1; exit} {print} END{if(!found) exit 1}'); then
    err "$name: frontmatter not closed with '---'"
    continue
  fi

  echo "$fm" | grep -q '^name:' || err "$name: frontmatter missing 'name:'"
  echo "$fm" | grep -q '^description:' || err "$name: frontmatter missing 'description:'"

  declared=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')
  if [ -n "$declared" ]; then
    if [ "$declared" != "$name" ]; then
      err "$name: frontmatter name '$declared' does not match folder name"
    fi
    if ! echo "$declared" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
      err "$name: name '$declared' is not kebab-case"
    fi
  fi
done

# Everything directly under skills/ must be a skill folder.
for entry in skills/*; do
  if [ ! -d "$entry" ]; then
    err "stray file under skills/: $entry (every entry must be a skill folder)"
  fi
done

# Secret scan over tracked and untracked (non-ignored) files, excluding this
# script's own patterns. Covers vendor token formats plus quoted or unquoted
# key/secret/password assignments. Matches on obvious placeholder values are
# filtered out. git grep exits 0 on match, 1 on no match, >1 on error.
secret_re="gh[pousr]_[A-Za-z0-9]{20,}"
secret_re="$secret_re|github_pat_[A-Za-z0-9_]{20,}"
secret_re="$secret_re|AKIA[0-9A-Z]{16}"
secret_re="$secret_re|sk-[A-Za-z0-9_-]{20,}"
secret_re="$secret_re|xox[baprs]-[A-Za-z0-9-]{10,}"
secret_re="$secret_re|AIza[0-9A-Za-z_-]{35}"
secret_re="$secret_re|-----BEGIN [A-Z ]*PRIVATE KEY-----"
secret_re="$secret_re|(api[_-]?key|secret|password)[[:space:]]*[:=][[:space:]]*['\"]?[^'\"[:space:]]{8,}"
placeholder_re="your[-_]|example|placeholder|dummy|sample|changeme|redacted|x{4,}|\*{4,}|<[^>]+>|\{\{[^}]+\}\}"

scan_output=$(git grep --untracked -nIiE "$secret_re" -- . ':!scripts/validate-skills.sh')
scan=$?
if [ "$scan" -gt 1 ]; then
  err "secret scan could not run (git grep exited $scan)"
elif [ "$scan" -eq 0 ]; then
  # Test placeholders against the matched content only — the path portion of
  # "path:line:content" may itself contain words like "example".
  hits=$(printf '%s\n' "$scan_output" | while IFS= read -r line; do
    content=${line#*:*:}
    printf '%s' "$content" | grep -qiE "$placeholder_re" || printf '%s\n' "$line"
  done)
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits"
    err "possible secret found (see matches above)"
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: all $((${#dirs[@]})) skills valid"
fi
exit $fail
