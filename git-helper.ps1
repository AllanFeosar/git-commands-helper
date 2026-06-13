#Requires -Version 5.1
# Git Helper CLI  v3.0
# Windows 8/10/11 (PowerShell 5.1+)  |  Linux & macOS (PowerShell 7+ / pwsh)

# ─── Platform detection ───────────────────────────────────────────────────────

$script:OnWindows = -not ((Get-Variable 'IsLinux'  -Scope Global -ErrorAction SilentlyContinue) -and $IsLinux) `
                  -and -not ((Get-Variable 'IsMacOS' -Scope Global -ErrorAction SilentlyContinue) -and $IsMacOS)
$script:OnLinux   = (Get-Variable 'IsLinux'  -Scope Global -ErrorAction SilentlyContinue) -and $IsLinux
$script:OnMac     = (Get-Variable 'IsMacOS'  -Scope Global -ErrorAction SilentlyContinue) -and $IsMacOS

# UTF-8 so box-drawing characters render on all platforms
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding            = [System.Text.Encoding]::UTF8

# ─── Output helpers ───────────────────────────────────────────────────────────

function wh {
    param([string]$Text, [ConsoleColor]$Color = 'White', [switch]$NoNewline)
    if ($NoNewline) { Write-Host $Text -ForegroundColor $Color -NoNewline }
    else            { Write-Host $Text -ForegroundColor $Color }
}

function Sep { wh ("  " + ([string][char]0x2500) * 52) DarkGray }

function Show-Banner {
    Clear-Host
    wh ""
    wh "  ┌──────────────────────────────────────────────────┐" Cyan
    wh "  │                                                  │" Cyan
    wh "  │          G I T   H E L P E R   v3.0              │" Yellow
    wh "  │          Developer Workflow Toolkit              │" DarkCyan
    wh "  │                                                  │" Cyan
    wh "  └──────────────────────────────────────────────────┘" Cyan
    wh ""
}

# ─── Git helpers ──────────────────────────────────────────────────────────────

function Test-GitInstalled {
    $null = & git --version 2>&1
    return ($LASTEXITCODE -eq 0)
}

function Test-GitRepo {
    $null = & git rev-parse --is-inside-work-tree 2>&1
    return ($LASTEXITCODE -eq 0)
}

function Get-CurrentBranch {
    $b = & git branch --show-current 2>&1
    if ($LASTEXITCODE -eq 0 -and $b) { return [string]$b }
    return $null
}

function Invoke-Checkout([string]$Branch) {
    wh "  >> git checkout $Branch" DarkGray
    $out = & git checkout $Branch 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Failed to checkout '$Branch'" Red
        foreach ($l in $out) { wh "      $l" DarkRed }
        return $false
    }
    $null = & git symbolic-ref -q HEAD 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] '$Branch' is not a branch — checkout left the repo in detached HEAD" Red
        wh "      Returning to where you started..." DarkRed
        & git checkout - 2>&1 | Out-Null
        return $false
    }
    wh "  [OK] On branch: $Branch" Green
    return $true
}

function Confirm-Proceed {
    $go = Ask "Proceed? [Y/N]:"
    if ($go -notmatch '^[yY]$') { wh "  Cancelled." Yellow; Pause-Return; return $false }
    return $true
}

# Any ref (branch, tag, commit) with this name already exists
function Test-RefExists([string]$Name) {
    $null = & git rev-parse --verify $Name 2>&1
    return ($LASTEXITCODE -eq 0)
}

# A local BRANCH (not a tag/detached commit) with this name exists
function Test-LocalBranchExists([string]$Name) {
    & git show-ref --verify --quiet "refs/heads/$Name" 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# Number of commits HEAD is ahead of its upstream, or $null if no upstream configured
function Get-AheadOfUpstreamCount {
    $null = & git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return [int][string](& git rev-list --count "@{u}..HEAD" 2>$null)
}

# ─── Input / UI helpers ───────────────────────────────────────────────────────

function Ask([string]$Prompt) {
    wh "  > " Cyan -NoNewline
    wh "$Prompt " Yellow -NoNewline
    return (Read-Host)
}

function Pause-Return {
    wh ""
    wh "  Press any key to return to menu..." DarkGray
    try   { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    catch { $null = Read-Host }
}

function Is-Quit([string]$s)  { return ($s -ceq 'q' -or $s -ceq 'Q') }
function Test-Hash([string]$h) { return ($h -match '^[0-9a-fA-F]{7,40}$') }

function Clip([string]$s, [int]$max = 35) {
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' }
    return $s
}

function Draw-Box {
    param([string[]]$Rows, [ConsoleColor]$Color = 'Cyan')
    $maxLen = ($Rows | Where-Object { $_ } | Measure-Object -Property Length -Maximum).Maximum
    if (-not $maxLen) { $maxLen = 38 }
    $inner = [Math]::Max([int]$maxLen, 38)
    $hr = [string][char]0x2500
    $tl = [string][char]0x250C ; $tr = [string][char]0x2510
    $bl = [string][char]0x2514 ; $br = [string][char]0x2518
    $vb = [string][char]0x2502
    wh ("  $tl" + ($hr * ($inner + 4)) + "$tr") $Color
    foreach ($r in $Rows) {
        $padded = ([string]$r).PadRight($inner)
        wh "  $vb  $padded  $vb" $Color
    }
    wh ("  $bl" + ($hr * ($inner + 4)) + "$br") $Color
}

# Cross-platform no-op editor for non-interactive rebase
function Get-NoopEditor {
    $tmp = [System.IO.Path]::GetTempPath()
    if ($script:OnWindows) {
        $f = Join-Path $tmp "git-noop-editor.bat"
        "@echo off" | Out-File -FilePath $f -Encoding ascii -Force
    } else {
        $f = Join-Path $tmp "git-noop-editor.sh"
        "#!/bin/sh`nexit 0" | Out-File -FilePath $f -Encoding ascii -Force
        & chmod +x $f 2>&1 | Out-Null
    }
    return $f
}

