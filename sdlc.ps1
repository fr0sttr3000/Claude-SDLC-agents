[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $LauncherArgs = @()
)

$Adapter = Join-Path $PSScriptRoot '_runtimes\windows-launcher.ps1'
& $Adapter -Launcher 'sdlc.sh' -LauncherArgs $LauncherArgs
exit $LASTEXITCODE
