---
name: nightly-precommit
description: Pre-commit guard for a pending Perforce changelist. Runs the `nightly` code-quality checks (clang-tidy, IWYU, checkStandards, Doxygen, Lint, format) only for the C++ files opened in that changelist, fixes findings in those files, and reports whether the changelist is ready to submit. Use when asked to check, guard, or "nightly-check" a changelist before submit.
---

# Nightly Pre-Commit Guard Skill

## Input
A pending Perforce changelist number, for example `3053412`, in the client `C:\perforce\AnmaTest` (`$CLIENT_ROOT`).

Mode:
- **fix** (default): fix every finding in the changelist files and keep the fixes in the same changelist.
- **check**: when the user says "check only", "report only" or "dry run". Do not edit any file and do not change the changelist. Only report.

## How this differs from `nightly` / the `nightly-fix` skill
- Never run `checkout` (`p4 edit ...\*.h ...\*.cpp`) or `revert` (`p4 revert -a`). Both affect files outside the changelist. Only the files that are already in the changelist are checked and changed.
- clang-tidy and IWYU run with `-onlyWritable`. That limits them to opened (writable) files instead of the whole package.
- `checkstd`, `dox` and `lint` can only run on a whole package. Their output is filtered to the changelist files.
- `format` runs on the changelist files only (`formatcpp.exe` accepts file paths).
- A finding blocks the submit only if it is in a changelist file. Findings in other files are pre-existing. List them as "not blocking" and do not fix them.

## Requirements
- Every long step runs in a **new Developer PowerShell window** (see "Running a step"). Do not run long steps in the agent terminal, because it times out ("A task was canceled").
- The new window loads the user profile, so `checkstd`, `dox`, `lint`, `Py`, `Invoke-AtRoot` and `$CLIENT_ROOT` are defined.
- `p4` must be logged in (`p4 login -s`).
- clang-tidy needs the Windows Python `C:\Program Files\Python313\python.exe`. IWYU needs the default Cygwin Python of the profile.

## Helpers
Define these once in the agent terminal.

### Changelist files grouped by package
A package is the nearest parent folder that contains `Configuration.xml` (for example `BOLDMRIMapping\logic` or `BOLDMRIMapping\logic\test`).
```powershell
function Get-ChangelistPackages([int]$Cl) {
    $root = 'C:\perforce\AnmaTest'
    $info = (p4 -ztag -F '%status%|%client%' describe -s $Cl) -split '\|'
    if ($info[0] -ne 'pending') { throw "Changelist $Cl is not pending (status: $($info[0]))." }
    $client = (p4 -ztag -F '%clientName%' info)
    if ($info[1] -ne $client) { throw "Changelist $Cl belongs to client '$($info[1])', not '$client'." }
    p4 -ztag -F '%action%|%path%' fstat -Op -Ro -e $Cl //... | Where-Object { $_ -match '^[^|]+\|.+' } | ForEach-Object {
        $action, $path = $_ -split '\|', 2
        $pkg = $null
        if ($action -notmatch 'delete' -and $path -match '\.(h|hpp|cpp)$') {
            $dir = Split-Path $path
            while ($dir -and $dir.Length -gt $root.Length) {
                if (Test-Path (Join-Path $dir 'Configuration.xml')) { $pkg = $dir; break }
                $dir = Split-Path $dir
            }
        }
        [pscustomobject]@{ Action = $action; Path = $path; Package = $pkg }
    }
}
```
Files with an empty `Package` are skipped: deleted files, non-C++ files (`.tsx`, `.xml`, ...) and C++ files outside any package. List them in the report as "not checked".

