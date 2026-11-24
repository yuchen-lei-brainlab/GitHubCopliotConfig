---
name: nightly-fix
description: Run the `nightly` code-quality pipeline (clang-tidy, IWYU, checkStandards, Doxygen, Lint, format) on a given package folder (e.g. BOLDMRIMapping/logic), fix every reported error/warning step by step, and collect the fixes in a Perforce changelist. Use when asked to make a package "nightly clean".
---

# Nightly Fix Skill

## Input
A package path relative to `C:\perforce\AnmaTest`, e.g. `BOLDMRIMapping/logic`
→ working folder `C:\perforce\AnmaTest\BOLDMRIMapping\logic`.

## What `nightly` does (defined in the PowerShell profile)
```
nightly [-startStep N]
  checkout   -> p4 edit ...\*.h ...\*.cpp
  steps (index 0..4), each followed by prompt "Continue to next step? (y/n/r)":
    0 clang    -> Py $CLIENT_ROOT\tools\CodeQualityCheckTools\ClangTidy\clang-tidy.py -config anma
    1 iwyu     -> execIwyu
    2 checkstd -> removeBak; $CLIENT_ROOT\tools\checkstandards\bin\checkStandards.exe .
    3 dox      -> braindox --html --omitextrapages --notransitionguides .
    4 lint     -> bm . -c VC143LintRelease
  format     -> $CLIENT_ROOT\tools\bm\bin\formatcpp.exe .
  revert     -> p4 revert -a   (reverts unchanged files)
  prints "Everything is fine."
```
`y` = next step, `r` = repeat the current step, `n` = stop.

## Requirements
- Every nightly command runs in a **new Developer PowerShell window** (see "Running a step" below). Do not run long steps in the agent terminal, because it times out ("A task was canceled").
- The new window loads the user profile, so `nightly`, `clang`, `iwyu`, `checkstd`, `dox`, `lint`, `format`, `checkout`, `revert`, `Py`, `Say` and `$CLIENT_ROOT` are defined.
- `p4` must be logged in (`p4 login -s`).

