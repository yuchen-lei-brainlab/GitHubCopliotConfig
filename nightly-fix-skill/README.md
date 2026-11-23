# nightly-fix skill

`SKILL.md` is a GitHub Copilot agent skill. It runs the `nightly` code-quality pipeline (clang-tidy, IWYU, checkStandards, Doxygen, Lint, format) on a package, fixes every error and warning, and collects the fixes in a Perforce changelist whose description starts with `CHANGED:`.

## Install the skill in a solution

Copilot loads skills from `.github\skills\<skill-name>\SKILL.md` below the workspace root, which is the folder that contains the opened solution.

1. Find the workspace root of the solution, for example `C:\perforce\AnmaTest\ImageFusion\distribution`.
2. Copy the skill into a folder named exactly `nightly-fix`:
   ```powershell
   $root = 'C:\perforce\AnmaTest\ImageFusion\distribution'
   New-Item -ItemType Directory -Force "$root\.github\skills\nightly-fix" | Out-Null
   Copy-Item 'C:\GitHubCopliotConfig\nightly-fix-skill\SKILL.md' "$root\.github\skills\nightly-fix\SKILL.md"
   ```
3. Reload the solution or start a new Copilot chat.

Rules:
- The folder name must match `name: nightly-fix` in the header of `SKILL.md`.
- The file must be named `SKILL.md` and start with the `---` header block.
- Copy only `SKILL.md`. This README is not needed in the solution.

### Use it in every solution (optional)
Copy it to the user-level skill folder instead:
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.copilot\skills\nightly-fix" | Out-Null
Copy-Item 'C:\GitHubCopliotConfig\nightly-fix-skill\SKILL.md' "$env:USERPROFILE\.copilot\skills\nightly-fix\SKILL.md"
```
Not every Copilot client reads this folder. If the skill is not picked up, use the per-solution copy.

## Requirements on the machine
- Visual Studio 2022 with the Developer PowerShell (`Launch-VsDevShell.ps1`).
- A PowerShell profile that defines `nightly`, `checkout`, `clang`, `iwyu`, `checkstd`, `dox`, `lint`, `format`, `revert` and `$CLIENT_ROOT`.
- Windows Python at `C:\Program Files\Python313\python.exe` for the clang-tidy step. If it is installed elsewhere, change that path in `SKILL.md`.
- `p4` logged in.

## Usage
In Copilot chat, ask:
> run the nightly-fix skill on BOLDMRIMapping/logic

The package path is relative to `C:\perforce\AnmaTest`.

## Updating
The master copy is `C:\perforce\AnmaTest\.github\skills\nightly-fix\SKILL.md`. After changing it, copy it here again and to every solution that uses it.
