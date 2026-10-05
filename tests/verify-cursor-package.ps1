$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message}}
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('pjivn-cursor-package-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $fixtureRoot)
foreach($name in @('prepare-cursor-extension.ps1','helper-common.ps1')){Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $fixtureRoot $name)}
Copy-Item -LiteralPath (Join-Path $root 'cursor-extension') -Destination (Join-Path $fixtureRoot 'cursor-extension') -Recurse
$config=[pscustomobject]@{Usage='moonlight';ExtensionId='dfmhlfpfpbijchleocfbpcdjgnbpdigh';CardId='moon123';Name='イヴンタイト(Moonlight)'}
$configFile=Join-Path $fixtureRoot 'config.cursor.local.json'
$config | ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding UTF8
$script=Join-Path $fixtureRoot 'prepare-cursor-extension.ps1'
& $script -ConfigPath $configFile | Out-Null
$packages=@(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot '.local') -Filter 'settings.local.json' -Recurse)
Assert ($packages.Count -eq 1) 'Expected one generated settings file.'
$json=Get-Content -LiteralPath $packages[0].FullName -Raw -Encoding UTF8
$settings=$json | ConvertFrom-Json
Assert ($settings.cardId -ceq 'moon123' -and $settings.cardName -ceq $config.Name -and $settings.requireFullscreen) 'Card mapping mismatch.'
Assert ($settings.PSObject.Properties.Name.Count -eq 6) 'Unexpected settings field count.'
foreach($secret in @('ChromePath','Profile','SunshineConfigPath',$fixtureRoot)) {Assert (-not $json.Contains($secret)) 'Local environment leaked into extension config.'}
$package=Split-Path $packages[0].FullName -Parent
Assert (@(Get-ChildItem -LiteralPath $package -File).Count -eq 6) 'Unexpected package contents.'
$before=(Get-FileHash -LiteralPath $packages[0].FullName -Algorithm SHA256).Hash
$failed=$false
try{& $script -ConfigPath $configFile | Out-Null}catch{$failed=$true}
Assert $failed 'Existing package overwrite accepted.'
Assert ((Get-FileHash -LiteralPath $packages[0].FullName -Algorithm SHA256).Hash -ceq $before) 'Existing package changed.'
$config.Usage='pc'
$config | ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding UTF8
$failed=$false
try{& $script -ConfigPath $configFile | Out-Null}catch{$failed=$true}
Assert $failed 'PC config accepted for cursor helper.'
# Invalid identifiers fail before any package is created.
$config.Usage='moonlight'
foreach($field in @('CardId','ExtensionId','Name')) {
 $savedValue=$config.$field
 $config.$field=if($field -eq 'CardId'){'REPLACE_AFTER_IMPORT'}elseif($field -eq 'ExtensionId'){'invalid'}else{'PC'}
 $config | ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding UTF8
 $failed=$false
 try{& $script -ConfigPath $configFile | Out-Null}catch{$failed=$true}
 Assert $failed ('Invalid '+$field+' accepted.')
 $config.$field=$savedValue
}
Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot '.local') -Filter 'settings.local.json' -Recurse).Count -eq 1) 'Invalid identity created a package.'
# A full launcher config remains compatible; its environment values are neither required nor exported.
$config | Add-Member -NotePropertyName ChromePath -NotePropertyValue 'not-an-installed-chrome'
$config | Add-Member -NotePropertyName Profile -NotePropertyValue 'not-a-real-profile'
$config | Add-Member -NotePropertyName SunshineConfigPath -NotePropertyValue 'not-a-sunshine-config'
$fullConfig=Join-Path $fixtureRoot 'full.moonlight.local.json'
$config | ConvertTo-Json | Set-Content -LiteralPath $fullConfig -Encoding UTF8
& $script -ConfigPath $fullConfig | Out-Null
$packages=@(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot '.local') -Filter 'settings.local.json' -Recurse)
Assert ($packages.Count -eq 2) 'Full launcher config compatibility failed.'
foreach($settingsFile in $packages){$text=Get-Content -LiteralPath $settingsFile.FullName -Raw -Encoding UTF8; Assert (-not ($text -match 'not-a-real-profile|not-an-installed-chrome|not-a-sunshine-config')) 'Unused environment values leaked.'}
Write-Output 'PASS: minimal card-only generation, full config compatibility, identity rejection, no personal fields, PC rejection, existing package preservation. No UI/installation.'
