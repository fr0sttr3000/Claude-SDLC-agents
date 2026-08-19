[CmdletBinding()]
param(
    [string] $ExpectedSourceRevision = '',

    [switch] $RequireCleanRepository
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool] $Condition,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    if (-not $Condition) {
        throw "FAIL: $Message"
    }
}

function Parse-PowerShellFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref] $tokens,
        [ref] $parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object Message) -join '; '
        throw "PowerShell parser rejected $($Path): $messages"
    }
    return $ast
}

function Invoke-WrapperProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PowerShell,

        [Parameter(Mandatory = $true)]
        [string] $Wrapper,

        [string[]] $Arguments = @()
    )

    $output = & $PowerShell -NoLogo -NoProfile -File $Wrapper @Arguments 2>&1
    [pscustomobject] @{
        ExitCode = $LASTEXITCODE
        Output = ($output | Out-String)
    }
}

$RepositoryRoot = Split-Path -Parent $PSScriptRoot

if ($ExpectedSourceRevision) {
    Assert-True ($ExpectedSourceRevision -match '^[0-9a-f]{40}$|^[0-9a-f]{64}$') 'Expected source must be a full 40/64-hex revision'
    $ActualSourceRevision = (& git.exe -C $RepositoryRoot rev-parse HEAD).Trim()
    Assert-True ($LASTEXITCODE -eq 0) 'Repository HEAD is unavailable'
    Assert-True ($ActualSourceRevision -eq $ExpectedSourceRevision) 'Checked-out source does not match expected revision'
}
else {
    $ActualSourceRevision = 'local-unbound'
}

if ($RequireCleanRepository) {
    $RepositoryStatus = & git.exe -C $RepositoryRoot status --porcelain=v1 --untracked-files=all
    Assert-True ($LASTEXITCODE -eq 0) 'Repository status is unavailable'
    Assert-True (-not $RepositoryStatus) 'Working tree is not clean; exact-commit evidence would be ambiguous'
}

$PowerShellFiles = @(
    (Join-Path $RepositoryRoot 'sdlc.ps1'),
    (Join-Path $RepositoryRoot 'localrun.ps1'),
    (Join-Path $RepositoryRoot '_runtimes\windows-launcher.ps1')
)

$AdapterAst = $null
foreach ($File in $PowerShellFiles) {
    $ParsedAst = Parse-PowerShellFile -Path $File
    if ($File -like '*windows-launcher.ps1') {
        $AdapterAst = $ParsedAst
    }
}
Assert-True ($null -ne $AdapterAst) 'Windows adapter AST was not captured'

$LocalPathFunction = $AdapterAst.Find(
    {
        param($Node)
        $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $Node.Name -eq 'Resolve-SdlcLocalFullPath'
    },
    $true
)
Assert-True ($null -ne $LocalPathFunction) 'Resolve-SdlcLocalFullPath AST is missing'
$LocalPathScriptBlock = $LocalPathFunction.Body.GetScriptBlock()
$UncError = ''
try {
    & $LocalPathScriptBlock -Path '\\server\share\repo\sdlc.sh' -Label 'Canonical launcher'
}
catch {
    $UncError = $_.Exception.Message
}
Assert-True ($UncError -like '*UNC path*') 'UNC canonical launcher path was not rejected'

$Git = Get-Command git.exe -ErrorAction Stop
$GitRoot = Split-Path -Parent (Split-Path -Parent $Git.Source)
$DiscoveredBash = Join-Path $GitRoot 'bin\bash.exe'
Assert-True (Test-Path -LiteralPath $DiscoveredBash -PathType Leaf) 'Git for Windows Bash discovery prerequisite is missing'

$TemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("SDLC Windows CI Пробелы {0}" -f [guid]::NewGuid())
$RuntimeDirectory = Join-Path $TemporaryRoot '_runtimes'
New-Item -ItemType Directory -Path $RuntimeDirectory -Force | Out-Null

try {
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'sdlc.ps1') -Destination $TemporaryRoot
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'localrun.ps1') -Destination $TemporaryRoot
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot '_runtimes\windows-launcher.ps1') -Destination $RuntimeDirectory

    $ProbeLauncher = @'
