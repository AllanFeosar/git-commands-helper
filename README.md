# Git Helper CLI v3.0
**Developer Workflow Toolkit — PowerShell | Windows · Linux · macOS**

A MAS-style interactive CLI that solves the most painful git workflows developers hit daily. No external dependencies beyond PowerShell and git.

---

## Requirements

### Windows (8 / 10 / 11)
- Windows PowerShell 5.1 or later (built-in)
- git installed and available in PATH ([https://git-scm.com](https://git-scm.com))

### Linux / macOS
- PowerShell 7+ (`pwsh`) — the script uses `git-helper.sh` to launch it
  - macOS: `brew install --cask powershell`
  - Ubuntu: see [https://aka.ms/install-powershell-ubuntu](https://aka.ms/install-powershell-ubuntu)
  - Fedora: see [https://aka.ms/install-powershell-fedora](https://aka.ms/install-powershell-fedora)
- git installed and available in PATH

Must be run from inside a git repository.

---

## How to Run

### Windows

#### Option A — One-time run (no permanent change)
```powershell
powershell -ExecutionPolicy Bypass -File ".\git-helper.ps1"
```

#### Option B — Allow local scripts permanently (your user account only)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Run this once, then launch the script normally with `.\git-helper.ps1` going forward.

#### Option C — Run with full path
```powershell
& "C:\path\to\git-helper.ps1"
```
Replace `C:\path\to\` with the actual folder where you saved the script. Works from any directory.

### Linux / macOS
```bash
bash git-helper.sh
```
The launcher checks for `pwsh`, shows install instructions if missing, then starts the tool.

---

## Menu Overview

```
  MAIN MENU

    [1]   Cherry Pick            Single commit — NEW or OLD diff
    [2]   Range Pick             Commit range A..B, keep or squash
    [3]   Hotfix Broadcast       One commit applied to N branches at once
    [4]   Conflict Pre-Check     Dry-run: will this cherry-pick conflict?
    [5]   Wrong Branch Rescue    Move latest commit to the correct branch
    [6]   Undo Last Cherry-Pick  Smart reset (not pushed) or revert (pushed)
    [7]   Clean Merged Branches  Delete all local branches merged into base
    [8]   Commit Fixup           Fix an older commit and autosquash it in
    [9]   Multi-Commit Rescue    Move N commits to a new branch
    [10]  Reflog Recovery        Browse reflog and recover lost commits
    [11]  Amend + Force Push     Amend last commit with safe force-with-lease
    [12]  Multi-Pick Squash      N commits from anywhere -> one squashed commit
    [0]   Exit
```

Type **Q** at any prompt inside a flow to cancel and return to this menu.

---

## Option Details & Sample Problems

---

### [1] Cherry Pick — Single commit, NEW or OLD diff

**What it does:**
Applies one specific commit onto any branch, or reverses what it did.

**Steps it walks you through:**
1. Commit hash to pick
2. NEW diff (apply the commit) or OLD diff (undo/reverse the commit)
3. Target branch to apply onto
4. New commit message

**Sample problems it solves:**

> *"A bug fix landed on `feature/login`. I need it on `main` right now without merging the whole feature."*
- Run option 1, pick the fix commit hash, choose NEW diff, target branch = `main`

> *"We shipped a bad commit to production. I need to reverse exactly what it changed on the `release` branch."*
- Run option 1, enter the bad commit hash, choose OLD diff, target branch = `release`

---

### [2] Range Pick — Commit range A through B

**What it does:**
Cherry-picks every commit from A to B (inclusive). Fixes git's silent off-by-one: `git A..B` excludes A — this tool always uses the correct `A^..B` form. Optionally squashes the entire range into one clean commit.

**Steps it walks you through:**
1. Start commit hash (oldest to include)
2. End commit hash (newest to include)
3. Keep individual commits OR squash into one (with your message)
4. Target branch

**Sample problems it solves:**

> *"A feature was built across 6 commits. I need all 6 on the `release/2.1` branch as a single clean backport commit."*
- Run option 2, enter start and end hashes, choose squash, enter the backport message, target = `release/2.1`

> *"I cherry-picked A..B three times and kept missing the first commit because of the exclusion syntax."*
- This tool always uses `A^..B` so A is always included — no more off-by-one.

---

### [3] Hotfix Broadcast — One commit applied to N branches at once

**What it does:**
Applies a single commit (e.g. a security fix) to multiple release branches in one automated loop. Uses `-x` to embed the source commit hash in every cherry-pick for a full audit trail. Reports per-branch success or failure. Returns you to your original branch when done.

**Steps it walks you through:**
1. Commit hash to broadcast
2. Target branches — enter one per line, blank line to finish
3. Whether to push each branch to remote after picking

**Sample problems it solves:**

> *"A critical security patch landed on `main`. I need it on `release/2.1`, `release/2.2`, and `release/2.3` before end of day."*
- Run option 3, enter the patch hash, add all 3 release branches, choose to push — done in one flow instead of 12 manual commands.

> *"I broadcast a hotfix to 5 branches manually and forgot to push one."*
- Option 3 pushes every branch immediately after each pick and shows a results table at the end.

---

### [4] Conflict Pre-Check — Dry-run before you commit

**What it does:**
Tests whether a cherry-pick would conflict on a target branch WITHOUT making any permanent changes. Stashes your uncommitted work, checks out the target, attempts the pick, then always aborts and restores everything exactly as it was.

**Steps it walks you through:**
1. Commit hash to test
2. Target branch to test against

**Sample problems it solves:**

> *"I'm about to broadcast a fix to 8 branches. I don't want to find out there's a conflict halfway through."*
- Run option 4 first on your most sensitive branch to verify it would apply cleanly.

> *"I have no idea if this old commit is compatible with the current state of `release/1.x`."*
- Option 4 tells you exactly which files would conflict — zero risk.

---

### [5] Wrong Branch Rescue — Move latest commit to the correct branch

**What it does:**
The classic mistake: you committed to `main` instead of `feature/xyz`. This cherry-picks your latest commit onto the correct branch, then resets it off the wrong one — all in one guided flow.

**Steps it walks you through:**
1. Shows your current branch and last 5 commits
2. Destination branch
3. Confirmation with clear warning about history rewrite

**Sample problems it solves:**

> *"I typed `git commit` without realising I was still on `main`. The commit belongs on `feature/payments`."*
- Run option 5, enter `feature/payments` as the destination — commit moves, `main` is reset.

> *"I committed a WIP directly to `develop` when I have a feature branch for it."*
- Same flow: option 5 moves it cleanly.

**Important:** Only moves the single latest commit. Only use before pushing — it resets history on the source branch.

---

### [6] Undo Last Cherry-Pick — Smart reset or revert

**What it does:**
Intelligently undoes the most recent cherry-pick. Detects whether the commit was pushed to remote and picks the safe strategy automatically:
- **Not pushed** → `git reset --hard ORIG_HEAD` (removes the commit entirely)
- **Pushed** → `git revert HEAD --no-edit` (adds a new undo commit, safe for shared branches)

**Steps it walks you through:**
1. Shows current branch, last commit, and remote sync status
2. Displays which strategy was chosen and why
3. Confirmation before executing

**Sample problems it solves:**

> *"I cherry-picked the wrong commit. I need to undo it but I can't remember if I pushed yet."*
- Run option 6 — it checks for you and uses the correct method.

> *"I used `git reset --hard` on a commit that was already pushed and broke the shared branch."*
- Option 6 prevents this by detecting push state and defaulting to `revert` when in doubt.

---

### [7] Clean Merged Branches — Delete all dead local branches

**What it does:**
Finds every local branch that has already been merged into a base branch (e.g. `main`) and deletes them all in one go. Protected branches (`main`, `master`, `develop`, your current branch) are never touched.

**Steps it walks you through:**
1. Base branch to check against (defaults to `main`)
2. Shows the list of branches that will be deleted
3. Confirmation before deleting

**Sample problems it solves:**

> *"I have 40 local branches from old PRs. They're all merged but cleaning them manually takes forever."*
- Run option 7, confirm, done in seconds.

> *"I can never remember the `git branch --merged | grep -v main | xargs git branch -d` command."*
- Option 7 handles this for you with a clear preview before anything is deleted.

---

### [8] Commit Fixup — Fix an older commit and autosquash

**What it does:**
The "I forgot to include this small change in that commit" flow. Stages your current changes as a fixup for any older commit, then runs `git rebase --autosquash` non-interactively to merge it in cleanly. Replaces four manual commands most developers don't know.

**Steps it walks you through:**
1. Shows uncommitted changes and recent commit log
2. Target commit hash to fix
3. Stage all changes (`git add -A`) or use what's already staged
4. Confirmation with history-rewrite warning

**Under the hood:**
```
git add -A                             (if chosen)
git commit --fixup=<target-hash>
git rebase -i --autosquash <hash>^     (non-interactive, no editor)
```

**Sample problems it solves:**

> *"I wrote a test for a function but the function commit was 3 commits ago. I want the test to live in the same commit."*
- Run option 8, point it at the function's commit hash, done.

> *"I spotted a typo in a commit from this morning. Amending doesn't work because it's not the last commit."*
- Option 8 creates a fixup and squashes it in automatically.

**Important:** Rewrites history. Do not use on commits that are already pushed to a shared remote.

---

### [9] Multi-Commit Rescue — Move N commits to a new branch

**What it does:**
You made 2–10 commits on the wrong branch and need all of them moved. This creates a new branch at your current HEAD (which already contains all the commits), then resets the original branch back — 2 git commands regardless of how many commits you need to move.

**Steps it walks you through:**
1. Shows your current branch and last 10 commits (numbered)
2. How many commits to move (1–10)
3. Name for the new branch (validated — won't overwrite an existing one)
4. Confirmation showing the two-step plan
5. Rolls back (deletes new branch) automatically if the reset fails

**Sample problems it solves:**

> *"I made 5 feature commits straight onto `main` before realising I never created a feature branch."*
- Run option 9, enter 5, name the new branch `feature/my-work` — done in seconds.

> *"I've been committing to `develop` for 3 days instead of my sprint branch. Now I need to move 8 commits."*
- Option 9 moves all 8 at once without cherry-picking each individually.

**Important:** Rewrites history on the original branch. Only use before pushing.

---

### [10] Reflog Recovery Wizard — Recover lost commits

**What it does:**
Shows the last 15 entries from the git reflog in a numbered table (hash, reflog label, action description). You pick any entry and choose to either safely create a new branch there, or hard-reset your current branch to that point.

**Steps it walks you through:**
1. Displays the 15 most recent reflog entries
2. Pick an entry by number
3. Choose action:
   - **[1] Create new branch** at that SHA — safe, non-destructive
   - **[2] Hard-reset current branch** to that SHA — destructive, requires typing `YES`

**Sample problems it solves:**

> *"I ran `git reset --hard` and lost commits I needed. I have no idea what the hash was."*
- Run option 10, find the entry just before the reset in the reflog, create a branch there to recover the commits.

> *"I accidentally deleted a branch I was working on."*
- Option 10 lets you find the last HEAD position on that branch from the reflog and restore it without needing to remember the hash.

---

### [11] Amend + Safe Force-Push — Amend last commit with safety gate

**What it does:**
Amends the last commit (message only, new changes, or both), then force-pushes using `--force-with-lease` instead of `--force`. Before pushing, it checks whether the remote has commits you don't have (indicating a shared branch) and warns loudly, requiring you to type `FORCE` to confirm.

**Steps it walks you through:**
1. Choose amend type: message only / stage changes + keep message / stage changes + new message
2. Shows uncommitted changes if staging
3. Checks remote state — warns with a danger box if others may have pushed
4. Confirmation (Y/N normally, type `FORCE` if shared-branch risk detected)
5. Amends the commit and pushes with `--force-with-lease`

**Under the hood:**
```
git commit --amend [-m "new message"] [--no-edit]
git push --force-with-lease
```

**Sample problems it solves:**

> *"I pushed a commit with a typo in the message. I need to fix it without creating a new 'fix typo' commit."*
- Run option 11, choose option 1 (message only), enter the corrected message — amended and force-pushed safely.

> *"I forgot to include a small change in my last commit and already pushed it."*
- Run option 11, choose option 2 (stage changes), say Y to stage all — the change is folded into the commit and force-pushed.

**Important:** Rewrites history. `--force-with-lease` aborts if the remote changed since your last fetch — run `git fetch` and try again if you get a push failure.

---

### [12] Multi-Pick Squash — N commits from anywhere, squashed into one

**What it does:**
Picks 2–10 commits from anywhere in the repo (any branch, any order) and squashes them into a single commit on a new or existing branch. Unlike Range Pick (Option 2), the commits don't need to be in a contiguous range or even on the same branch.

**Steps it walks you through:**
1. How many commits (2–10), then each commit hash (validated against the repo) — entered in the order they'll be applied
2. Target branch: create a NEW branch (from any base branch/commit) or use an EXISTING branch
3. Combined commit message

**Under the hood:**
```
git checkout -b <new-branch> <base>     (or git checkout <existing-branch>)
git cherry-pick --no-commit <hash-1>
git cherry-pick --no-commit <hash-2>
...
git commit -m "<combined message>"
```

**If a merge conflict happens mid-pick**, you're asked how to proceed:
1. **Stage everything as-is** — `git add -A` + `git cherry-pick --quit`, then continues to the next commit (review the result before the final commit!)
2. **Cancel** — aborts the pick, resets any already-staged changes, and (for a new branch) deletes the branch and returns you to where you started

Any *non-conflict* failure (e.g. an already-applied/empty commit) always rolls back automatically — no half-finished state.

**Sample problems it solves:**

> *"I have 3 related commits scattered across `feature/payments`, `feature/billing`, and `hotfix/patient-api` — I want them combined into one clean commit on a new branch for review."*
- Run option 12, create new branch `dhahari-All-patient-Apis` based on `main`, enter the 3 hashes in order, give it one message — done.

> *"I started Range Pick (Option 2) but my 3 commits aren't a contiguous range — they're on different branches."*
- Option 12 doesn't require a contiguous range; pick the exact commits you need regardless of where they live.

**Important:** Requires a clean working tree before starting. Cherry-picks are applied in the order you enter them — pick an order that minimizes conflicts (usually chronological).

---

## Tips

- Always run from inside your git repository folder, or use the full path (Option C above)
- Type **Q** at any prompt to cancel without making changes
- Option [4] Conflict Pre-Check is free — run it before any broadcast to avoid surprises
- Options [5], [6], [8], [9], and [11] rewrite history — only use them on commits that have not been pushed yet (or with caution on personal branches)
- Option [10] is always safe to browse — creating a branch from reflog never modifies your current branch
- Option [12] cherry-picks are non-destructive to source branches — only the target branch is affected