## Running a step (new Developer PowerShell window)
Define this helper once in the agent terminal. It opens a new Developer PowerShell window for one step, writes all output to a log file, and writes a `.done` marker file at the end:
```powershell
function Invoke-NightlyStep([string]$Step, [string]$Dir) {
    $vs   = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
    $logs = "$env:TEMP\nightly"; New-Item -ItemType Directory -Force $logs | Out-Null
    $log  = "$logs\$Step.log"; $done = "$log.done"
    Remove-Item $log, $done -ErrorAction SilentlyContinue
    $cmd = "& '$vs\Common7\Tools\Launch-VsDevShell.ps1' -Arch amd64 -SkipAutomaticLocation | Out-Null; " +
           ". `$PROFILE; Set-Location '$Dir'; & $Step *>&1 | Tee-Object -FilePath '$log'; " +
           "Set-Content '$done' `$LASTEXITCODE"
    Start-Process powershell.exe -ArgumentList '-ExecutionPolicy', 'Bypass', '-Command', $cmd
    return $log
}
```
Usage:
1. Start the step: `$log = Invoke-NightlyStep clang C:\perforce\AnmaTest\BOLDMRIMapping\logic`.
2. Poll with short commands until `"$log.done"` exists: `Test-Path "$log.done"`, waiting with `Start-Sleep 30` between checks. Never wait in a single long command.
3. Read the result: `Select-String -Path $log -Pattern 'warning|error' | Select-Object -First 100`.

Python per step: `clang` fails with `ModuleNotFoundError: No module named 'utils'` under the Cygwin Python set by the profile, because Cygwin treats `C:/...` paths as relative. For `clang`, add `` `$global:PythonExe='C:\Program Files\Python313\python.exe'; `` after `. `$PROFILE;` in `$cmd`. `iwyu` needs the default Cygwin Python, so leave the variable unchanged for it.

Reading results: `dox` prints its progress through stderr, so PowerShell shows `NativeCommandError` lines. These are not warnings. `lint` is clean when it ends with `OK` and shows no `Warning`, `Error` or `Info` lines with a number.

The window closes automatically when the step finishes; its log and `.done` marker remain available.

## Procedure
The interactive prompt cannot be answered reliably from the agent terminal. Run the same functions one at a time and make each y/r decision yourself. This produces the same result as `nightly`.

1. `Set-Location C:\perforce\AnmaTest\<package>` (for example `C:\perforce\AnmaTest\BOLDMRIMapping\logic`).
2. Create one changelist for the session:
   - First save the files that are already open in the default changelist: `$pre = p4 opened -c default | % { ($_ -split '#')[0] }`.
   - Create an **empty** changelist. Remove the `Files:` section, otherwise every file in the default changelist is moved into it:
     ```powershell
     $spec = (p4 change -o) -join "`n" -replace '(?s)\nFiles:.*$','' -replace '<enter description here>','CHANGED: <package> nightly fixes'
     $cl = ((($spec | p4 change -i) -split ' ')[1])
     ```
   - Run `checkout` in the package folder (quick, so the agent terminal is fine).
   - Move only the newly opened package files into `$cl`: `p4 opened -c default ... | % { ($_ -split '#')[0] } | ? { $_ -notin $pre } | % { p4 reopen -c $cl $_ }`.
3. For each step in this order: `clang`, `iwyu`, `checkstd`, `dox`, `lint`:
   1. Run the step in a new Developer PowerShell window with `Invoke-NightlyStep <step> <folder>`. Poll until it finishes, then read the log.
   2. Review the output for errors and warnings that belong to this package's files. For clang-tidy, also check the check name in brackets, for example `[modernize-use-nodiscard]`.
   3. **If any error or warning remains (this is the "r" answer):**
      - Fix the source code at the root cause. Do not silence it with `NOLINT` or by changing settings unless a real fix is impossible. If it is impossible, explain why.
      - Follow the existing code style. C++20.
      - Make sure every modified or added file is in the changelist: use `p4 edit -c $cl <file>` or `p4 add -c $cl <file>`.
      - Update the changelist description. It must start with `CHANGED:`. Add a short, descriptive line for each fix. If clang-tidy findings were fixed, the description must contain `clang-tidy`.
        ```powershell
        p4 --field "Description=CHANGED: <package> <summary>`n- clang-tidy: <checks fixed>`n- iwyu: ...`n- checkstd: ..." change -o $cl | p4 change -i
        ```
      - Run the **same step again** and repeat until it reports no errors or warnings.
   4. **If the output is clean (this is the "y" answer):** go to the next step.
4. After all five steps are clean, run `Invoke-NightlyStep format <folder>` and wait for it to finish. Then run `revert` (`p4 revert -a`, which reverts unchanged files; quick, so the agent terminal is fine).
5. Final verification: run all five steps again with `Invoke-NightlyStep`, one after another. If any step shows an error or warning, go back to step 3 for that check. The process is finished when every step is clean. Optionally, tell the user they can confirm by running `nightly` in a Developer PowerShell and answering `y` at each prompt; it should print `Everything is fine.`
6. Report the result: the changelist number, the final description, and the files that were changed. Do **not** submit the changelist.

## Notes
- Keep fixes minimal and only inside the package folder. Shared headers from other packages may be affected. Ask before changing them.
- IWYU fixes are add/remove `#include` changes. Rebuild with `bm . -c VC143LintRelease` or a normal build to confirm nothing breaks.
- Doxygen warnings usually mean missing or incorrect `@param`, `@return` or `@brief` comments.
- `checkstd` runs `removeBak` first. Never commit `.bak` files.

## Learnings
- Preserve justified existing analyzer suppressions and the code they protect; do not remove them or change an API solely to appease another analyzer. For example, retain a reference-returning thread-local generator and its `//lint !e1929` annotation rather than returning a pointer, and keep a macro's `//lint !e750` annotation when it is used by third-party headers.
- Preserve explicit lambda captures when they are intentional; replacing `[this, &event, count]` with `[&]` can introduce lint findings. Keep established `CHKSTD_OK` test-header comments unchanged unless a finding actually requires changing them.
- If modified tests belong to a separate test package, run its lint independently in a new Developer PowerShell window; linting the parent package may not include test sources. Review numbered findings and exit status, and report any remaining blockers rather than claiming the test package is clean.