#!/usr/bin/env bash
set -u
probe_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
{
  printf 'LAUNCHER=%s\n' "$(basename "$0")"
  printf 'ARG=%s\n' "$@"
} > "$probe_dir/windows-launcher.capture"
exit 37
'@
    $Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path $TemporaryRoot 'sdlc.sh'), $ProbeLauncher, $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $TemporaryRoot 'localrun.sh'), $ProbeLauncher, $Utf8NoBom)

    $InvalidPowerShell = Join-Path $TemporaryRoot 'invalid.ps1'
    [System.IO.File]::WriteAllText($InvalidPowerShell, 'function Broken-Syntax {', $Utf8NoBom)
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $InvalidPowerShell,
        [ref] $tokens,
        [ref] $parseErrors
    ) | Out-Null
    Assert-True ($parseErrors.Count -gt 0) 'PowerShell parser accepted an invalid mutation fixture'

    $CurrentPowerShell = (Get-Process -Id $PID).Path
    $SavedBashOverride = $env:SDLC_BASH
    try {
        Remove-Item Env:SDLC_BASH -ErrorAction SilentlyContinue
        $AutoResult = Invoke-WrapperProcess -PowerShell $CurrentPowerShell -Wrapper (Join-Path $TemporaryRoot 'sdlc.ps1') -Arguments @('plain', 'argument with spaces', 'аргумент-не-ASCII')
        Assert-True ($AutoResult.ExitCode -eq 37) 'auto-detected Bash did not propagate launcher exit code'
        $AutoCapture = Get-Content -LiteralPath (Join-Path $TemporaryRoot 'windows-launcher.capture') -Raw
        $ExpectedAutoCapture = "LAUNCHER=sdlc.sh`nARG=plain`nARG=argument with spaces`nARG=аргумент-не-ASCII`n"
        Assert-True ($AutoCapture -eq $ExpectedAutoCapture) 'auto-detected Bash changed launcher path or arguments'

        $env:SDLC_BASH = $DiscoveredBash
        $ExplicitResult = Invoke-WrapperProcess -PowerShell $CurrentPowerShell -Wrapper (Join-Path $TemporaryRoot 'localrun.ps1') -Arguments @('explicit Bash', 'значение')
        Assert-True ($ExplicitResult.ExitCode -eq 37) 'explicit SDLC_BASH did not propagate launcher exit code'
        $ExplicitCapture = Get-Content -LiteralPath (Join-Path $TemporaryRoot 'windows-launcher.capture') -Raw
        $ExpectedExplicitCapture = "LAUNCHER=localrun.sh`nARG=explicit Bash`nARG=значение`n"
        Assert-True ($ExplicitCapture -eq $ExpectedExplicitCapture) 'explicit SDLC_BASH changed launcher path or arguments'

        $env:SDLC_BASH = Join-Path $TemporaryRoot 'missing bash.exe'
        $MissingResult = Invoke-WrapperProcess -PowerShell $CurrentPowerShell -Wrapper (Join-Path $TemporaryRoot 'sdlc.ps1')
        Assert-True ($MissingResult.ExitCode -ne 0) 'missing explicit SDLC_BASH was accepted'
        Assert-True ($MissingResult.Output -like '*SDLC_BASH points to a missing file*') 'missing SDLC_BASH error was not explicit'
    }
    finally {
        if ($null -ne $SavedBashOverride) {
            $env:SDLC_BASH = $SavedBashOverride
        }
        else {
            Remove-Item Env:SDLC_BASH -ErrorAction SilentlyContinue
        }
    }
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}

if ($RequireCleanRepository) {
    $RepositoryStatusAfter = & git.exe -C $RepositoryRoot status --porcelain=v1 --untracked-files=all
    Assert-True ($LASTEXITCODE -eq 0) 'Repository status after verification is unavailable'
    Assert-True (-not $RepositoryStatusAfter) 'Windows verification changed the working tree or left untracked files'
}

Write-Host "PASS: real Windows launcher matrix source=$ActualSourceRevision"
