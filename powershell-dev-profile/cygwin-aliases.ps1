#===============================================================================
# Ported from Cygwin ~/.bashrc (C:\cygwin64\home\yuchen.lei\.bashrc)
#===============================================================================
$env:CLIENT_ROOT = 'C:\perforce\AnmaTest'
$CLIENT_ROOT = $env:CLIENT_ROOT
if ($env:PATH -notlike "*$CLIENT_ROOT\tools\bm\bin*") { $env:PATH = "$CLIENT_ROOT\tools\bm\bin;$env:PATH" }
if (-not $env:BRAINTOOLS_DIR) { $env:BRAINTOOLS_DIR = 'C:\braintools' }
foreach ($dir in "$env:BRAINTOOLS_DIR\perforce\bin", "$env:BRAINTOOLS_DIR\braindox\bin") {
    if ((Test-Path $dir) -and ($env:PATH -notlike "*$dir*")) { $env:PATH = "$dir;$env:PATH" }
}
if ((Test-Path 'C:\cygwin64\bin\cygpath.exe') -and ($env:PATH -notlike '*C:\cygwin64\bin*')) { $env:PATH = "$env:PATH;C:\cygwin64\bin" }

function Say($msg) { Write-Host; Write-Host $msg }
$script:PythonExe = Get-Command python3, python -CommandType Application -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -like '*.exe' -and $_.Source -notlike '*\WindowsApps\*' -and $_.Source -notlike '*\cygwin*' } | Select-Object -First 1 -ExpandProperty Source
function Py { if ($script:PythonExe) { & $script:PythonExe @args } else { Write-Error 'No real Python found on PATH.' } }
function Get-ModulePath { (Get-Location).Path.Substring($CLIENT_ROOT.Length).TrimStart('\').Replace('\', '/') }

function reload    { . $PROFILE }
function ll        { Get-ChildItem @args }
function update    { Say 'Update client:'; pt updateclient -y -d; Select-String -Path pt-log.txt -Pattern '\b(ERROR|WARNING)\b' -CaseSensitive }
function checkout  { Say "Check out source files under $(Get-Location):"; p4 edit ...\*.h ...\*.cpp }
function revert    { Say 'Revert unchanged files:'; p4 revert -a }
function int       { Say 'Integrate client:'; bm -i }
function dbg       { Say 'Build Debug:'; bm -c VC143SharedDebug }
function rel       { Say 'Build Mixed Release:'; bm -c VC143MixedRelease }
function relshared { Say 'Build Shared Release:'; bm -c VC143SharedRelease }
function all       { dbg; rel }
function vs        { Say 'Start Visual Studio:'; Get-ChildItem *.sln | Select-Object -First 1 | ForEach-Object { Invoke-Item $_.FullName } }
function removeBak { Say 'Remove .bak files...'; Get-ChildItem -Recurse -File -Filter *.bak | Remove-Item -Force }

function adapt       { pt adapt -f //sw/config/domain/all/trunk/adapt-reference.xml --targets //sw/config/domain/all/trunk/adapt-targets.xml -d -@head --upgradeversion }
function adaptTse    { pt adapt -f //sw/config/domain/all/trunk/adapt-reference.xml --targets //sw/dev/mde/thomas.seiler/config/adapt-targets.xml -d -@head --upgradeversion }
function adaptRel    { pt adapt -f //sw/config/domain/all/15.0/adapt-reference.xml --targets //sw/dev/mde/thomas.seiler/config/adapt-targets-rel-15.xml -d --upgradeversion }
function adapt12     { pt adapt -f //sw/config/domain/all/12.0/adapt-reference.xml --targets //sw/dev/mde/thomas.seiler/config/adapt-targets-rel-12.xml -d }
function adapt14     { pt adapt -f //sw/config/domain/all/14.0/adapt-reference.xml --targets //sw/dev/mde/thomas.seiler/config/adapt-targets-rel-14.xml -d }
function adapt15     { pt adapt -f //sw/config/domain/all/15.0/adapt-reference.xml --targets //sw/dev/mde/thomas.seiler/config/adapt-targets-rel-15.xml -d }
function adaptRelAll { pt adapt -f //sw/config/domain/all/15.0/adapt-reference.xml --targets //sw/config/domain/all/15.0/adapt-targets.xml -d --upgradeversion }

function checkplus { Say 'Run CheckPlus:'; bm --cmake -c VC143PlusRelease }
function checkstd  { Say 'Run CheckStd:'; removeBak; & "$CLIENT_ROOT\tools\checkstandards\bin\checkStandards.exe" . }
function coverage  { Say 'Create coverage report:'; & "$CLIENT_ROOT\tools\coverage\bin\runcoverage.exe" -c VC143SharedDebug --report-directory . --method OpenCppCoverage --report-html }
function dox       { Say 'Create Doxygen documentation:'; braindox --html --omitextrapages --notransitionguides . }
function doxall    { Say 'Create extended Doxygen documentation:'; braindox --html -i -t --notransitionguides . }
function format    { Say 'Format files:'; & "$CLIENT_ROOT\tools\bm\bin\formatcpp.exe" . }
function lint      { Say 'Lint files:'; bm . -c VC143LintRelease }

function buildall {
    $modules = 'BOLDMRIMapping\distribution', 'Contouring\distribution', 'CranialSetupPlanning\distribution',
               'DWIPerformer\test\distribution', 'Fibertracking\distribution', 'FlowPlanning\distribution',
               'ImageFusion\distribution', 'ImageFusionAngio\distribution', 'ImageSortingPerformer\test'
    $log = "$CLIENT_ROOT\tse-out.txt"
    & {
        Set-Location $CLIENT_ROOT; update
        foreach ($m in $modules) { Set-Location "$CLIENT_ROOT\$m"; int; all }
        Set-Location $CLIENT_ROOT
    } *>&1 | Tee-Object -FilePath $log
    Select-String -Path $log -Pattern 'error'
}

function Invoke-AtRoot([scriptblock]$block) {
    $path = Get-ModulePath
    Push-Location $CLIENT_ROOT
    try { & $block $path } finally { Pop-Location }
}
function execIwyu        { Invoke-AtRoot { param($p) Py ./tools/CodeQualityCheckTools/IncludeWhatYouUse/include-what-you-use.py $p -no_fwd_decl } }
function verboseExecIwyu { Invoke-AtRoot { param($p) Py ./tools/CodeQualityCheckTools/IncludeWhatYouUse/include-what-you-use.py $p -no_fwd_decl -verbose } }
function execFixiwyu     { Invoke-AtRoot { param($p) Py ./tools/CodeQualityCheckTools/IncludeWhatYouUse/runFixIncludes.py $p -no_fwd_decl }; Py C:\cygwin64\home\yuchen.lei\preserve_newline.py }

function iwyu     { Say 'Run Include-What-You-Use:'; execIwyu }
function viwyu    { Say 'Run verbose mode of Include-What-You-Use:'; verboseExecIwyu }
function clang    { Say 'Run Clang-Tidy:'; Py "$CLIENT_ROOT\tools\CodeQualityCheckTools\ClangTidy\clang-tidy.py" -config anma }
function fixiwyu  { Say 'Fix Include-What-You-Use issues:'; checkout; execFixiwyu; revert; format; removeBak }
function fixclang { Say 'Fix Clang-Tidy issues:'; checkout; Py "$CLIENT_ROOT\tools\CodeQualityCheckTools\ClangTidy\clang-tidy.py" -config anma -fix; revert; format; removeBak }
function fixall   { fixiwyu; fixclang }

function bipInfo { Py C:\cygwin64\home\yuchen.lei\parse_bips.py @args }

function nightly([int]$startStep = 0) {
    checkout
    $steps = 'clang', 'iwyu', 'checkstd', 'dox', 'lint'
    for ($i = $startStep; $i -lt $steps.Count; $i++) {
        while ($true) {
            & $steps[$i]
            $answer = Read-Host 'Continue to next step? (y = yes, n = no, r = repeat)'
            if ($answer -match '^[Yy]$') { break }
            elseif ($answer -match '^[Nn]$') { Write-Host 'Stopped by user.'; return }
            elseif ($answer -match '^[Rr]$') { Write-Host "Repeating step $($i + 1)..." }
            else { Write-Host 'Invalid input. Please enter y, n, or r.' }
        }
    }
    format
    revert
    Write-Host 'Everything is fine.'
}
