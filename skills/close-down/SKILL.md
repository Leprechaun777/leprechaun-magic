---
name: close-down
description: >
  End-of-session housekeeping. Updates CLAUDE.md with anything worth remembering
  from this session, syncs GitHub issues to match backlog changes, updates the
  README changelog, commits and pushes all work, builds the debug APK, publishes
  it as a GitHub Release, and sideloads it to the phone if connected.
  Use when the user says "close down", "wrap up", "end session", "let's call it",
  "push everything", or "we're done for today".
---

# close-down

End-of-session skill. Six steps: update CLAUDE.md, sync GitHub issues, update README changelog, push, publish a GitHub Release with the latest APK, then sideload the APK to the phone if connected.

> **Customize before use:** replace `<owner>/<repo>` with your GitHub repo, and see
> Step 6 for device-specific adb setup. Steps 5–7 assume an Android/Gradle project;
> skip them for other project types.

## Step 1 — Update CLAUDE.md

Review the current conversation for anything worth adding to CLAUDE.md that isn't already there:

- Commands or workflows discovered this session
- Architectural decisions or constraints learned
- Gotchas, workarounds, or non-obvious behaviour
- Conventions established or confirmed

If CLAUDE.md doesn't exist, create it at the repo root with a minimal structure. If it does exist, read it first and only append or update — never remove existing content unless it is factually wrong.

Keep additions concise: one line per fact where possible. Do not add session-specific ephemera (bug fixes, PR numbers, current task state).

## Step 2 — Sync GitHub issues with CLAUDE.md backlog

Compare the CLAUDE.md backlog against the open GitHub issues. Keep them in sync:

1. List open issues:
   ```
   gh issue list --repo <owner>/<repo> --limit 100 --state open
   ```
2. For every backlog item in CLAUDE.md that has **no corresponding open issue**, create one:
   ```
   gh issue create --repo <owner>/<repo> \
     --title "..." --body "..." --label "bug" (or "enhancement")
   ```
   Use the repo's existing labels as appropriate.
3. For every open issue whose backlog item was **completed this session** (shipped in a commit), close it with a comment referencing the commit:
   ```
   gh issue close {NUMBER} --repo <owner>/<repo> \
     --comment "Shipped in {COMMIT_HASH}"
   ```
4. Do not close issues for items still in the backlog. Do not create duplicate issues for items already tracked.

If no backlog changes were made this session, confirm and skip.

## Step 3 — Update README changelog

**Always do this step.** Read the current README.md. Check `git log` for commits since the last session to confirm which versions shipped. For every version that does not already have a changelog entry, add one at the top of the **Changelog** section. Do not assume entries exist — verify by reading the file.

Format:

```
### vX.Y.Z — Short title *(Mon D, YYYY)*
One paragraph describing what changed and why. Be specific: name new screens,
parsers, data models, or UX changes. Keep it under 5 sentences.
```

Use today's date from the session's `currentDate` memory/context (e.g. `*(Jun 9, 2026)*`).

Rules:
- Newest version at the top.
- Read the Changelog section first, then compare against git log — only skip a version if its entry is already present verbatim.
- Also update the **Status / Current version** line at the top of the README (current version, versionCode, test count) if it has changed.
- If the README has no Changelog section, create one after the Features section.

## Step 4 — Commit and push

Run these steps in order:

1. `git status` — identify what has changed.
2. Stage changes. Prefer specific file names over `git add .`. Never stage `.env`, credential files, or secrets.
3. Draft a commit message that summarises *what changed and why* in one sentence. Include the CLAUDE.md update if one was made.
4. Commit using a HEREDOC so the message formats correctly.
5. `git push` to the current tracking branch. If no upstream is set, tell the user and provide the `git push -u origin <branch>` command to run themselves.
6. Confirm success with the final commit hash and remote URL.

## Step 5 — Build APK and publish GitHub Release

1. Build the debug APK:
   ```
   ./gradlew assembleDebug
   ```
