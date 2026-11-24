<#
.SYNOPSIS
    Installs the nightly-precommit Copilot agent skill for Visual Studio and VS Code.
.DESCRIPTION
    Copies SKILL.md and the shared COMMON.md to the personal skill folder
    (~\.copilot\skills\nightly-precommit), which both Visual Studio 2026 (18.5+) and VS Code
    read. Optionally also copies them into one or more workspaces.
.EXAMPLE
    .\Install-Skill.ps1
.EXAMPLE
    .\Install-Skill.ps1 -Workspace C:\perforce\AnmaTest\ApproachPlanning\distribution
#>
param(
    [string[]]$Workspace = @()
)

$ErrorActionPreference = 'Stop'
$name = 'nightly-precommit'
$source = Join-Path $PSScriptRoot 'SKILL.md'
$common = Join-Path (Split-Path $PSScriptRoot) 'nightly-common\COMMON.md'
if (-not (Test-Path $source)) { throw "SKILL.md not found next to this script: $source" }
if (-not (Test-Path $common)) { throw "Shared guidance not found: $common" }

$targets = @(Join-Path $env:USERPROFILE ".copilot\skills\$name")
foreach ($ws in $Workspace) {
    if (-not (Test-Path $ws)) { Write-Warning "Workspace not found, skipped: $ws"; continue }
    $targets += Join-Path $ws ".github\skills\$name"
}

foreach ($dir in $targets) {
    foreach ($file in @('SKILL.md', 'COMMON.md')) {
        $dest = Join-Path $dir $file
        if ((Test-Path $dest) -and (Get-Item $dest).IsReadOnly) {
            throw "Read-only (Perforce?), run 'p4 edit $dest' first: $dest"
        }
    }
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item $source (Join-Path $dir 'SKILL.md') -Force
    Copy-Item $common (Join-Path $dir 'COMMON.md') -Force
    Write-Host "Installed: $dir"
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
