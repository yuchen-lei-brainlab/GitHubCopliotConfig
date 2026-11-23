<#
.SYNOPSIS
    Installs the nightly-fix Copilot agent skill for Visual Studio and VS Code.
.DESCRIPTION
    Copies SKILL.md to the personal skill folder (~\.copilot\skills\nightly-fix), which both
    Visual Studio 2026 (18.5+) and VS Code read. Optionally also copies it into the
    .github\skills folder of one or more workspaces.
.EXAMPLE
    .\Install-Skill.ps1
.EXAMPLE
    .\Install-Skill.ps1 -Workspace C:\perforce\AnmaTest\ApproachPlanning\distribution
#>
param(
    [string[]]$Workspace = @()
)

$ErrorActionPreference = 'Stop'
$name = 'nightly-fix'
$source = Join-Path $PSScriptRoot 'SKILL.md'
if (-not (Test-Path $source)) { throw "SKILL.md not found next to this script: $source" }

$targets = @(Join-Path $env:USERPROFILE ".copilot\skills\$name")
foreach ($ws in $Workspace) {
    if (-not (Test-Path $ws)) { Write-Warning "Workspace not found, skipped: $ws"; continue }
    $targets += Join-Path $ws ".github\skills\$name"
}

foreach ($dir in $targets) {
    New-Item -ItemType Directory -Force $dir | Out-Null
    $dest = Join-Path $dir 'SKILL.md'
    if ((Test-Path $dest) -and -not (Get-Item $dest).IsReadOnly) {
        Copy-Item $source $dest -Force
    }
    elseif (Test-Path $dest) {
        Write-Warning "Read-only (Perforce?), run 'p4 edit $dest' first: $dest"
        continue
    }
    else {
        Copy-Item $source $dest
    }
    Write-Host "Installed: $dest"
}

# Checks
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $versions = & $vswhere -all -prerelease -property catalog_productDisplayVersion
    if (-not ($versions | Where-Object { [version]($_ -replace '[^\d\.].*$', '') -ge [version]'18.5' })) {
        Write-Warning "No Visual Studio 18.5+ found (found: $($versions -join ', ')). Visual Studio loads agent skills only from VS 2026 18.5 on. VS Code works."
    }
}
if (-not (Test-Path 'C:\Program Files\Python313\python.exe')) {
    Write-Warning "Windows Python not found at 'C:\Program Files\Python313\python.exe'. The clang-tidy step needs it; adjust the path in SKILL.md."
}
Write-Host 'Done. Restart Visual Studio / VS Code or start a new chat in agent mode.'
