param([string]$ConfigPath=(Join-Path $PSScriptRoot 'config.cursor.local.json'))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'helper-common.ps1')
function Read-CursorIdentityConfig([string]$Path) {
 $resolved=(Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
 $raw=Get-Content -LiteralPath $resolved -Raw -Encoding UTF8
 $c=$raw | ConvertFrom-Json
 if($c.Usage -ne 'moonlight'){throw 'Use a Moonlight cursor configuration, not the PC card.'}
 if([string]$c.ExtensionId -notmatch '^[a-p]{32}$'){throw 'Invalid Demado extension ID.'}
 if([string]::IsNullOrWhiteSpace([string]$c.CardId) -or $c.CardId -eq 'REPLACE_AFTER_IMPORT' -or [string]$c.CardId -notmatch '^[a-z0-9]+$'){throw 'Record the saved Moonlight Demado card ID first.'}
 if([string]::IsNullOrWhiteSpace([string]$c.Name) -or -not ([string]$c.Name).Contains('Moonlight') -or ([string]$c.Name).Length -gt 200 -or [string]$c.Name -match '[\r\n]'){throw 'Use the exact saved Moonlight card name.'}
 # Keep the same state namespace algorithm as the launcher, without requiring its environment fields.
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($resolved.ToLowerInvariant()+"`n"+$raw)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
 $c | Add-Member -NotePropertyName HelperConfigKey -NotePropertyValue $key -Force
 $c
}
$config=Read-CursorIdentityConfig $ConfigPath
$stateRoot=Initialize-StateDirectory $config
$packageRoot=Join-Path $stateRoot 'cursor-extension'
if(Test-Path -LiteralPath $packageRoot){throw 'Package already exists. Preserve the loaded package; use a new config path for a new package after pausing/restoring.'}
[void](New-Item -ItemType Directory -Path $packageRoot)
foreach($name in @('manifest.json','background.js','controller.js','policy.js','probes.js')) {
 Copy-Item -LiteralPath (Join-Path (Join-Path $PSScriptRoot 'cursor-extension') $name) -Destination (Join-Path $packageRoot $name)
}
# Export only the non-secret card identity. No paths, Chrome profile or Sunshine data.
$settings=[ordered]@{schemaVersion=1;usage='moonlight';demadoExtensionId=[string]$config.ExtensionId;cardId=[string]$config.CardId;cardName=[string]$config.Name;requireFullscreen=$true}
$json=$settings | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $packageRoot 'settings.local.json'),$json,(New-Object Text.UTF8Encoding($false)))
Write-Output ('Local extension package: '+$packageRoot)
Write-Output 'Not installed or enabled. Review/approve host access and load this folder in the verified game Chrome profile only.'
