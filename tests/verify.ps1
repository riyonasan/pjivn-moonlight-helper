$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'helper-common.ps1')
function Assert($Condition,[string]$Message) {if(-not $Condition){throw $Message}}
function Assert-Throws([scriptblock]$Action,[string]$Message) {
 $thrown=$false
 try {& $Action | Out-Null} catch {$thrown=$true}
 Assert $thrown $Message
}
$asts=@{}
foreach($file in Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse) {
 $tokens=$null;$errors=$null
 $ast=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
 Assert ($errors.Count -eq 0) ($file.Name+': '+($errors.Message -join '; '))
 $asts[$file.Name]=$ast
}
foreach($name in @('launch-pjivn.ps1','fullscreen-pjivn.ps1')) {
 $native=$asts[$name].Find({param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $node.Value.Contains('public class Pjivn')},$true)
 Assert ($null -ne $native) 'Native helper source not found.'
 # Compile the declarations only; none of the Windows API methods are called.
 Add-Type -TypeDefinition $native.Value
}
$import=Get-Content (Join-Path $root 'demado/pjivn.import.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$example=Get-Content (Join-Path $root 'config.example.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($import.mados.Count -eq 1 -and $import.version -eq '2.0.60') 'Unexpected import envelope.'
$card=$import.mados[0]
Assert ($card.name -eq $example.Name -and $card.addressbar -eq $false -and $card.zoom -eq 1) 'Import/config mismatch.'
Assert ($card.size.width -eq 1280 -and $card.size.height -eq 720) 'Unexpected game size.'
Assert (-not $card.PSObject.Properties['_id'] -and -not $card.PSObject.Properties['position']) 'Local ID or position leaked.'
Assert ($card.stylesheet -ceq (Get-Content (Join-Path $root 'demado/pjivn.css') -Raw -Encoding UTF8)) 'CSS is out of sync.'
$url='chrome-extension://'+$example.ExtensionId+'/index.html#dashboard'
Assert ((Get-ChromeArguments 'Profile 1' $url) -ceq ('--profile-directory="Profile 1" --new-window "'+$url+'"')) 'Profile quoting failed.'
Assert-Throws {Get-ChromeArguments 'Default" --bad' $url} 'Profile injection accepted.'
Assert-Throws {Get-ChromeArguments 'Default' 'https://example.invalid'} 'Unexpected URL accepted.'
$cmds=Get-PrepCommands 'C:\helper path' 'C:\helper path\settings.local.json'
Assert ($cmds.do -ceq 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\helper path\launch-pjivn.ps1" -ConfigPath "C:\helper path\settings.local.json" -Fullscreen') 'do command quoting failed.'
Assert ($cmds.undo -eq $cmds.do.Replace(' -Fullscreen',' -Restore')) 'undo command mismatch.'
Assert-Throws {Get-PrepCommands 'C:\bad"path' 'C:\settings.json'} 'Unsafe command path accepted.'
$saved=[pscustomobject]@{handle=42;pid=12;processStartTicks=12345678901234}
Assert (Test-WindowIdentity $saved 42 12 12345678901234) 'Matching identity rejected.'
Assert (-not (Test-WindowIdentity $saved 43 12 12345678901234)) 'Reused window handle accepted.'
Assert (-not (Test-WindowIdentity $saved 42 13 12345678901234)) 'Different PID accepted.'
Assert (-not (Test-WindowIdentity $saved 42 12 12345678901235)) 'Reused PID accepted.'
Assert (-not (Test-WindowIdentity $null 42 12 12345678901234)) 'Missing state accepted.'
$function=$asts['fullscreen-pjivn.ps1'].Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-MonitorBounds'},$true)
. ([scriptblock]::Create($function.Extent.Text))
$bounds=[pscustomobject]@{Left=0;Top=0;Right=2560;Bottom=1440}
Assert (Test-MonitorBounds ([pscustomobject]@{left=0;top=0;right=2560;bottom=1440}) $bounds) 'Fullscreen rejected.'
Assert (-not (Test-MonitorBounds ([pscustomobject]@{left=0;top=0;right=1280;bottom=720}) $bounds)) 'CSS bounds accepted.'
Assert (-not (Test-MonitorBounds ([pscustomobject]@{left=-8;top=-8;right=2568;bottom=1448}) $bounds)) 'Maximized frame accepted.'
foreach($resolution in @(@(1280,720),@(1920,1080),@(2560,1440))) {
 $plan=& (Join-Path $root 'fullscreen-pjivn.ps1') -PlanOnly -Width $resolution[0] -Height $resolution[1] | ConvertFrom-Json
 Assert ($plan.CssScale -eq $resolution[0]/1280 -and -not $plan.ChangesDisplayResolution -and -not $plan.BrowserZoomChanged) 'Plan mismatch.'
}
Assert-Throws {& (Join-Path $root 'fullscreen-pjivn.ps1') -PlanOnly -Width 1920 -Height 1200} 'Non-16:9 plan accepted.'
# Verify config parsing through harmless fixture files; no Chrome process is started.
$temp=Join-Path ([IO.Path]::GetTempPath()) ('pjivn-check-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
try {
 $fixture=Join-Path $temp 'chrome.exe'
 Set-Content -LiteralPath $fixture -Value 'not executable'
 $example.ChromePath=$fixture;$example.Profile='Profile 1';$example.CardId='sample123'
 $configFile=Join-Path $temp 'settings.local.json'
 $example | ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding UTF8
 $parsed=Read-HelperConfig $configFile
 Assert ($parsed.Profile -eq 'Profile 1' -and $parsed.Name -eq $card.name) 'Config parsing failed.'
 $example.CardId='REPLACE_AFTER_IMPORT'
 $example | ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding UTF8
 Assert-Throws {Read-HelperConfig $configFile} 'Unconfigured card accepted.'
} finally {
 # Only remove the exact two test fixture files in the freshly created temp directory.
 Remove-Item -LiteralPath $fixture,$configFile -Force -ErrorAction SilentlyContinue
 Remove-Item -LiteralPath $temp -Force
}
$launcher=$asts['launch-pjivn.ps1'].Extent.Text
foreach($guard in @("if(`$tabs.Count -ne 1)","`$w.Current.ProcessId -ne `$owner.pid","`$value -ne `$expectedUrl",'Test-WindowIdentity $owner','if($documentUrl -ne $url)','Close-OwnedDashboard $url')) {
 Assert ($launcher.Contains($guard)) ('Dashboard cleanup guard missing: '+$guard)
}
Assert (-not ($launcher -match 'Stop-Process|taskkill|--user-data-dir')) 'Unsafe process/profile operation found.'
# Moonlight assets preserve the PC layout and keep iframe cursor rules separate.
$moonImport=Get-Content (Join-Path $root 'demado/pjivn-moonlight.import.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$moonConfig=Get-Content (Join-Path $root 'config.moonlight.example.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$moonCss=Get-Content (Join-Path $root 'demado/pjivn-moonlight.css') -Raw -Encoding UTF8
Assert ($moonImport.mados.Count -eq 1 -and $moonConfig.Usage -eq 'moonlight') 'Moonlight separation missing.'
Assert ($moonImport.mados[0].name -ceq $moonConfig.Name -and $moonConfig.Name -cne $card.name) 'Moonlight card name must be distinct.'
Assert ($moonImport.mados[0].stylesheet -ceq $moonCss) 'Moonlight CSS is out of sync.'
Assert ($moonCss.StartsWith($card.stylesheet) -and $moonCss.Contains('cursor: none !important')) 'PC layout changed in Moonlight CSS.'
Assert ($moonImport.mados[0].url -ceq $card.url -and $moonImport.mados[0].addressbar -eq $true -and $moonImport.mados[0].zoom -eq $card.zoom) 'Moonlight card target/settings changed.'
$inner=Get-Content (Join-Path $root 'demado/pjivn-moonlight-frame-cursor.css') -Raw -Encoding UTF8
Assert (-not ($inner -match 'clip-path|transform:|position:|width:|height:')) 'Layout CSS leaked into iframe cursor candidate.'
$ownershipConfig=[pscustomobject]@{Usage='moonlight';HelperConfigKey='config-a'}
$owner=[pscustomobject]@{handle=42;pid=12;processStartTicks=12345678901234;configKey='config-a'}
Assert (Test-GameOwnership $owner $ownershipConfig 42 12 12345678901234) 'Owned Moonlight window rejected.'
Assert (-not (Test-GameOwnership $null $ownershipConfig 42 12 12345678901234)) 'Unowned PC window accepted.'
Assert (-not (Test-GameOwnership $owner $ownershipConfig 43 12 12345678901234)) 'Reused Moonlight handle accepted.'
Assert (-not (Test-GameOwnership $owner $ownershipConfig 42 13 12345678901234)) 'Different Moonlight PID accepted.'
Assert (-not (Test-GameOwnership $owner $ownershipConfig 42 12 12345678901235)) 'Reused Moonlight PID accepted.'
$ownershipConfig.HelperConfigKey='config-b'
Assert (-not (Test-GameOwnership $owner $ownershipConfig 42 12 12345678901234)) 'Different Moonlight config accepted.'
Assert ($launcher.Contains('foreach($existing in $targets){Assert-OwnedGameWindow') -and $launcher.Contains('Assert-OwnedGameWindow $config $stateRoot $target')) 'Launcher ownership guard missing.'
Assert ($asts['fullscreen-pjivn.ps1'].Extent.Text.Contains('Assert-OwnedGameWindow $config $stateRoot $windows[0]')) 'Standalone fullscreen ownership guard missing.'
Assert ($example.Name -ceq 'イヴンタイト') 'PC distribution card name mismatch.'
Assert ($moonConfig.Name -ceq 'イヴンタイト(Moonlight)') 'Moonlight distribution card name mismatch.'
$manifest=Get-Content (Join-Path $root 'cursor-extension/manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($manifest.manifest_version -eq 3 -and $manifest.background.type -ceq 'module') 'Unexpected helper manifest.'
Assert (($manifest.permissions -join ',') -ceq 'scripting,webNavigation,storage,alarms') 'Unexpected helper permissions.'
Assert ($manifest.host_permissions.Count -eq 2 -and -not ($manifest.host_permissions -contains '<all_urls>')) 'Broad helper host permission.'
Write-Output 'PASS: Moonlight assets, independent config, ownership/config mismatch guards. No UI launched.'
Write-Output 'PASS: syntax, JSON/CSS, config, quoted commands, window lifetime, dashboard guards, fullscreen bounds, plans. No UI launched.'