# ─────────────────────────────────────────────────────────────────────────────
# [1]  Cherry Pick  ─  Single commit, NEW or OLD diff
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-CherryPick {
    Show-Banner
    wh "  [ 1 ]  Cherry Pick  ─  Single commit" Yellow
    Sep ; wh ""
    wh "  Apply or reverse one specific commit onto any branch." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    wh "  STEP 1 / 4  ─  Commit to pick" DarkCyan ; wh ""
    $hash = ""
    while ($true) {
        $hash = Ask "Commit ID (7-40 hex chars):"
        if (Is-Quit $hash)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($hash))  { wh "  [!] Cannot be empty." Red; continue }
        if (-not (Test-Hash $hash))               { wh "  [!] Invalid git hash." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 2 / 4  ─  Which diff to apply?" DarkCyan ; wh ""
    wh "    [1]  NEW diff  --  Apply what the commit introduced   (cherry-pick)" White
    wh "    [2]  OLD diff  --  Reverse / undo what the commit did (revert)" White
    wh ""
    $mode = ""
    while ($true) {
        $s = Ask "Select [1 or 2]:"
        if (Is-Quit $s) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($s -eq '1') { $mode = 'NEW'; break }
        if ($s -eq '2') { $mode = 'OLD'; break }
        wh "  [!] Enter 1 or 2." Red
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 3 / 4  ─  Target branch" DarkCyan ; wh ""
    $branch = ""
    while ($true) {
        $branch = Ask "Branch to apply onto:"
        if (Is-Quit $branch)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($branch))  { wh "  [!] Cannot be empty." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 4 / 4  ─  Commit message" DarkCyan ; wh ""
    $msg = ""
    while ($true) {
        $msg = Ask "New commit message:"
        if (Is-Quit $msg)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($msg))  { wh "  [!] Cannot be empty." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  CONFIRM" DarkCyan ; wh ""
    $modeLabel = if ($mode -eq 'NEW') { "NEW diff  (cherry-pick)" } else { "OLD diff  (revert)" }
    Draw-Box @(
        "Commit to pick  : $(Clip $hash)",
        "Mode            : $modeLabel",
        "Target branch   : $(Clip $branch)",
        "Commit message  : $(Clip $msg)"
    )
    wh ""
    if (-not (Confirm-Proceed)) { return }
    wh "" ; Sep ; wh ""
    wh "  Executing..." DarkCyan ; wh ""

    if (-not (Invoke-Checkout $branch)) { Pause-Return; return }
    wh ""

    if ($mode -eq 'NEW') {
        wh "  >> git cherry-pick --no-commit $hash" DarkGray
        $out = & git cherry-pick --no-commit $hash 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Cherry-pick failed — aborting" Red
            foreach ($l in $out) { wh "      $l" DarkRed }
            & git cherry-pick --abort 2>&1 | Out-Null
            Pause-Return; return
        }
    } else {
        wh "  >> git revert --no-commit $hash" DarkGray
        $out = & git revert --no-commit $hash 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Revert failed — resetting" Red
            foreach ($l in $out) { wh "      $l" DarkRed }
            & git reset --hard HEAD 2>&1 | Out-Null
            Pause-Return; return
        }
    }
    wh "  [OK] Changes staged" Green ; wh ""
    wh "  >> git commit -m `"$msg`"" DarkGray
    $out = & git commit -m $msg 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Commit failed" Red
        foreach ($l in $out) { wh "      $l" DarkRed }
        Pause-Return; return
    }
    wh "  [OK] Committed" Green ; wh ""
    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Cherry Pick completed!           │" Green
    wh "  └──────────────────────────────────────────┘" Green
    wh "" ; (& git log --oneline -1 2>&1) | ForEach-Object { wh "  $_" Green }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [2]  Range Pick  ─  Commit range A through B, squash option
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-RangePick {
    Show-Banner
    wh "  [ 2 ]  Range Pick  ─  Commit range A through B" Yellow
    Sep ; wh ""
    wh "  git A..B silently EXCLUDES A. This tool uses A^..B (always inclusive)." DarkGray
    wh "  Optional: squash the whole range into one clean commit." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    wh "  STEP 1 / 5  ─  Range START  (oldest commit to include)" DarkCyan ; wh ""
    $startHash = ""
    while ($true) {
        $startHash = Ask "Start commit hash:"
        if (Is-Quit $startHash)                       { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($startHash)) { wh "  [!] Cannot be empty." Red; continue }
        if (-not (Test-Hash $startHash))              { wh "  [!] Invalid hash." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 2 / 5  ─  Range END  (newest commit to include)" DarkCyan ; wh ""
    $endHash = ""
    while ($true) {
        $endHash = Ask "End commit hash:"
        if (Is-Quit $endHash)                       { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($endHash)) { wh "  [!] Cannot be empty." Red; continue }
        if (-not (Test-Hash $endHash))              { wh "  [!] Invalid hash." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 3 / 5  ─  Commit mode" DarkCyan ; wh ""
    wh "    [1]  Keep individual commits  (original messages preserved)" White
    wh "    [2]  Squash into ONE commit   (you provide the message)" White
    wh ""
    $squash = $false ; $squashMsg = ""
    while ($true) {
        $s = Ask "Select [1 or 2]:"
        if (Is-Quit $s) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($s -eq '1') { break }
        if ($s -eq '2') {
            $squash = $true
            wh ""
            while ($true) {
                $squashMsg = Ask "Combined commit message:"
                if (Is-Quit $squashMsg)                       { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
                if ([string]::IsNullOrWhiteSpace($squashMsg)) { wh "  [!] Cannot be empty." Red; continue }
                break
            }
            break
        }
        wh "  [!] Enter 1 or 2." Red
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 4 / 5  ─  Target branch" DarkCyan ; wh ""
    $branch = ""
    while ($true) {
        $branch = Ask "Target branch:"
        if (Is-Quit $branch)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($branch))  { wh "  [!] Cannot be empty." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 5 / 5  ─  Confirm" DarkCyan ; wh ""
    $modeStr = if ($squash) { "Squash into 1 commit" } else { "Keep individual commits" }
    $rows = [System.Collections.Generic.List[string]]::new()
    $rows.Add("Range start     : $(Clip $startHash)")
    $rows.Add("Range end       : $(Clip $endHash)")
    $rows.Add("Mode            : $modeStr")
    if ($squash) { $rows.Add("New message     : $(Clip $squashMsg)") }
    $rows.Add("Target branch   : $(Clip $branch)")
    Draw-Box $rows.ToArray()
    wh ""
    if (-not (Confirm-Proceed)) { return }
    wh "" ; Sep ; wh ""
    wh "  Executing..." DarkCyan ; wh ""
    if (-not (Invoke-Checkout $branch)) { Pause-Return; return }
    wh ""

    $parentTest = & git rev-parse "$startHash^" 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] '$startHash' appears to be the root commit (has no parent)." Red
        wh "  Range pick cannot start from the root commit — choose the next commit instead." DarkGray
        Pause-Return; return
    }
    & git merge-base --is-ancestor $startHash $endHash 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] '$startHash' is not an ancestor of '$endHash' — this range would not make sense." Red
        wh "  Make sure both hashes are on the same line of history, with start before end." DarkGray
        Pause-Return; return
    }
    $range = "$startHash^..$endHash"
    if ($squash) {
        wh "  >> git cherry-pick --no-commit $range" DarkGray
        $out = & git cherry-pick --no-commit $range 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Range pick failed — aborting" Red
            foreach ($l in $out) { wh "      $l" DarkRed }
            & git cherry-pick --abort 2>&1 | Out-Null
            Pause-Return; return
        }
        wh "  [OK] All changes staged" Green ; wh ""
        wh "  >> git commit -m `"$squashMsg`"" DarkGray
        $out = & git commit -m $squashMsg 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Commit failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
            Pause-Return; return
        }
    } else {
        wh "  >> git cherry-pick $range" DarkGray
        $out = & git cherry-pick $range 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Range pick failed — aborting" Red
            foreach ($l in $out) { wh "      $l" DarkRed }
            & git cherry-pick --abort 2>&1 | Out-Null
            Pause-Return; return
        }
    }
    wh "  [OK] Range applied!" Green ; wh ""
    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Range Pick completed!            │" Green
    wh "  └──────────────────────────────────────────┘" Green
    wh "" ; (& git log --oneline -3 2>&1) | ForEach-Object { wh "    $_" Green }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [3]  Hotfix Broadcast  ─  One commit applied to N branches atomically
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-HotfixBroadcast {
    Show-Banner
    wh "  [ 3 ]  Hotfix Broadcast  ─  One commit, many branches" Yellow
    Sep ; wh ""
    wh "  Applies a hotfix to multiple release branches at once." DarkGray
    wh "  Uses -x to embed source hash in each commit for audit trail." DarkGray
    wh "  Type Q to cancel." DarkGray ; wh ""

    wh "  STEP 1 / 3  ─  Commit to broadcast" DarkCyan ; wh ""
    $hash = ""
    while ($true) {
        $hash = Ask "Commit hash:"
        if (Is-Quit $hash)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($hash))  { wh "  [!] Cannot be empty." Red; continue }
        if (-not (Test-Hash $hash))               { wh "  [!] Invalid hash." Red; continue }
        break
    }
    $info = & git log --oneline -1 $hash 2>&1
    if ($LASTEXITCODE -eq 0) { wh "  Commit: $info" DarkGray }
    wh "" ; Sep ; wh ""

    wh "  STEP 2 / 3  ─  Target branches" DarkCyan
    wh "  Enter one branch per line. Blank line = done." DarkGray ; wh ""
    $branches = [System.Collections.Generic.List[string]]::new()
    while ($true) {
        $b = Ask "Branch (blank = done):"
        if (Is-Quit $b) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($b)) {
            if ($branches.Count -eq 0) { wh "  [!] Add at least one branch." Red; continue }
            break
        }
        $branches.Add($b) ; wh "  [+] $b" DarkGreen
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 3 / 3  ─  Options & Confirm" DarkCyan ; wh ""
    $pa = Ask "Push each branch to remote after picking? [Y/N]:"
    $push = ($pa -match '^[yY]$')
    wh ""
    Draw-Box @(
        "Commit          : $(Clip $hash)",
        "Target branches : $(Clip ($branches -join ', ') 40)",
        "Push after each : $(if ($push) { 'Yes' } else { 'No' })"
    )
    wh ""
    if (-not (Confirm-Proceed)) { return }
    wh "" ; Sep ; wh ""

    $orig    = Get-CurrentBranch
    $results = [System.Collections.Generic.List[string]]::new()
    $dirty = & git status --porcelain 2>&1
    $didBcStash = $false
    if ($dirty) {
        wh "  Stashing uncommitted changes before switching branches..." DarkGray
        & git stash push -m "git-helper-broadcast" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $didBcStash = $true ; wh "  [OK] Changes stashed" Green ; wh "" }
        else { wh "  [!] Could not stash — proceeding (some checkouts may fail)" Yellow ; wh "" }
    }
    foreach ($b in $branches) {
        wh "  ─── Branch: $b ───" DarkCyan
        $out = & git checkout $b 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Checkout failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
            $results.Add("FAIL  | $b  (checkout failed)") ; wh "" ; continue
        }
        $out = & git cherry-pick -x $hash 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Conflict — aborting this branch" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
            & git cherry-pick --abort 2>&1 | Out-Null
            $results.Add("FAIL  | $b  (conflict)") ; wh "" ; continue
        }
        wh "  [OK] Applied" Green
        if ($push) {
            $out = & git push 2>&1
            if ($LASTEXITCODE -ne 0) { wh "  [!] Push failed" Yellow ; $results.Add("WARN  | $b  (applied, push failed)") }
            else                     { wh "  [OK] Pushed" Green      ; $results.Add("OK    | $b  (applied + pushed)") }
        } else { $results.Add("OK    | $b  (applied)") }
        wh ""
    }
    $returnedToOrig = $true
    if ($orig) {
        $co = & git checkout $orig 2>&1
        if ($LASTEXITCODE -eq 0) { wh "  Returned to: $orig" DarkGray }
        else {
            $returnedToOrig = $false
            wh "  [!] Could not return to '$orig' — you are on the last processed branch" Yellow
        }
        wh ""
    }
    if ($didBcStash) {
        if ($returnedToOrig) {
            $out = & git stash pop 2>&1
            if ($LASTEXITCODE -eq 0) { wh "  [OK] Stash restored" DarkGray }
            else {
                wh "  [!] Could not restore stash automatically — run 'git stash pop' manually" Yellow
                foreach ($l in $out) { wh "      $l" DarkRed }
            }
        } else {
            wh "  [!] Skipped restoring stash — switch to '$orig' and run 'git stash pop' manually" Yellow
        }
        wh ""
    }
    Sep ; wh "" ; wh "  BROADCAST RESULTS" DarkCyan ; wh ""
    foreach ($r in $results) {
        if   ($r.StartsWith("OK"))   { wh "    $r" Green  }
        elseif ($r.StartsWith("WARN")) { wh "    $r" Yellow }
        else                         { wh "    $r" Red    }
    }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [4]  Conflict Pre-Check  ─  Dry-run preview
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-ConflictPreCheck {
    Show-Banner
    wh "  [ 4 ]  Conflict Pre-Check  ─  Dry-run preview" Yellow
    Sep ; wh ""
    wh "  Checks whether a cherry-pick WOULD conflict before you commit." DarkGray
    wh "  Always aborts cleanly — zero permanent changes." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    $origBranch = Get-CurrentBranch
    $origSha    = if (-not $origBranch) { [string](& git rev-parse HEAD 2>&1) } else { $null }
    wh "  STEP 1 / 2  ─  Commit to test" DarkCyan ; wh ""
    $hash = ""
    while ($true) {
        $hash = Ask "Commit hash:"
        if (Is-Quit $hash)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($hash))  { wh "  [!] Cannot be empty." Red; continue }
        if (-not (Test-Hash $hash))               { wh "  [!] Invalid hash." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 2 / 2  ─  Target branch to test against" DarkCyan ; wh ""
    $branch = ""
    while ($true) {
        $branch = Ask "Target branch:"
        if (Is-Quit $branch)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($branch))  { wh "  [!] Cannot be empty." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""
    wh "  Running pre-check (no permanent changes)..." DarkCyan ; wh ""

    $dirty = & git status --porcelain 2>&1
    $didStash = $false
    if ($dirty) {
        wh "  Stashing uncommitted changes temporarily..." DarkGray
        & git stash push -m "git-helper-precheck" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $didStash = $true }
    }
    $out = & git checkout $branch 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Cannot checkout '$branch'" Red
        if ($didStash) { & git stash pop 2>&1 | Out-Null }
        Pause-Return; return
    }
    $pickOut  = & git cherry-pick --no-commit $hash 2>&1
    $pickExit = $LASTEXITCODE
    if ($pickExit -ne 0) { & git cherry-pick --abort 2>&1 | Out-Null }
    else                 { & git reset --hard HEAD 2>&1 | Out-Null }
    $co = $null
    if ($origBranch)   { $co = & git checkout $origBranch 2>&1 }
    elseif ($origSha)  { $co = & git checkout $origSha    2>&1 }
    $returnedOk = ($null -eq $co -or $LASTEXITCODE -eq 0)
    if (-not $returnedOk) {
        wh "  [!] Could not return to your original position automatically" Yellow
        foreach ($l in $co) { wh "      $l" DarkRed }
    }
    if ($didStash) {
        if ($returnedOk) {
            $out = & git stash pop 2>&1
            if ($LASTEXITCODE -ne 0) {
                wh "  [!] Could not restore stash automatically — run 'git stash pop' manually" Yellow
                foreach ($l in $out) { wh "      $l" DarkRed }
            }
        } else {
            wh "  [!] Skipped restoring stash — return to your original branch and run 'git stash pop' manually" Yellow
        }
    }

    Sep ; wh ""
    if ($pickExit -eq 0) {
        wh "  ┌──────────────────────────────────────────┐" Green
        wh "  │   [OK]  CLEAN  —  No conflicts detected  │" Green
        wh "  │   Cherry-pick would apply safely.        │" Green
        wh "  └──────────────────────────────────────────┘" Green
    } else {
        wh "  ┌──────────────────────────────────────────┐" Red
        wh "  │   [!]   CONFLICTS DETECTED               │" Red
        wh "  └──────────────────────────────────────────┘" Red
        wh "" ; wh "  Conflict details:" Yellow
        foreach ($l in $pickOut) {
            if ($l -match 'CONFLICT|conflict|error') { wh "    $l" Yellow }
        }
    }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [5]  Wrong Branch Rescue  ─  Move latest commit to correct branch
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-WrongBranchRescue {
    Show-Banner
    wh "  [ 5 ]  Wrong Branch Rescue  ─  Move latest commit" Yellow
    Sep ; wh ""
    wh "  Moves your most recent commit to a different branch." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    $origBranch = Get-CurrentBranch
    if (-not $origBranch) { wh "  [X] Cannot determine current branch." Red; Pause-Return; return }

    wh "  Current branch  : $origBranch" DarkCyan ; wh ""
    wh "  Last 5 commits:" DarkGray
    (& git log --oneline -5 2>&1) | ForEach-Object { wh "    $_" White }
    wh ""

    $latestHash    = [string](& git log --format="%H" -1 2>&1)
    $latestOneline = [string](& git log --oneline -1 2>&1)
    wh "  Commit to move  : $latestOneline" Cyan ; wh ""

    wh "  Where should it go?" DarkCyan ; wh ""
    $target = ""
    while ($true) {
        $target = Ask "Destination branch:"
        if (Is-Quit $target)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($target))  { wh "  [!] Cannot be empty." Red; continue }
        if ($target -eq $origBranch)                { wh "  [!] Same as current branch." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""
    Draw-Box @(
        "Commit to move  : $(Clip $latestOneline)",
        "From branch     : $origBranch",
        "To branch       : $target"
    )
    wh "" ; wh "  WARNING: Rewrites history on '$origBranch'. Only safe if NOT pushed." Yellow ; wh ""
    $ahead = Get-AheadOfUpstreamCount
    if ($null -ne $ahead -and $ahead -eq 0) {
        Draw-Box @(
            "DANGER: '$origBranch' is up to date with its remote.",
            "This commit may already be pushed/shared."
        ) Red
        wh ""
        $conf = Ask "Type FORCE to confirm rewriting pushed history:"
        if ($conf -ne 'FORCE') { wh "  Cancelled." Yellow; Pause-Return; return }
    } else {
        if (-not (Confirm-Proceed)) { return }
    }
    wh "" ; Sep ; wh ""
    wh "  Executing..." DarkCyan ; wh ""

    if (-not (Invoke-Checkout $target)) { Pause-Return; return }
    wh "  >> git cherry-pick $latestHash" DarkGray
    $out = & git cherry-pick $latestHash 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Cherry-pick failed — aborting" Red
        foreach ($l in $out) { wh "      $l" DarkRed }
        & git cherry-pick --abort 2>&1 | Out-Null
        $co = & git checkout $origBranch 2>&1
        if ($LASTEXITCODE -eq 0) { wh "  '$origBranch' is UNCHANGED" DarkGray }
        else { wh "  [!] Also failed to return to '$origBranch'" Yellow ; foreach ($l in $co) { wh "      $l" DarkRed } }
        Pause-Return; return
    }
    wh "  [OK] Applied to '$target'" Green ; wh ""
    $co = & git checkout $origBranch 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Could not return to '$origBranch' — reset cancelled to protect '$target'" Red
        foreach ($l in $co) { wh "      $l" DarkRed }
        Pause-Return; return
    }
    wh "  >> git reset --hard HEAD~1  (on '$origBranch')" DarkGray
    $out = & git reset --hard HEAD~1 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Reset failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
        Pause-Return; return
    }
    wh "  [OK] Commit removed from '$origBranch'" Green ; wh ""
    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Rescue completed!                │" Green
    wh "  └──────────────────────────────────────────┘" Green
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [6]  Undo Last Cherry-Pick  ─  Smart reset or revert
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-UndoLastPick {
    Show-Banner
    wh "  [ 6 ]  Undo Last Cherry-Pick  ─  Safe rollback" Yellow
    Sep ; wh ""
    wh "  Not pushed  =>  git reset --hard ORIG_HEAD  (removes commit)" DarkGray
    wh "  Pushed      =>  git revert HEAD             (adds undo commit)" DarkGray ; wh ""

    $branch   = Get-CurrentBranch
    $lastLine = [string](& git log --oneline -1 2>&1)
    wh "  Branch         : $branch" DarkCyan
    wh "  Last commit    : $lastLine" White ; wh ""

    $origHead      = & git rev-parse ORIG_HEAD 2>&1
    $hasOrigHead   = ($LASTEXITCODE -eq 0)
    $lastReflogMsg = [string](& git reflog -1 --format="%gs" 2>&1)
    $origHeadIsLastPick = ($hasOrigHead -and $lastReflogMsg -match '^cherry-pick:')
    $trackRef    = & git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>&1
    $hasUpstream = ($LASTEXITCODE -eq 0)
    if ($hasUpstream) {
        $aheadCount = [int][string](& git rev-list --count "@{u}..HEAD" 2>$null)
        $notPushed  = ($aheadCount -gt 0)
        $statusInfo = if ($notPushed) { "$aheadCount commit(s) ahead of remote" } else { "up to date with remote" }
    } else {
        $notPushed  = $true
        $statusInfo = "no upstream configured (treating as unpushed)"
    }

    wh "  Remote status  : $statusInfo" DarkGray ; wh ""

    $useReset = ($notPushed -and $origHeadIsLastPick)
    if ($useReset) {
        wh "  Strategy: RESET  (not yet pushed)" Green ; wh ""
        Draw-Box @("Command : git reset --hard ORIG_HEAD","Effect  : Completely removes the cherry-pick commit","Safe    : Yes — was never on the remote") Green
    } else {
        wh "  Strategy: REVERT  (may be on remote)" Yellow ; wh ""
        if ($hasOrigHead -and -not $origHeadIsLastPick) {
            wh "  Note: ORIG_HEAD does not correspond to the last cherry-pick — using revert for safety." DarkGray ; wh ""
        }
        Draw-Box @("Command : git revert HEAD --no-edit","Effect  : New commit that undoes the cherry-pick","Safe    : Yes — no history rewrite") Yellow
    }
    wh ""
    if (-not (Confirm-Proceed)) { return }
    wh "" ; Sep ; wh ""
    wh "  Executing..." DarkCyan ; wh ""

    if ($useReset) {
        wh "  >> git reset --hard ORIG_HEAD" DarkGray
        $out = & git reset --hard ORIG_HEAD 2>&1
        if ($LASTEXITCODE -ne 0) { wh "  [X] Reset failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed } ; Pause-Return; return }
        wh "  [OK] Undone via reset" Green
    } else {
        wh "  >> git revert HEAD --no-edit" DarkGray
        $out = & git revert HEAD --no-edit 2>&1
        if ($LASTEXITCODE -ne 0) { wh "  [X] Revert failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed } ; Pause-Return; return }
        wh "  [OK] Undone via revert" Green
    }
    wh "" ; (& git log --oneline -3 2>&1) | ForEach-Object { wh "    $_" White }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [7]  Clean Merged Branches
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-CleanMergedBranches {
    Show-Banner
    wh "  [ 7 ]  Clean Merged Branches  ─  Remove dead local branches" Yellow
    Sep ; wh ""
    wh "  Deletes every local branch already merged into a base branch." DarkGray
    wh "  Protected branches are never touched. Type Q to cancel." DarkGray ; wh ""

    wh "  Base branch to check against:" DarkCyan ; wh ""
    $base = ""
    while ($true) {
        $base = Ask "Base branch [default: main]:"
        if (Is-Quit $base) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($base)) { $base = "main" }
        break
    }
    wh "" ; wh "  Scanning..." DarkGray
    $mergedOut = & git branch --merged $base 2>&1
    if ($LASTEXITCODE -ne 0) { wh "  [X] Failed — is '$base' a valid branch?" Red; Pause-Return; return }

    $current   = Get-CurrentBranch
    $protected = @("main","master","develop",$base,$current)
    $toDelete  = $mergedOut | ForEach-Object { $_.Trim().TrimStart("* ") } |
                 Where-Object { $_ -ne "" -and $_ -notin $protected }

    if (-not $toDelete -or @($toDelete).Count -eq 0) {
        wh "" ; wh "  [OK] Nothing to clean up." Green ; Pause-Return; return
    }
    $count = @($toDelete).Count
    wh "" ; wh "  Branches to delete ($count):" Yellow
    foreach ($b in $toDelete) { wh "    - $b" White }
    wh ""
    $go = Ask "Delete all $count branch(es)? [Y/N]:"
    if ($go -notmatch '^[yY]$') { wh "  Cancelled." Yellow; Pause-Return; return }
    wh "" ; Sep ; wh ""

    $ok = 0 ; $fail = 0
    foreach ($b in $toDelete) {
        $out = & git branch -d $b 2>&1
        if ($LASTEXITCODE -eq 0) { wh "  [OK] Deleted: $b" Green ; $ok++ }
        else                     { wh "  [X] Failed:  $b — $out" Red ; $fail++ }
    }
    wh "" ; $c = if ($fail -eq 0) { 'Green' } else { 'Yellow' }
    wh "  Done  —  Deleted: $ok   Failed: $fail" $c
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [8]  Commit Fixup  ─  Fix an older commit via autosquash
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-CommitFixup {
    Show-Banner
    wh "  [ 8 ]  Commit Fixup  ─  Amend an older commit via autosquash" Yellow
    Sep ; wh ""
    wh "  Creates a --fixup commit for any past commit, then rebases with" DarkGray
    wh "  --autosquash to cleanly merge it in." DarkGray
    wh "  WARNING: Rewrites history — avoid on pushed commits." Red
    wh "  Type Q to cancel." DarkGray ; wh ""

    $dirty = & git status --porcelain 2>&1
    if (-not $dirty) { wh "  [!] No uncommitted changes found. Stage your fix first." Yellow; Pause-Return; return }
    wh "  Uncommitted changes:" DarkGray ; foreach ($s in $dirty) { wh "    $s" White } ; wh ""

    wh "  Recent commits:" DarkCyan
    (& git log --oneline -15 2>&1) | ForEach-Object { wh "    $_" White } ; wh ""

    wh "  Which commit should these changes fix?" DarkCyan ; wh ""
    $target = ""
    while ($true) {
        $target = Ask "Target commit hash:"
        if (Is-Quit $target)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($target))  { wh "  [!] Cannot be empty." Red; continue }
        if (-not (Test-Hash $target))               { wh "  [!] Invalid hash." Red; continue }
        $null = & git cat-file -t $target 2>&1
        if ($LASTEXITCODE -ne 0)                    { wh "  [!] Commit not found." Red; continue }
        if (-not (Test-RefExists "$target^"))       { wh "  [!] '$target' is the root commit (no parent) — cannot autosquash into it." Red; continue }
        break
    }
    wh "" ; wh "  Stage mode:" DarkCyan
    wh "    [1]  Stage ALL changes  (git add -A)" White
    wh "    [2]  Use what is already staged" White ; wh ""
    $stageMode = ""
    while ($true) {
        $s = Ask "Select [1 or 2]:"
        if (Is-Quit $s) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($s -eq '1' -or $s -eq '2') { $stageMode = $s; break }
        wh "  [!] Enter 1 or 2." Red
    }
    wh "" ; Sep ; wh ""
    $tLine = [string](& git log --oneline -1 $target 2>&1)
    Draw-Box @("Fixing commit   : $(Clip $tLine)","Stage mode      : $(if ($stageMode -eq '1') { 'Stage all' } else { 'Use existing index' })")
    wh ""
    if (-not (Confirm-Proceed)) { return }
    wh "" ; Sep ; wh ""
    wh "  Executing fixup..." DarkCyan ; wh ""

    if ($stageMode -eq '1') {
        wh "  >> git add -A" DarkGray
        & git add -A 2>&1 | Out-Null ; wh "  [OK] All changes staged" Green ; wh ""
    } else {
        $staged = @(& git diff --cached --name-only 2>&1)
        if ($staged.Count -eq 0) {
            wh "  [!] Nothing is staged. Run 'git add <files>' first, then retry." Yellow
            Pause-Return; return
        }
    }
    wh "  >> git commit --fixup=$target" DarkGray
    $out = & git commit --fixup=$target 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Fixup commit failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
        Pause-Return; return
    }
    wh "  [OK] Fixup commit created" Green ; wh ""

    $noopEditor = Get-NoopEditor
    $env:GIT_SEQUENCE_EDITOR = $noopEditor
    wh "  >> git rebase -i --autosquash $target^  (non-interactive)" DarkGray
    $out = & git rebase -i --autosquash "$target^" 2>&1
    $rbExit = $LASTEXITCODE
    $env:GIT_SEQUENCE_EDITOR = $null
    Remove-Item $noopEditor -Force -ErrorAction SilentlyContinue

    if ($rbExit -ne 0) {
        wh "  [X] Rebase failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
        wh "  Run 'git rebase --abort' if rebase is still in progress." Yellow
        Pause-Return; return
    }
    wh "  [OK] Fixup squashed into target commit" Green ; wh ""
    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Fixup completed!                 │" Green
    wh "  └──────────────────────────────────────────┘" Green
    wh "" ; (& git log --oneline -5 2>&1) | ForEach-Object { wh "    $_" Green }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [9]  Multi-Commit Rescue  ─  Move N commits from wrong branch to new branch
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-MultiCommitRescue {
    Show-Banner
    wh "  [ 9 ]  Multi-Commit Rescue  ─  Move N commits to a new branch" Yellow
    Sep ; wh ""
    wh "  You made multiple commits on the wrong branch. This creates a new" DarkGray
    wh "  branch containing those commits, then resets the original back." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    $origBranch = Get-CurrentBranch
    if (-not $origBranch) { wh "  [X] Cannot determine current branch." Red; Pause-Return; return }

    wh "  Current branch  : $origBranch" DarkCyan ; wh ""
    wh "  Recent commits on this branch:" DarkGray
    $logLines = @(& git log --oneline -10 2>&1)
    for ($i = 0; $i -lt $logLines.Count; $i++) {
        wh "    [$($i+1)]  $($logLines[$i])" White
    }
    wh ""

    # How many commits to rescue
    $count = 0
    while ($true) {
        $n = Ask "How many commits to move to new branch? (1-10):"
        if (Is-Quit $n) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le 10) { $count = [int]$n; break }
        wh "  [!] Enter a number between 1 and 10." Red
    }
    if (-not (Test-RefExists "HEAD~$count")) {
        wh "" ; wh "  [X] '$origBranch' has fewer than $($count + 1) commit(s) — cannot move $count." Red
        Pause-Return; return
    }
    wh ""
    wh "  These $count commit(s) will be moved:" DarkGray
    for ($i = 0; $i -lt $count -and $i -lt $logLines.Count; $i++) {
        wh "    $($logLines[$i])" Cyan
    }
    wh ""

    # New branch name
    wh "  New branch to create for these commits:" DarkCyan ; wh ""
    $newBranch = ""
    while ($true) {
        $newBranch = Ask "New branch name:"
        if (Is-Quit $newBranch)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($newBranch))  { wh "  [!] Cannot be empty." Red; continue }
        if ($newBranch -eq $origBranch)                { wh "  [!] Same as current branch." Red; continue }
        # Check branch doesn't already exist
        if (Test-RefExists $newBranch) { wh "  [!] Branch '$newBranch' already exists. Choose a different name." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  CONFIRM" DarkCyan ; wh ""
    Draw-Box @(
        "Commits to move : $count",
        "From branch     : $origBranch",
        "New branch      : $newBranch"
    )
    wh ""
    wh "  Step 1: Create '$newBranch' at current HEAD (includes all $count commits)" DarkGray
    wh "  Step 2: Reset '$origBranch' back $count commit(s)" DarkGray
    wh ""
    wh "  WARNING: Rewrites history on '$origBranch'. Only safe if NOT pushed." Yellow ; wh ""
    $ahead = Get-AheadOfUpstreamCount
    if ($null -ne $ahead -and $ahead -lt $count) {
        Draw-Box @(
            "DANGER: only $ahead of these $count commit(s) are unpushed.",
            "Some may already be on the remote — rewriting affects shared history."
        ) Red
        wh ""
        $conf = Ask "Type FORCE to confirm rewriting pushed history:"
        if ($conf -ne 'FORCE') { wh "  Cancelled." Yellow; Pause-Return; return }
    } else {
        if (-not (Confirm-Proceed)) { return }
    }
    wh "" ; Sep ; wh ""
    wh "  Executing..." DarkCyan ; wh ""

    # Create new branch at current HEAD (no checkout needed)
    wh "  >> git branch $newBranch" DarkGray
    $out = & git branch $newBranch 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Failed to create '$newBranch'" Red
        foreach ($l in $out) { wh "      $l" DarkRed }
        Pause-Return; return
    }
    wh "  [OK] Branch '$newBranch' created at current HEAD" Green ; wh ""

    # Reset original back N commits
    wh "  >> git reset --hard HEAD~$count  (on '$origBranch')" DarkGray
    $out = & git reset --hard "HEAD~$count" 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Reset failed — rolling back (deleting '$newBranch')" Red
        foreach ($l in $out) { wh "      $l" DarkRed }
        & git branch -D $newBranch 2>&1 | Out-Null
        Pause-Return; return
    }
    wh "  [OK] '$origBranch' reset back $count commit(s)" Green ; wh ""

    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Multi-Commit Rescue completed!   │" Green
    wh "  └──────────────────────────────────────────┘" Green
    wh ""
    wh "  '$origBranch' is now clean." Green
    wh "  Your $count commit(s) are on '$newBranch'." Green
    wh ""
    wh "  Switch to it with:  git checkout $newBranch" DarkGray
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [10] Reflog Recovery Wizard  ─  Recover lost commits via reflog
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-ReflogRecovery {
    Show-Banner
    wh "  [ 10 ]  Reflog Recovery Wizard  ─  Recover lost commits" Yellow
    Sep ; wh ""
    wh "  Shows the last 15 repo states from the reflog. Pick any entry to" DarkGray
    wh "  either create a new branch there, or hard-reset your current branch." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    # Load reflog
    wh "  Loading reflog..." DarkGray
    $reflogRaw = & git reflog --format="%H|%gd|%gs" -15 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $reflogRaw) {
        wh "  [X] Could not read reflog." Red ; Pause-Return; return
    }
    $entries = @($reflogRaw | Where-Object { $_ -match '\|' })
    if ($entries.Count -eq 0) { wh "  [X] Reflog is empty." Red ; Pause-Return; return }

    wh ""
    wh "  #   Short Hash   Reflog Entry          Action" DarkCyan
    Sep
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $parts = $entries[$i] -split '\|', 3
        $sha   = if ($parts[0].Length -ge 7) { $parts[0].Substring(0,7) } else { $parts[0] }
        $ref   = $parts[1].PadRight(20)
        $msg   = if ($parts[2].Length -gt 35) { $parts[2].Substring(0,35) + '...' } else { $parts[2] }
        $num   = "[$($i+1)]".PadLeft(4)
        wh "  $num  $sha   $ref  $msg" White
    }
    Sep ; wh ""

    # Pick entry
    $pick = 0
    while ($true) {
        $n = Ask "Pick entry number (1-$($entries.Count)):"
        if (Is-Quit $n) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $entries.Count) { $pick = [int]$n; break }
        wh "  [!] Enter a number between 1 and $($entries.Count)." Red
    }
    $chosenParts = $entries[$pick - 1] -split '\|', 3
    $chosenSha   = $chosenParts[0]
    $chosenMsg   = $chosenParts[2]
    wh "" ; wh "  Selected: $chosenMsg" Cyan ; wh "  SHA     : $chosenSha" DarkGray ; wh ""

    # What to do
    wh "  What would you like to do?" DarkCyan ; wh ""
    wh "    [1]  Create a NEW branch at this SHA  (safe — no changes to current branch)" White
    wh "    [2]  Hard-reset current branch to this SHA  (destructive — rewrites history)" White
    wh ""
    $action = ""
    while ($true) {
        $s = Ask "Select [1 or 2]:"
        if (Is-Quit $s) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($s -eq '1' -or $s -eq '2') { $action = $s; break }
        wh "  [!] Enter 1 or 2." Red
    }

    if ($action -eq '1') {
        wh "" ; wh "  New branch name:" DarkCyan ; wh ""
        $newBranch = ""
        while ($true) {
            $newBranch = Ask "Branch name:"
            if (Is-Quit $newBranch)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
            if ([string]::IsNullOrWhiteSpace($newBranch))  { wh "  [!] Cannot be empty." Red; continue }
            if (Test-RefExists $newBranch) { wh "  [!] Branch '$newBranch' already exists. Choose a different name." Red; continue }
            break
        }
        wh "" ; Sep ; wh ""
        Draw-Box @("Action  : Create new branch","Branch  : $newBranch","At SHA  : $(Clip $chosenSha)")
        wh ""
        if (-not (Confirm-Proceed)) { return }
        wh "" ; wh "  >> git branch $newBranch $chosenSha" DarkGray
        $out = & git branch $newBranch $chosenSha 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Failed to create branch" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
            Pause-Return; return
        }
        wh "  [OK] Branch '$newBranch' created at $($chosenSha.Substring(0,7))" Green
        wh "" ; wh "  Switch to it with:  git checkout $newBranch" DarkGray
    } else {
        $curBranch = Get-CurrentBranch
        wh "" ; Sep ; wh ""
        Draw-Box @("Action  : Hard-reset current branch","Branch  : $curBranch","To SHA  : $(Clip $chosenSha)") Red
        wh "" ; wh "  WARNING: This rewrites history on '$curBranch'." Red
        wh "  Any commits after this SHA will be LOST unless on another branch." Red ; wh ""
        $ahead        = Get-AheadOfUpstreamCount
        $discardCount = [int][string](& git rev-list --count "$chosenSha..HEAD" 2>$null)
        if ($null -ne $ahead -and $discardCount -gt $ahead) {
            Draw-Box @(
                "DANGER: $($discardCount - $ahead) of the $discardCount commit(s) being",
                "discarded appear to already be pushed to the remote."
            ) Red
            wh ""
            $go = Ask "Type FORCE to confirm discarding pushed history:"
            if ($go -ne 'FORCE') { wh "  Cancelled." Yellow; Pause-Return; return }
        } else {
            $go = Ask "Type YES to confirm destructive reset:"
            if ($go -ne 'YES') { wh "  Cancelled." Yellow; Pause-Return; return }
        }
        wh "" ; wh "  >> git reset --hard $chosenSha" DarkGray
        $out = & git reset --hard $chosenSha 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Reset failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
            Pause-Return; return
        }
        wh "  [OK] Branch '$curBranch' reset to $($chosenSha.Substring(0,7))" Green
    }

    wh ""
    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Reflog Recovery completed!       │" Green
    wh "  └──────────────────────────────────────────┘" Green
    wh "" ; (& git log --oneline -3 2>&1) | ForEach-Object { wh "    $_" Green }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [11] Amend + Safe Force-Push  ─  Amend last commit with safety gate
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-AmendForcePush {
    Show-Banner
    wh "  [ 11 ]  Amend + Safe Force-Push" Yellow
    Sep ; wh ""
    wh "  Amends the last commit, checks if the remote branch is shared," DarkGray
    wh "  warns loudly if so, then pushes with --force-with-lease (safer" DarkGray
    wh "  than --force: aborts if someone else pushed since your last fetch)." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    $branch = Get-CurrentBranch
    $lastLine = [string](& git log --oneline -1 2>&1)
    wh "  Branch      : $branch" DarkCyan
    wh "  Last commit : $lastLine" White ; wh ""

    # Choose amend type
    wh "  Amend options:" DarkCyan ; wh ""
    wh "    [1]  Change message only" White
    wh "    [2]  Stage new changes + keep message" White
    wh "    [3]  Stage new changes + change message" White
    wh ""
    $amendType = ""
    while ($true) {
        $s = Ask "Select [1, 2 or 3]:"
        if (Is-Quit $s) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($s -eq '1' -or $s -eq '2' -or $s -eq '3') { $amendType = $s; break }
        wh "  [!] Enter 1, 2 or 3." Red
    }

    $newMsg = ""
    if ($amendType -eq '1' -or $amendType -eq '3') {
        wh ""
        while ($true) {
            $newMsg = Ask "New commit message:"
            if (Is-Quit $newMsg)                        { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
            if ([string]::IsNullOrWhiteSpace($newMsg))  { wh "  [!] Cannot be empty." Red; continue }
            break
        }
    }

    if ($amendType -eq '2' -or $amendType -eq '3') {
        $dirty = & git status --porcelain 2>&1
        if (-not $dirty) {
            wh "" ; wh "  [!] No uncommitted changes to stage." Yellow
            wh "  Switch to option 1 if you only want to change the message." DarkGray
            Pause-Return; return
        }
        wh "" ; wh "  Changes to stage:" DarkGray
        foreach ($s in $dirty) { wh "    $s" White }
        wh ""
        $stageAll = Ask "Stage all changes? [Y/N]:"
        if ($stageAll -match '^[yY]$') {
            & git add -A 2>&1 | Out-Null ; wh "  [OK] All changes staged" Green
        } else {
            $indexed = @(& git diff --cached --name-only 2>&1)
            if ($indexed.Count -eq 0) {
                wh "  [!] Nothing is staged. Stage changes first ('git add'), or pick option 1 to amend message only." Yellow
                Pause-Return; return
            }
            wh "  [OK] Using already-staged changes" DarkGray
        }
    }

    # Remote safety check
    wh "" ; wh "  Checking remote state..." DarkGray
    $tracking = & git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>&1
    $hasTracking = ($LASTEXITCODE -eq 0)

    $sharedWarning = $false
    if ($hasTracking) {
        $remoteAhead = @(& git log "HEAD..@{u}" --oneline 2>&1)
        if ($remoteAhead.Count -gt 0) {
            $sharedWarning = $true
            wh ""
            wh "  ╔══════════════════════════════════════════════════╗" Red
            wh "  ║  DANGER: Remote has $($remoteAhead.Count) commit(s) you don't have.   ║" Red
            wh "  ║  This branch may be shared with other developers. ║" Red
            wh "  ║  Force-pushing will overwrite their work.         ║" Red
            wh "  ╚══════════════════════════════════════════════════╝" Red
            wh ""
            wh "  Remote commits you would overwrite:" Yellow
            foreach ($l in $remoteAhead) { wh "    $l" Yellow }
        } else {
            wh "  [OK] Remote is behind — branch appears safe to force-push." Green
        }
    } else {
        wh "  [!] No tracking remote found — will push to origin/$branch" Yellow
    }

    wh "" ; Sep ; wh ""
    wh "  CONFIRM" DarkCyan ; wh ""
    $amendLabel = switch ($amendType) { '1' { 'Message only' } '2' { 'Stage + keep msg' } '3' { 'Stage + new msg' } }
    Draw-Box @(
        "Branch          : $branch",
        "Amend type      : $amendLabel",
        "Force strategy  : --force-with-lease (safe)"
    )
    wh ""
    if ($sharedWarning) {
        wh "  SHARED BRANCH WARNING — Type FORCE to confirm:" Red
        $conf = Ask "Confirmation:"
        if ($conf -ne 'FORCE') { wh "  Cancelled." Yellow; Pause-Return; return }
    } else {
        if (-not (Confirm-Proceed)) { return }
    }
    wh "" ; Sep ; wh ""
    wh "  Executing..." DarkCyan ; wh ""

    # Amend
    if ($amendType -eq '1') {
        wh "  >> git commit --amend -m `"$newMsg`"" DarkGray
        $out = & git commit --amend -m $newMsg 2>&1
    } elseif ($amendType -eq '2') {
        wh "  >> git commit --amend --no-edit" DarkGray
        $out = & git commit --amend --no-edit 2>&1
    } else {
        wh "  >> git commit --amend -m `"$newMsg`"" DarkGray
        $out = & git commit --amend -m $newMsg 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Amend failed" Red ; foreach ($l in $out) { wh "      $l" DarkRed }
        Pause-Return; return
    }
    wh "  [OK] Commit amended" Green ; wh ""

    # Force push
    if ($hasTracking) {
        wh "  >> git push --force-with-lease" DarkGray
        $out = & git push --force-with-lease 2>&1
    } else {
        wh "  >> git push --force-with-lease origin $branch" DarkGray
        $out = & git push --force-with-lease origin $branch 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Push failed" Red
        foreach ($l in $out) { wh "      $l" DarkRed }
        wh ""
        wh "  Tip: '--force-with-lease' aborts if the remote changed since your" DarkGray
        wh "  last fetch. Run 'git fetch' then try again." DarkGray
        Pause-Return; return
    }
    wh "  [OK] Force-pushed with --force-with-lease" Green ; wh ""
    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Amend + Force-Push completed!    │" Green
    wh "  └──────────────────────────────────────────┘" Green
    wh "" ; (& git log --oneline -1 2>&1) | ForEach-Object { wh "  $_" Green }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# [12] Multi-Pick Squash ─ Pick N commits from anywhere, squash into ONE commit
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-MultiPickSquash {
    Show-Banner
    wh "  [ 12 ]  Multi-Pick Squash  ─  N commits from anywhere -> ONE commit" Yellow
    Sep ; wh ""
    wh "  Pick several commits (from any branch, in any order) and squash" DarkGray
    wh "  them into a single commit on a new or existing branch." DarkGray
    wh "  Type Q at any prompt to cancel." DarkGray ; wh ""

    $origBranch = Get-CurrentBranch
    if (-not $origBranch) { wh "  [X] Cannot determine current branch." Red; Pause-Return; return }

    # Cherry-pick requires a clean working tree
    $dirty = & git status --porcelain 2>&1
    if ($dirty) {
        wh "  [X] Working tree is not clean. Commit, stash, or discard changes first." Red
        wh ""
        foreach ($l in $dirty) { wh "      $l" DarkRed }
        Pause-Return; return
    }

    wh "  STEP 1 / 3  ─  Commits to pick  (in the order they'll be applied)" DarkCyan ; wh ""
    $count = 0
    while ($true) {
        $n = Ask "How many commits to squash together? (2-10):"
        if (Is-Quit $n) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($n -match '^\d+$' -and [int]$n -ge 2 -and [int]$n -le 10) { $count = [int]$n; break }
        wh "  [!] Enter a number between 2 and 10." Red
    }
    wh ""

    $hashes = [System.Collections.Generic.List[string]]::new()
    for ($i = 1; $i -le $count; $i++) {
        while ($true) {
            $h = Ask "Commit $i of $count (hash):"
            if (Is-Quit $h) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
            if ([string]::IsNullOrWhiteSpace($h)) { wh "  [!] Cannot be empty." Red; continue }
            if (-not (Test-Hash $h))              { wh "  [!] Invalid git hash." Red; continue }
            if (-not (Test-RefExists "$h^{commit}")) { wh "  [!] Commit '$h' not found in this repo." Red; continue }
            $hashes.Add($h)
            break
        }
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 2 / 3  ─  Target branch" DarkCyan ; wh ""
    wh "    [1]  Create a NEW branch" White
    wh "    [2]  Use an EXISTING branch" White
    wh ""
    $createNew = $false
    while ($true) {
        $s = Ask "Select [1 or 2]:"
        if (Is-Quit $s) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ($s -eq '1') { $createNew = $true; break }
        if ($s -eq '2') { $createNew = $false; break }
        wh "  [!] Enter 1 or 2." Red
    }
    wh ""

    $targetBranch = "" ; $baseRef = ""
    if ($createNew) {
        while ($true) {
            $targetBranch = Ask "New branch name:"
            if (Is-Quit $targetBranch)                       { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
            if ([string]::IsNullOrWhiteSpace($targetBranch)) { wh "  [!] Cannot be empty." Red; continue }
            if (Test-RefExists $targetBranch) { wh "  [!] Branch '$targetBranch' already exists. Choose a different name." Red; continue }
            break
        }
        wh ""
        while ($true) {
            $baseRef = Ask "Base branch/commit for '$targetBranch' (blank = current '$origBranch'):"
            if (Is-Quit $baseRef) { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
            if ([string]::IsNullOrWhiteSpace($baseRef)) { $baseRef = $origBranch }
            if (-not (Test-RefExists $baseRef)) { wh "  [!] '$baseRef' is not a valid branch/commit." Red; continue }
            break
        }
    } else {
        while ($true) {
            $targetBranch = Ask "Existing branch name:"
            if (Is-Quit $targetBranch)                       { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
            if ([string]::IsNullOrWhiteSpace($targetBranch)) { wh "  [!] Cannot be empty." Red; continue }
            if (-not (Test-LocalBranchExists $targetBranch)) { wh "  [!] Branch '$targetBranch' does not exist." Red; continue }
            break
        }
    }
    wh "" ; Sep ; wh ""

    wh "  STEP 3 / 3  ─  Combined commit message" DarkCyan ; wh ""
    $msg = ""
    while ($true) {
        $msg = Ask "Commit message:"
        if (Is-Quit $msg)                       { wh "  Cancelled." DarkGray; Start-Sleep -Milliseconds 400; return }
        if ([string]::IsNullOrWhiteSpace($msg)) { wh "  [!] Cannot be empty." Red; continue }
        break
    }
    wh "" ; Sep ; wh ""

    wh "  CONFIRM" DarkCyan ; wh ""
    $rows = [System.Collections.Generic.List[string]]::new()
    $rows.Add("Commits (in apply order):")
    for ($i = 0; $i -lt $hashes.Count; $i++) {
        $summary = [string](& git log -1 "--format=%h %s" $hashes[$i] 2>&1)
        $rows.Add("  $($i+1). $(Clip $summary 50)")
    }
    if ($createNew) {
        $rows.Add("Target branch   : $targetBranch  (NEW, based on $baseRef)")
    } else {
        $rows.Add("Target branch   : $targetBranch  (existing)")
    }
    $rows.Add("New message     : $(Clip $msg)")
    Draw-Box $rows.ToArray()
    wh ""
    if (-not (Confirm-Proceed)) { return }
    wh "" ; Sep ; wh ""
    wh "  Executing..." DarkCyan ; wh ""

    # Step 1: get onto the target branch
    if ($createNew) {
        wh "  >> git checkout -b $targetBranch $baseRef" DarkGray
        $out = & git checkout -b $targetBranch $baseRef 2>&1
        if ($LASTEXITCODE -ne 0) {
            wh "  [X] Failed to create '$targetBranch'" Red
            foreach ($l in $out) { wh "      $l" DarkRed }
            Pause-Return; return
        }
        wh "  [OK] Created and switched to '$targetBranch'" Green ; wh ""
    } else {
        if (-not (Invoke-Checkout $targetBranch)) { Pause-Return; return }
        wh ""
    }

    # Step 2: cherry-pick each commit's changes without committing
    $applied = 0
    for ($idx = 0; $idx -lt $hashes.Count; $idx++) {
        $h = $hashes[$idx]
        wh "  >> git cherry-pick --no-commit $h" DarkGray
        $out = & git cherry-pick --no-commit $h 2>&1
        if ($LASTEXITCODE -ne 0) {
            $conflicted = @(& git diff --name-only --diff-filter=U 2>&1)
            if ($conflicted.Count -gt 0) {
                wh "" ; wh "  [!] MERGE CONFLICT while applying $h" Red
                foreach ($l in $out) { wh "      $l" DarkRed }
                wh "" ; wh "  Conflicted file(s):" Yellow
                foreach ($f in $conflicted) { wh "    - $f" Yellow }
                wh "" ; wh "  How do you want to proceed?" DarkCyan ; wh ""
                wh "    [1]  Stage everything as-is (git add -A) and continue" White
                wh "    [2]  Cancel — roll back everything done so far" White
                wh ""
                $handled = $false
                while ($true) {
                    $choice = Ask "Select [1 or 2]:"
                    if ($choice -eq '1') {
                        wh ""
                        wh "  >> git add -A" DarkGray
                        & git add -A 2>&1 | Out-Null
                        wh "  >> git cherry-pick --quit" DarkGray
                        & git cherry-pick --quit 2>&1 | Out-Null
                        wh "  [OK] Staged as-is (conflict markers may remain — review before final commit!)" Yellow
                        $applied++
                        $handled = $true
                        break
                    }
                    if ($choice -eq '2') {
                        & git cherry-pick --abort 2>&1 | Out-Null
                        if ($applied -gt 0) { & git reset --hard HEAD 2>&1 | Out-Null }
                        if ($createNew) {
                            & git checkout $origBranch 2>&1 | Out-Null
                            & git branch -D $targetBranch 2>&1 | Out-Null
                            wh "  [!] Rolled back — '$targetBranch' deleted, back on '$origBranch'." Yellow
                        } else {
                            & git reset --hard HEAD 2>&1 | Out-Null
                            wh "  [!] Rolled back staged changes on '$targetBranch'." Yellow
                        }
                        Pause-Return; return
                    }
                    wh "  [!] Enter 1 or 2." Red
                }
                if ($handled) { continue }
            }
            wh "  [X] Cherry-pick of '$h' failed — rolling back" Red
            foreach ($l in $out) { wh "      $l" DarkRed }
            & git cherry-pick --abort 2>&1 | Out-Null
            if ($applied -gt 0) { & git reset --hard HEAD 2>&1 | Out-Null }
            if ($createNew) {
                & git checkout $origBranch 2>&1 | Out-Null
                & git branch -D $targetBranch 2>&1 | Out-Null
                wh "  [!] Rolled back — '$targetBranch' deleted, back on '$origBranch'." Yellow
            } else {
                & git reset --hard HEAD 2>&1 | Out-Null
                wh "  [!] Rolled back staged changes on '$targetBranch'." Yellow
            }
            Pause-Return; return
        }
        $applied++
        wh "  [OK] Staged ($applied/$($hashes.Count))" Green
    }
    wh ""

    # Step 3: combine everything into a single commit
    wh "  >> git commit -m `"$msg`"" DarkGray
    $out = & git commit -m $msg 2>&1
    if ($LASTEXITCODE -ne 0) {
        wh "  [X] Commit failed" Red
        foreach ($l in $out) { wh "      $l" DarkRed }
        wh "  [!] Changes remain staged on '$targetBranch' — resolve manually." Yellow
        Pause-Return; return
    }

    wh "  [OK] Squashed commit created!" Green ; wh ""
    wh "  ┌──────────────────────────────────────────┐" Green
    wh "  │   [OK]  Multi-Pick Squash completed!     │" Green
    wh "  └──────────────────────────────────────────┘" Green
    wh "" ; (& git log --oneline -3 2>&1) | ForEach-Object { wh "    $_" Green }
    Pause-Return
}

# ─────────────────────────────────────────────────────────────────────────────
# Main menu
# ─────────────────────────────────────────────────────────────────────────────

function Show-MainMenu {
    Show-Banner
    $platform = if ($script:OnWindows) { "Windows" } elseif ($script:OnMac) { "macOS" } else { "Linux" }
    wh "  Platform : $platform  |  PS $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)" DarkGray
    if (Test-GitRepo) {
        $root = [string](& git rev-parse --show-toplevel 2>&1)
        wh "  Repo     : $root" DarkGreen
    } else {
        wh "  [!] Not inside a git repository  (cd into one first)" DarkYellow
    }
    wh "" ; Sep ; wh ""
    wh "  MAIN MENU" White ; wh ""
    wh "    [1]   Cherry Pick            Single commit — NEW or OLD diff" Cyan
    wh "    [2]   Range Pick             Commit range A..B, keep or squash" Cyan
    wh "    [3]   Hotfix Broadcast       One commit applied to N branches at once" Cyan
    wh "    [4]   Conflict Pre-Check     Dry-run: will this cherry-pick conflict?" Cyan
    wh "    [5]   Wrong Branch Rescue    Move latest commit to the correct branch" Cyan
    wh "    [6]   Undo Last Cherry-Pick  Smart reset (not pushed) or revert (pushed)" Cyan
    wh "    [7]   Clean Merged Branches  Delete all local branches merged into base" Cyan
    wh "    [8]   Commit Fixup           Fix an older commit and autosquash it in" Cyan
    wh "    [9]   Multi-Commit Rescue    Move N commits to a new branch" Cyan
    wh "    [10]  Reflog Recovery        Browse reflog and recover lost commits" Cyan
    wh "    [11]  Amend + Force Push     Amend last commit with safe force-with-lease" Cyan
    wh "    [12]  Multi-Pick Squash      N commits from anywhere -> one squashed commit" Cyan
    wh "    [0]   Exit" Cyan
    wh "" ; Sep ; wh ""
    wh "  Type Q at any prompt to cancel and return here." DarkGray ; wh ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-GitInstalled)) {
    wh "" ; wh "  [ERROR] git was not found in PATH." Red
    wh "  Install git from https://git-scm.com and try again." Red ; wh ""
    wh "  Press any key to exit..." DarkGray
    try   { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    catch { $null = Read-Host }
    exit 1
}

while ($true) {
    Show-MainMenu
    $sel = Ask "Select option:"
    switch ($sel) {
        '1'            { Invoke-CherryPick          }
        '2'            { Invoke-RangePick            }
        '3'            { Invoke-HotfixBroadcast      }
        '4'            { Invoke-ConflictPreCheck      }
        '5'            { Invoke-WrongBranchRescue     }
        '6'            { Invoke-UndoLastPick          }
        '7'            { Invoke-CleanMergedBranches   }
        '8'            { Invoke-CommitFixup           }
        '9'            { Invoke-MultiCommitRescue     }
        '10'           { Invoke-ReflogRecovery        }
        '11'           { Invoke-AmendForcePush        }
        '12'           { Invoke-MultiPickSquash       }
        '0'            { wh "" ; wh "  Goodbye!" Cyan ; wh "" ; exit 0 }
        { Is-Quit $_ } { wh "" ; wh "  Goodbye!" Cyan ; wh "" ; exit 0 }
        default {
            wh "" ; wh "  [!] Invalid selection." Yellow
            Start-Sleep -Milliseconds 600
        }
    }
}