2. Confirm the APK exists at `app/build/outputs/apk/debug/app-debug.apk`.
3. Read `versionName` from `app/build.gradle.kts` to get the tag (e.g. `0.57.1` → tag `v0.57.1`).
4. Check whether a release for that tag already exists:
   ```
   gh release view v{VERSION} --repo <owner>/<repo>
   ```
   - If it already exists, upload the APK as an additional asset using `gh release upload`.
   - If it does not exist, create it with `gh release create`.
5. Create or update the release:
   ```
   gh release create v{VERSION} \
     "app/build/outputs/apk/debug/app-debug.apk#{AppName}-v{VERSION}-debug.apk" \
     --title "v{VERSION} — {short title from changelog}" \
     --repo <owner>/<repo> \
     --notes "{one paragraph from the README changelog entry for this version}"
   ```
6. Confirm the release URL (GitHub prints it on success).

## Step 6 — Push APK to phone

Use wireless debugging (no USB cable needed). The phone pairs via mDNS after the one-time `adb pair` step has been done.

1. Check for a connected device — prefer the mDNS transport over the raw IP:
   ```
   adb devices -l
   ```
2. Look for a line containing `adb-<device-serial>` (the phone's mDNS entry) with state `device`. That is the working wireless transport — note its `transport_id`.
3. If the mDNS entry is present and online, install via that transport:
   ```
   adb -t <transport_id> install -r app/build/outputs/apk/debug/app-debug.apk
   ```
   Or, if only one device is listed, `./gradlew installDebug` works directly.
4. If wireless is not available, fall back to USB:
   - Check again for any device with state `device` (a wired connection will show the bare serial):
     ```
     adb devices -l
     ```
   - If a wired device is present, install via it:
     ```
     ./gradlew installDebug
     ```
   - If still no device, prompt the user to either plug in the USB cable or re-enable Wireless Debugging:
     - **Wireless**: Settings → System → Developer options → Wireless debugging → enable. If a fresh pair is needed, tap "Pair device with pairing code", share the IP:port and 6-digit code, then run:
       ```
       adb pair <ip>:<port> <code>
       adb connect <ip>:<main-port>
       ```
     - Once either connection is live, retry the install.

**Note:** if `adb` is not on PATH, use the full path to your SDK's `platform-tools/adb.exe`. Raw-IP entries routed over a VPN or subnet relay may show as `offline`; ignore them and use the mDNS transport instead.

## Step 7 — Clean up GitHub Actions storage

GitHub Actions storage quota is 0.5 GB (free plan). APK artifacts accumulate fast (~25 MB each); check and prune at the end of every session to avoid hitting the cap.

1. Check current artifact count and size for the repo:
   ```
   gh api "repos/<owner>/<repo>/actions/artifacts?per_page=100" \
     -q '[.artifacts[] | select(.expired==false)] | length'
   ```
2. If more than **3 artifacts** remain, delete all but the newest one:
   ```bash
   newest=$(gh api "repos/<owner>/<repo>/actions/artifacts?per_page=1" -q '.artifacts[0].id')
   ids=$(gh api "repos/<owner>/<repo>/actions/artifacts?per_page=100" \
     -q ".artifacts[] | select(.expired==false and .id != $newest) | .id")
   for id in $ids; do
     gh api -X DELETE "repos/<owner>/<repo>/actions/artifacts/$id" >/dev/null
   done
   ```
3. Report how many were deleted and the estimated storage freed.
4. If you find that `retention-days` in `.github/workflows/build.yml` is set higher than **7**, update it to 7 and include the change in the Step 4 commit.

The rolling `latest-build` **Release** asset is free storage and always has the current APK — artifact retention only needs to cover roughly one week of builds.

## Notes

- If there are no changes to commit, say so and skip the commit step.
- If the push requires credentials the shell doesn't have, stop and tell the user what they need to do.
- Do not force-push or amend. Always create a new commit.
- If your environment has a stale `GITHUB_TOKEN` set, prefix `gh` commands with `GITHUB_TOKEN=""` so the keyring credential is used instead.
- The APK is a debug sideload build. The release notes should remind the user to enable "Install unknown apps" on Android if this is their first sideload.
