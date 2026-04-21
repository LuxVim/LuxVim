# GitHub Org → josstei Migration Plan

**Status:** Ready for execution
**Date:** 2026-04-18
**Owner:** @josstei

## Goal

Transfer the LuxVim repository from the `LuxVim` GitHub organization to the `josstei` personal account, optionally rename to lowercase `luxvim` for `package.json` URL parity, and re-point all developer-machine remotes. Zero downtime; all existing URLs continue to resolve via GitHub's permanent 301 redirects.

## Architecture

Two-phase change:

1. **GitHub-side** — repo transfer + optional rename via the web UI. Seconds of elapsed time.
2. **Local-side** — `git remote set-url` on any clone still pointing at the old location.

Phase 2 of the npm distribution (release workflow + npm Trusted Publishing) is easier if done after this migration, since the OIDC claim embeds `repo:<owner>/<name>` and must match the new identity.

## Blast radius

Single repository. Everything transfers together:

- All branches (including `feat/npm-foundation`, `main`)
- All 34+ commits on `feat/npm-foundation`
- Open PR #7 (becomes `github.com/josstei/luxvim/pull/7`)
- All issues, releases, tags, stars, forks, watchers
- Repo-level secrets (if any) survive the transfer
- GitHub Actions workflow (`.github/workflows/test.yml`) runs under the new identity on next push
- Webhooks are preserved (may need manual verification)

## Timing recommendation

Execute **before** merging PR #7 and **before** starting the Phase 2 release workflow. Rationale:

- PR #7 is the foundation commit; its permanent record is cleaner if stored under `josstei` rather than the original `LuxVim` org plus redirect.
- npm OIDC Trusted Publishing requires re-registration if the repo owner/name changes after setup. Transferring first saves one round of reconfiguration.
- Transfer is a single one-time event with zero user-visible downtime, so there's no operational reason to defer.

---

## Prerequisites — decisions to make

- [ ] **Decision 1: Final repo name casing.**
  - **Option A (recommended)** — rename to `luxvim` (lowercase) during transfer. Reason: matches the `github.com/josstei/luxvim` URLs already hardcoded into `packages/luxvim/package.json` (`homepage`, `repository.url`, `bugs.url`). Character-for-character parity.
  - Option B — keep as `LuxVim` (PascalCase). Works — GitHub resolves URLs case-insensitively — but the committed URLs in `package.json` would visually mismatch the canonical form.

- [ ] **Decision 2: Disposition of the `LuxVim` GitHub org.**
  - Delete — frees the org name, zero cost since no repos remain there post-transfer.
  - Keep — reserved but unused. Some brand continuity, zero functional benefit.
  - Non-blocking either way; can be decided later.

- [ ] **Decision 3: Timing vs PR #7.**
  - **Option A (recommended)** — transfer before merging PR #7. The PR URL `pull/7` lives under `josstei` as its permanent record.
  - Option B — merge PR #7 first, then transfer. PR URL becomes a redirect (still works indefinitely).

- [ ] **Decision 4: `@luxvim` npm org.** Not affected by this migration (npm orgs are separate from GitHub orgs), and Phase 1 doesn't claim any npm scope beyond `@josstei`. No action needed here; flagged for completeness.

---

## Pre-transfer checklist

- [ ] Confirm no uncommitted work on other machines that references the old remote
- [ ] Confirm PR #7's CI run has completed (or is not mid-run) before the transfer
- [ ] If Decision 2 = "delete" — confirm the `LuxVim` org has no other repos (transfer only affects one repo at a time)
- [ ] Note the current repo URL for verification later: `git@github.com:LuxVim/LuxVim.git`

---

## Step 1 — GitHub UI: transfer

Performed in a browser at github.com.

- [ ] Navigate to `https://github.com/LuxVim/LuxVim/settings`
- [ ] Scroll to **Danger Zone** (bottom of the page)
- [ ] Click **Transfer ownership**
- [ ] New owner: `josstei`
- [ ] Confirm by typing the repo name `LuxVim`
- [ ] Click **I understand, transfer this repository**

Expected: GitHub redirects to the new location. Repo is now at `https://github.com/josstei/LuxVim` (casing unchanged until Step 2).

## Step 2 — GitHub UI: rename (only if Decision 1 = A)

- [ ] Navigate to `https://github.com/josstei/LuxVim/settings`
- [ ] Under **Repository name**, change `LuxVim` → `luxvim`
- [ ] Click **Rename**

Expected: repo now at `https://github.com/josstei/luxvim`. The original URL and the `josstei/LuxVim` intermediate URL both 301-redirect.

## Step 3 — Local: update origin remote

On your main development machine:

- [ ] Update the origin URL in the main clone:

```bash
cd /Users/josstei/Development/lux-workspace/LuxVim
git remote -v                                              # record current state
git remote set-url origin git@github.com:josstei/luxvim.git   # adjust casing per Decision 1
git remote -v                                              # verify new URL
```

- [ ] Verify fetch works against the new URL:

```bash
git fetch origin
git branch -vv                                             # tracking info should show josstei/luxvim
```

- [ ] The worktree at `.worktrees/npm-foundation` shares the main clone's `.git` directory, so its remote is updated automatically. Verify:

```bash
cd .worktrees/npm-foundation
git remote -v                                              # should show josstei/luxvim too
git fetch origin
```

Expected: no warnings, no errors. `git pull` / `git push` now target the new location.

