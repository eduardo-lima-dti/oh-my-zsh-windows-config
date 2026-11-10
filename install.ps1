# Runs install.sh with Git Bash from PowerShell or cmd:
#   powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'

$gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $gitExe) { throw 'Git for Windows is not installed. Install it first: winget install --id Git.Git -e' }

# git.exe lives in <GitRoot>\cmd, <GitRoot>\bin or <GitRoot>\<mingw64|ucrt64>\bin: walk up to find bin\bash.exe.
$dir = Split-Path $gitExe -Parent
$bash = $null
while ($dir) {
    $candidate = Join-Path $dir 'bin\bash.exe'
    if (Test-Path $candidate) { $bash = $candidate; break }
    $dir = Split-Path $dir -Parent
}
if (-not $bash) { throw "Could not find Git Bash (bin\bash.exe) above $gitExe" }

& $bash (Join-Path $PSScriptRoot 'install.sh')
exit $LASTEXITCODE
