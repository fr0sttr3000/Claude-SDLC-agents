[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $LauncherArgs = @()
)

$Adapter = Join-Path $PSScriptRoot '_runtimes\windows-launcher.ps1'
& $Adapter -Launcher 'localrun.sh' -LauncherArgs $LauncherArgs
exit $LASTEXITCODE