## Step 4 — Verify PR #7 followed the transfer

- [ ] Visit the old URL in a browser — should redirect to the new location:
  - Old: `https://github.com/LuxVim/LuxVim/pull/7`
  - New: `https://github.com/josstei/luxvim/pull/7`
- [ ] Run `gh pr view 7` from the worktree — confirms CLI access under new identity
- [ ] Check the **Actions** tab on the new repo — the last test.yml run is visible; the next push on the feature branch will trigger a fresh run

## Step 5 — Re-run CI with the new identity

Push any pending local commit (or an empty commit) to confirm the workflow runs correctly under `josstei/luxvim`:

- [ ] Option A: if there are local commits, push normally:

```bash
git push origin feat/npm-foundation
```

- [ ] Option B: if nothing's pending, force a CI re-run via the Actions UI:
  - Visit `https://github.com/josstei/luxvim/actions/workflows/test.yml`
  - Click **Run workflow** on the `feat/npm-foundation` branch

Expected: tests workflow green on Neovim `v0.10.0`, `stable`, and `nightly`.

---

## Post-transfer cleanup (lower priority)

### Documentation references

- [ ] Audit the top-level `README.md` for any hardcoded GitHub URLs pointing at `LuxVim/LuxVim` (shield badges, install instructions, etc.). Update to `josstei/luxvim` for visual consistency. Redirects cover functionality; this is purely aesthetic.
- [ ] Audit `luxvim.org` (the marketing site) for any links back to the GitHub repo. Same treatment.

### GitHub integrations

- [ ] If any external CI integrations (Codecov, Coveralls, Dependabot, etc.) are wired up, confirm they still authorize. Most use the GitHub App model and follow the repo transfer automatically; if one doesn't, re-authorize from the service's dashboard.
- [ ] Review repo-level notifications/alerts — ownership of subscriptions may transfer with the repo.

### Branch protection rules

- [ ] Visit `Settings → Branches` on the new repo. Branch protection rules usually survive transfer but verify `main` still requires `test.yml` green before merge.

---

## Rollback

If something goes wrong during Step 1 transfer (unlikely — GitHub's flow is atomic and reversible):

- [ ] Transfer the repo back from `josstei` to `LuxVim` via the same Danger Zone flow on `github.com/josstei/luxvim/settings`.
- [ ] Restore local origin URL: `git remote set-url origin git@github.com:LuxVim/LuxVim.git`.
- [ ] GitHub still preserves the original URL's redirect during the rollback window.

No data is lost in transfer — it's a pointer change, not a clone. Rollback is always a UI operation.

---

## What will not work / needs attention

| Symptom | Cause | Remedy |
|---|---|---|
| `git push` from a stale clone warns about redirect | origin still points at old URL | `git remote set-url` as in Step 3 |
| README shield.io badges show placeholder / 404 | badge URLs hardcode the repo owner | Update badge markdown to `josstei/luxvim` |
| `gh pr list` in an unupdated clone returns empty or errors | CLI uses origin URL | Update origin, or pass `--repo josstei/luxvim` |
| Old notifications in GitHub mobile/email link to `LuxVim/LuxVim` | GitHub 301-redirects these URLs | No action — works transparently |

## What does not break

- Committed `@josstei/luxvim` package name — unrelated to repo location
- Plugin source strings (`josstei/quill.nvim`, `josstei/fathom.nvim`, `josstei/whisk.nvim`) — unrelated to this repo's transfer
- Launcher code, test suite, plenary tests — none depend on the GitHub URL at runtime
- Commit author metadata — already `josstei@users.noreply.github.com`, independent of repo owner
- Existing `~/.local/bin/lux` launcher script — uses local filesystem paths, not GitHub URLs
- npm artifacts (`npm pack`, `npm install -g` from tarball) — local operation, doesn't touch GitHub

---

## Phase 2 preparation (context only — not part of this migration)

When Phase 2 introduces `.github/workflows/release.yml` with npm Trusted Publishing:

- The OIDC subject claim embeds `repo:josstei/luxvim` (or the chosen casing)
- You register the trust ONCE on npm's side: npmjs.com → `@josstei/luxvim` → Settings → Publishing → Add Trusted Publisher
- Provider: GitHub Actions
- Owner: `josstei`
- Repository: `luxvim` (matches Decision 1 casing)
- Workflow filename: `release.yml`

If the migration happens first, this registration is a one-time operation. If you set up trust under `LuxVim/LuxVim` and migrate afterward, the existing trust would have to be removed and re-added. Sequencing correctly avoids that churn.

---

## Verification criteria — done when all pass

- [ ] `https://github.com/josstei/luxvim` loads the repo homepage
- [ ] `https://github.com/LuxVim/LuxVim` 301-redirects to the above
- [ ] `git remote -v` in the main clone shows `josstei/luxvim.git`
- [ ] `git fetch` and `git push` work without warnings
- [ ] `gh pr view 7` returns the PR under the new URL
- [ ] GitHub Actions workflow run appears under the new repo and passes
- [ ] No new issues reported by collaborators (if any) about broken links

---

## Summary

**Downtime:** zero.
**External breakage:** zero (everything redirects indefinitely).
**Developer-machine work:** ~5 minutes to update `origin` and sanity-check.
**Order of operations:** do this before merging PR #7 and before Phase 2 CI work.
**Reversibility:** transfer is fully reversible via the same UI flow if needed.
