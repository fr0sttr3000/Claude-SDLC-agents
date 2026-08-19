[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('sdlc.sh', 'localrun.sh')]
    [string] $Launcher,

    [string[]] $LauncherArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-SdlcLocalFullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Label
    )

    $FullPath = [System.IO.Path]::GetFullPath($Path)
    if ($FullPath.StartsWith('\\')) {
        throw "$Label cannot use a UNC path: $FullPath"
    }
    return $FullPath
}

function Resolve-SdlcGitBash {
    if ($env:SDLC_BASH) {
        $Explicit = Resolve-SdlcLocalFullPath -Path $env:SDLC_BASH -Label 'SDLC_BASH'
        if (Test-Path -LiteralPath $Explicit -PathType Leaf) {
            return $Explicit
        }
        throw "SDLC_BASH points to a missing file: $Explicit"
    }

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $Git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($Git) {
        $GitRoot = Split-Path -Parent (Split-Path -Parent $Git.Source)
        $Candidates.Add((Join-Path $GitRoot 'bin\bash.exe'))
    }

    $Bash = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($Bash -and $Bash.Source -match '[\\/]Git[\\/]') {
        $Candidates.Add($Bash.Source)
    }

    if ($env:ProgramFiles) {
        $Candidates.Add((Join-Path $env:ProgramFiles 'Git\bin\bash.exe'))
    }
    if (${env:ProgramFiles(x86)}) {
        $Candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'))
    }
    if ($env:LOCALAPPDATA) {
        $Candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'))
    }

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            return Resolve-SdlcLocalFullPath -Path $Candidate -Label 'Git for Windows Bash'
        }
    }

    throw 'Git for Windows Bash was not found. Install Git for Windows or set SDLC_BASH to bash.exe.'
}

function ConvertTo-SdlcMsysPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $WindowsPath
    )

    $FullPath = Resolve-SdlcLocalFullPath -Path $WindowsPath -Label 'Canonical launcher'
    if ($FullPath -notmatch '^([A-Za-z]):\\(.*)$') {
        throw "Cannot convert path for Git for Windows Bash: $FullPath"
    }

    $Drive = $Matches[1].ToLowerInvariant()
    $Tail = $Matches[2] -replace '\\', '/'
    return "/$Drive/$Tail"
}

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$CanonicalLauncher = Join-Path $RepositoryRoot $Launcher
if (-not (Test-Path -LiteralPath $CanonicalLauncher -PathType Leaf)) {
    throw "Canonical launcher is missing: $CanonicalLauncher"
}

$BashPath = Resolve-SdlcGitBash
$MsysLauncher = ConvertTo-SdlcMsysPath -WindowsPath $CanonicalLauncher

Write-Host 'Supported SDLC scope: Cycle 1. Cycle 2/3 — FROZEN / NOT READY.'
Write-Host "Windows adapter: $Launcher via Git for Windows Bash."

& $BashPath $MsysLauncher @LauncherArgs
$LauncherExitCode = $LASTEXITCODE
if ($null -eq $LauncherExitCode) {
    throw 'Git for Windows Bash ended without an exit code.'
}
exit $LauncherExitCode
