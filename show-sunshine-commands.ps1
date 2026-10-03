param([string]$ConfigPath=(Join-Path $PSScriptRoot 'config.local.json'))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'helper-common.ps1')
$resolved=(Resolve-Path -LiteralPath $ConfigPath).Path
$null=Read-HelperConfig $resolved
Get-PrepCommands $PSScriptRoot $resolved | ConvertTo-Json
