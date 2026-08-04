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

  if ! head -1 "$f" | tr -d '\r' | grep -qx -- '---'; then
    err "$name: SKILL.md must start with '---' frontmatter"
    continue
  fi

  fm=$(tr -d '\r' < "$f" | awk 'NR==1{next} /^---[[:space:]]*$/{found=1; exit} {print} END{if(!found) exit 1}') \
    || err "$name: frontmatter not closed with '---'"

  echo "$fm" | grep -q '^name:' || err "$name: frontmatter missing 'name:'"
  echo "$fm" | grep -q '^description:' || err "$name: frontmatter missing 'description:'"

  declared=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  if [ -n "$declared" ]; then
    if [ "$declared" != "$name" ]; then
      err "$name: frontmatter name '$declared' does not match folder name"
    fi
    if ! echo "$declared" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
      err "$name: name '$declared' is not kebab-case"
    fi
  fi
done

# Secret scan over tracked and untracked (non-ignored) files, excluding this
# script's own patterns. git grep exits 0 on match, 1 on no match, >1 on error.
git grep --untracked -nIiE \
  "gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(api[_-]?key|secret|password)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{4,}" \
  -- . ':!scripts/validate-skills.sh'
scan=$?
if [ "$scan" -eq 0 ]; then
  err "possible secret found (see matches above)"
elif [ "$scan" -gt 1 ]; then
  err "secret scan could not run (git grep exited $scan)"
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: all $((${#dirs[@]})) skills valid"
fi
exit $fail