### Running a step (new Developer PowerShell window)
Opens a new Developer PowerShell window for one step in one package, writes all output to a log file, and writes a `.done` marker file at the end:
```powershell
function Invoke-GuardStep([string]$Step, [string]$Dir, [int]$Cl) {
    $root = 'C:\perforce\AnmaTest'
    $vs   = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
    $logs = "$env:TEMP\nightly-precommit\$Cl"; New-Item -ItemType Directory -Force $logs | Out-Null
    $tag  = $Dir.Substring($root.Length).Trim('\') -replace '\\', '_'
    $log  = "$logs\$tag-$Step.log"; $done = "$log.done"
    Remove-Item $log, $done -ErrorAction SilentlyContinue
    $run = switch ($Step) {
        'clang' { "`$global:PythonExe='C:\Program Files\Python313\python.exe'; Py '$root\tools\CodeQualityCheckTools\ClangTidy\clang-tidy.py' -config anma -onlyWritable" }
        'iwyu'  { "Invoke-AtRoot { param(`$p) Py ./tools/CodeQualityCheckTools/IncludeWhatYouUse/include-what-you-use.py `$p -no_fwd_decl -onlyWritable -plain }" }
        default { $Step }   # checkstd, dox, lint: whole package
    }
    $cmd = "& '$vs\Common7\Tools\Launch-VsDevShell.ps1' -Arch amd64 -SkipAutomaticLocation | Out-Null; " +
           ". `$PROFILE; Set-Location '$Dir'; & { $run } *>&1 | Tee-Object -FilePath '$log'; " +
           "Set-Content '$done' `$LASTEXITCODE"
    Start-Process powershell.exe -ArgumentList '-ExecutionPolicy', 'Bypass', '-Command', $cmd
    return $log
}
```
Do not put double quotes into `$cmd`; `Start-Process` drops them. Use single quotes. The window closes automatically when the step finishes; its log and `.done` marker remain available.

Usage:
1. Start the step: `$log = Invoke-GuardStep clang C:\perforce\AnmaTest\BOLDMRIMapping\logic 3053412`.
2. Poll with short commands until `"$log.done"` exists: `Test-Path "$log.done"`, waiting with `Start-Sleep 30` between checks. Never wait in a single long command.
3. Read the findings with `Get-GuardFindings` (below).

### Findings in changelist files
Tools print absolute paths with mixed `/` and `\`, or paths relative to the package. This filter matches both:
```powershell
function Get-GuardFindings([string]$Log, [string]$Dir, [string[]]$Files) {
    $keys = foreach ($f in $Files) { $f.ToLowerInvariant(); $f.Substring($Dir.Length).TrimStart('\').ToLowerInvariant() }
    Get-Content $Log | ForEach-Object { $_ -replace '\x1b\[[0-9;]*m', '' } | Where-Object {
        if ($_ -notmatch '\b(warning|error|info|FAILED)\b') { return $false }
        $line = ($_ -replace '/', '\').ToLowerInvariant()
        foreach ($k in $keys) { if ($line.Contains($k)) { return $true } }
        $false
    }
}
```
All other `warning`/`error` lines in the log are "not blocking". Also check the log for a crash or tool failure (Python traceback, `ModuleNotFoundError`, build error without a file). A failed tool is never a pass.

Reading results: `dox` prints its progress through stderr, so PowerShell shows `NativeCommandError` lines. These are not warnings. `lint` is clean for the changelist when no `Warning`, `Error` or `Info` line with a number refers to a changelist file. For clang-tidy, also note the check name in brackets, for example `[modernize-use-nodiscard]`. IWYU prints `<path> - FAILED` for each file with include problems. The lines below it, up to the next `- FAILED` line or `Done`, are the fix: `- #include ...` means remove, `#include ...` means add. Read that block in the log.

## Procedure
1. Check `p4 login -s`. Run `$all = Get-ChangelistPackages <cl>` and show the user the files grouped by package and the skipped files. If no file has a package, report "nothing to check" and stop.
2. Note the files in the changelist that are opened but unchanged (`p4 diff -sr` on the changelist files). Report them, but do not revert them.
3. For each package `$dir` (with `$files = ($all | ? Package -eq $dir).Path`), run the steps in this order: `clang`, `iwyu`, `checkstd`, `dox`, `lint`:
   1. Run the step with `Invoke-GuardStep <step> $dir <cl>`. Poll until it finishes. Then run `Get-GuardFindings $log $dir $files`.
   2. **No findings in changelist files:** the step passes. Go to the next step.
   3. **Findings in changelist files:**
      - In **check** mode: record them as blocking and go to the next step.
      - In **fix** mode: fix the source code at the root cause. Do not silence it with `NOLINT` or by changing settings unless a real fix is impossible. If it is impossible, explain why. Follow the existing code style. C++20. Change only files in the changelist. If a fix needs a file outside the changelist (for example a shared header), ask the user first; if approved, open it with `p4 edit -c <cl> <file>` so it is part of the changelist. Then run the **same step again** and repeat until it passes.
4. Format, on the changelist files only (quick, so the agent terminal is fine; it does not load the profile, so use the full path). Run it from the package folder:
   - **check** mode: `& 'C:\perforce\AnmaTest\tools\bm\bin\formatcpp.exe' --verify $files`. Exit code `0` means formatted. Otherwise, the listed files are blocking.
   - **fix** mode: `& 'C:\perforce\AnmaTest\tools\bm\bin\formatcpp.exe' $files`, then confirm with `--verify`.
5. In **fix** mode, if any file was changed in steps 3 or 4, run all five steps again for the affected packages (final verification). Go back to step 3 for any step that has findings in changelist files.
6. In **fix** mode, update the changelist description only if fixes were made. Keep the existing text unchanged and append one short line per fix. If clang-tidy findings were fixed and the description does not contain `clang-tidy`, the appended line must contain it:
   ```powershell
   $desc = (p4 -ztag -F '%desc%' describe -s <cl>) -join "`n"
   p4 --field "Description=$($desc.TrimEnd())`n- clang-tidy: <checks fixed>`n- iwyu: ..." change -o <cl> | p4 change -i
   ```
7. Run `removeBak` in each package folder (checkStandards can create `.bak` files). Never add `.bak` files to the changelist.
8. Report:
   - A verdict: **READY TO SUBMIT** if every step passed for every package, otherwise **BLOCKED**.
   - A table: one row per package, one column per step (`clang`, `iwyu`, `checkstd`, `dox`, `lint`, `format`) with pass/fail.
   - The blocking findings (check mode) or the fixes made (fix mode), and the files changed.
   - Files that were not checked, unchanged opened files, and a count of "not blocking" findings in other files.
   - Do **not** submit the changelist.
9. Delete the logs: `Remove-Item "$env:TEMP\nightly-precommit\<cl>" -Recurse -Force`. If a step window hangs, close it first. Exclude `$PID`, because the current shell's own command line also matches the filter:
   ```powershell
   Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*nightly-precommit\<cl>\*" } | ForEach-Object { Stop-Process -Id $_.ProcessId }
   ```

## Notes
- `-onlyWritable` processes a `.cpp` file if the file or its header is writable. Files opened in other changelists are writable too, so the log can contain findings for them. `Get-GuardFindings` ignores them.
- A header in the changelist without a writable `.cpp` file next to it is not processed by clang-tidy or IWYU. Name such headers in the report.
- IWYU fixes are add/remove `#include` changes. Rebuild (`bm . -c VC143LintRelease` or a normal build) to confirm nothing breaks.
- Doxygen warnings usually mean missing or incorrect `@param`, `@return` or `@brief` comments.
- If the changelist is shelved, the local files are what is checked. Remind the user to re-shelve after fixes.
