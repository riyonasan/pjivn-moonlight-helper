function Read-HelperConfig([string]$Path) {
 $resolved=(Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
 $c=Get-Content -LiteralPath $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
 foreach($field in @('Profile','ExtensionId','CardId','Name','SunshineConfigPath')) {
  if([string]::IsNullOrWhiteSpace([string]$c.$field)){throw "Missing configuration: $field"}
 }
 if($c.Profile -notmatch '^[A-Za-z0-9 _-]+$'){throw 'Profile must be a Chrome profile directory name, not a path.'}
 if($c.ExtensionId -notmatch '^[a-p]{32}$'){throw 'Invalid Chrome extension ID.'}
 if($c.CardId -eq 'REPLACE_AFTER_IMPORT' -or $c.CardId -notmatch '^[a-z0-9]+$'){throw 'Record the imported Demado card ID in CardId first.'}
 if([string]$c.Name -match '[\r\n]'){throw 'Invalid game card name.'}
 if([string]::IsNullOrWhiteSpace([string]$c.ChromePath)) {
  $c.ChromePath=@(
   (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
   (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
   (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
  ) | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf} | Select-Object -First 1
 }
 if(-not $c.ChromePath -or -not (Test-Path -LiteralPath $c.ChromePath -PathType Leaf)){throw 'Set ChromePath to an existing chrome.exe.'}
 if([IO.Path]::GetFileName($c.ChromePath) -ne 'chrome.exe'){throw 'ChromePath must point to chrome.exe.'}
 if(-not [IO.Path]::IsPathRooted($c.ChromePath) -or -not [IO.Path]::IsPathRooted($c.SunshineConfigPath)){throw 'Use absolute paths in ChromePath and SunshineConfigPath.'}
 if($c.PSObject.Properties['Usage'] -and $c.Usage -notin @('pc','moonlight')){throw 'Usage must be pc or moonlight.'}
 # A changed config or config location must never adopt a previously owned window.
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($resolved.ToLowerInvariant()+"`n"+(Get-Content -LiteralPath $resolved -Raw -Encoding UTF8))))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
 $c | Add-Member -NotePropertyName HelperConfigKey -NotePropertyValue $key
 $c
}

function Initialize-StateDirectory($Config) {
 $path=Join-Path $PSScriptRoot '.local'
 if($Config.Usage -eq 'moonlight'){$path=Join-Path $path ('moonlight-'+$Config.HelperConfigKey)}
 [void](New-Item -ItemType Directory -Path $path -Force)
 $path
}

function Test-WindowIdentity($Saved,[long]$Handle,[int]$ProcessId,[long]$StartTicks) {
 return ($null -ne $Saved -and $Saved.handle -eq $Handle -and $Saved.pid -eq $ProcessId -and $Saved.processStartTicks -eq $StartTicks)
}

function Get-ChromeArguments([string]$Profile,[string]$Url) {
 if($Profile -notmatch '^[A-Za-z0-9 _-]+$' -or $Url -notmatch '^chrome-extension://[a-p]{32}/index\.html#dashboard$'){throw 'Invalid Chrome arguments.'}
 # Start-Process joins array arguments without preserving their quoting.
 '--profile-directory="'+$Profile+'" --new-window "'+$Url+'"'
}

function Get-PrepCommands([string]$RepositoryPath,[string]$ConfigPath) {
 foreach($p in @($RepositoryPath,$ConfigPath)) {
  if($p -match '["\r\n]' -or -not [IO.Path]::IsPathRooted($p)){throw 'Command paths must be absolute and contain no quote or newline.'}
 }
 $script=Join-Path $RepositoryPath 'launch-pjivn.ps1'
 $base='powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+$script+'" -ConfigPath "'+$ConfigPath+'"'
 [pscustomobject]@{do=$base+' -Fullscreen';undo=$base+' -Restore'}
}

function Test-GameOwnership($Owner,$Config,[long]$Handle,[int]$ProcessId,[long]$StartTicks) {
 return ($null -ne $Owner -and $Owner.configKey -ceq $Config.HelperConfigKey -and
  (Test-WindowIdentity $Owner $Handle $ProcessId $StartTicks))
}

function Assert-OwnedGameWindow($Config,[string]$StateRoot,$Window) {
 if($Config.Usage -ne 'moonlight'){return}
 $ownerPath=Join-Path $StateRoot 'game-owner.json'
 if(-not (Test-Path -LiteralPath $ownerPath)){throw 'Unowned game window: leave the PC window unchanged and close it manually before Moonlight launch.'}
 $owner=Get-Content -LiteralPath $ownerPath -Raw | ConvertFrom-Json
 $proc=Get-Process -Id $Window.Current.ProcessId -ErrorAction Stop
 if($proc.ProcessName -ne 'chrome' -or -not (Test-GameOwnership $owner $Config $Window.Current.NativeWindowHandle $proc.Id $proc.StartTime.Ticks)){
  throw 'Game window ownership/config mismatch; refusing to change the PC window.'
 }
}
