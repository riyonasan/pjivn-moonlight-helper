param([switch]$Restore, [switch]$Maximize, [switch]$VerifyDemadoLaunch, [switch]$Fullscreen, [string]$ConfigPath=(Join-Path $PSScriptRoot 'config.local.json'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helper-common.ps1')
$config=Read-HelperConfig $ConfigPath
$stateRoot=Initialize-StateDirectory $config
Add-Type -AssemblyName UIAutomationClient
if(-not ('PjivnWindow' -as [type])) { Add-Type @'
using System;
using System.Runtime.InteropServices;
public class PjivnWindow {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,IntPtr pid);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool attach);
 [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hwnd);
 public static bool Focus(IntPtr hwnd) {
  uint a=GetCurrentThreadId(),b=GetWindowThreadProcessId(GetForegroundWindow(),IntPtr.Zero);
  bool attached=a!=b&&AttachThreadInput(a,b,true);
  try {BringWindowToTop(hwnd);SetForegroundWindow(hwnd);return GetForegroundWindow()==hwnd;} finally {if(attached)AttachThreadInput(a,b,false);}
 }
}
'@
}
$title = ([char]0x30a4).ToString()+[char]0x30f4+[char]0x30f3+[char]0x30bf+[char]0x30a4+[char]0x30c8+' - FANZA GAMES'
function Get-GameWindows {
 $condition = New-Object System.Windows.Automation.OrCondition((New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,$title)),(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,($title+' - Google Chrome'))))
 $windows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children,$condition)
 @($windows | Where-Object { (Get-Process -Id $_.Current.ProcessId -ErrorAction SilentlyContinue).ProcessName -eq 'chrome' })
}
function Get-DesktopWindows {
 [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)
}
$dashboardOwnerPath=Join-Path $stateRoot 'dashboard-owner.json'
function Get-OwnedDashboard {
 try {
  if(-not (Test-Path -LiteralPath $dashboardOwnerPath)){return $null}
  $owner=Get-Content -LiteralPath $dashboardOwnerPath -Raw | ConvertFrom-Json
  if(-not $owner.active){return $null}
  if($config.Usage -eq 'moonlight' -and $owner.configKey -cne $config.HelperConfigKey){return $null}
  $proc=Get-Process -Id $owner.pid -ErrorAction Stop
  if($proc.ProcessName -ne 'chrome' -or -not (Test-WindowIdentity $owner $owner.handle $proc.Id $proc.StartTime.Ticks)){return $null}
  $w=[System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$owner.handle)
  if($w.Current.ProcessId -ne $owner.pid -or $w.Current.Name -ne 'demado - Google Chrome'){return $null}
  $tabs=$w.FindAll([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::TabItem)))
  if($tabs.Count -ne 1){return $null}
  $elements=$w.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
  $doc=$elements | Where-Object {$_.Current.AutomationId -eq 'RootWebArea' -and $_.Current.Name -eq 'demado'} | Select-Object -First 1
  if($null -eq $doc -or -not $owner.url){return $null}
  if(([System.Windows.Automation.ValuePattern]$doc.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value -ne $owner.url){return $null}
  $w
 }catch{return $null}
}
function Close-OwnedDashboard([string]$expectedUrl) {
 try {
  $w=Get-OwnedDashboard
  if($null -eq $w){return}
  $elements=$w.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
  $doc=$elements | Where-Object {$_.Current.AutomationId -eq 'RootWebArea' -and $_.Current.Name -eq 'demado'} | Select-Object -First 1
  if($null -eq $doc){return}
  $value=([System.Windows.Automation.ValuePattern]$doc.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value
  if($value -ne $expectedUrl){return} # Preserve options, unsaved editing, and any user-changed tab.
  ([System.Windows.Automation.WindowPattern]$w.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)).Close()
  $owner=Get-Content -LiteralPath $dashboardOwnerPath -Raw | ConvertFrom-Json
  $owner.active=$false;$owner | ConvertTo-Json | Set-Content -LiteralPath $dashboardOwnerPath
 }catch{ } # Never close any other window when identity or URL cannot be proved.
}

$targets = @(Get-GameWindows)
$statePath = Join-Path $stateRoot 'window-state.json'
if($config.Usage -eq 'moonlight') {
 foreach($existing in $targets){Assert-OwnedGameWindow $config $stateRoot $existing}
 if($VerifyDemadoLaunch -and $targets.Count -gt 0){throw 'Moonlight verification must not reinvoke a card while a game window exists.'}
}
if ($Restore) {
 if(Test-Path -LiteralPath (Join-Path $stateRoot 'fullscreen-state.json')) {
  & (Join-Path $PSScriptRoot 'fullscreen-pjivn.ps1') -ConfigPath $ConfigPath -Restore
 }
 if ($targets.Count -eq 1 -and (Test-Path -LiteralPath $statePath)) {
  $target=$targets[0]
  $pattern=$target.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
  $saved = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($saved.active -and (Test-WindowIdentity $saved $target.Current.NativeWindowHandle $target.Current.ProcessId (Get-Process -Id $target.Current.ProcessId).StartTime.Ticks)) {
   $pattern.SetWindowVisualState([System.Windows.Automation.WindowVisualState][int]$saved.visualState)
   $saved | Add-Member -NotePropertyName active -NotePropertyValue $false -Force
   $saved | ConvertTo-Json | Set-Content -LiteralPath $statePath
  }
 }
 exit 0
}
if ($targets.Count -gt 1) { throw 'More than one dedicated game window; refusing ambiguous launch.' }
$openedViaDemado=$false
if ($targets.Count -eq 0 -or $VerifyDemadoLaunch) {

 $dashboardMutex=New-Object System.Threading.Mutex($false,'Local\PjivnDemadoDashboard')
 if(-not $dashboardMutex.WaitOne(0)){$dashboardMutex.Dispose();throw 'A Demado launch is already running.'}
 $url=$null
 try {
 # CardId is recorded for manual verification; accessibility launch matches a unique Name.
 $beforeHandles=@(Get-DesktopWindows | ForEach-Object {$_.Current.NativeWindowHandle})
 $url='chrome-extension://'+$config.ExtensionId+'/index.html#dashboard'
 $reusedDashboard=Get-OwnedDashboard
 $allowedHelperHandle=0
 if($null -ne $reusedDashboard){$allowedHelperHandle=$reusedDashboard.Current.NativeWindowHandle}
 else{Start-Process -FilePath $config.ChromePath -ArgumentList (Get-ChromeArguments $config.Profile $url)}
 $dashboard=$null
 $card=$null
 $launchDiagnostic='no new target dashboard matched'
 $deadline=(Get-Date).AddSeconds(25)
 while((Get-Date) -lt $deadline -and $null -eq $card) {
  Start-Sleep -Milliseconds 750
  foreach($candidate in (Get-DesktopWindows)) {
   if((Get-Process -Id $candidate.Current.ProcessId -ErrorAction SilentlyContinue).ProcessName -ne 'chrome'){continue}
   if(($candidate.Current.NativeWindowHandle -in $beforeHandles -and $candidate.Current.NativeWindowHandle -ne $allowedHelperHandle) -or $candidate.Current.Name -ne 'demado - Google Chrome') {continue}
   if($candidate.Current.NativeWindowHandle -ne $allowedHelperHandle){
    $proc=Get-Process -Id $candidate.Current.ProcessId
    @{handle=$candidate.Current.NativeWindowHandle;pid=$proc.Id;processStartTicks=$proc.StartTime.Ticks;url=$url;active=$true;configKey=$config.HelperConfigKey} | ConvertTo-Json | Set-Content -LiteralPath $dashboardOwnerPath
    $allowedHelperHandle=$candidate.Current.NativeWindowHandle
   }
   $launchDiagnostic='matched target dashboard '+$candidate.Current.NativeWindowHandle
   if(-not [PjivnWindow]::Focus([IntPtr]$candidate.Current.NativeWindowHandle)){continue}
   # Enumerating the local helper window also activates Chrome's lazy accessibility tree.
   $elements=$candidate.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
   $doc=$elements | Where-Object {$_.Current.AutomationId -eq 'RootWebArea' -and $_.Current.Name -eq 'demado'} | Select-Object -First 1
   if($null -eq $doc) {$launchDiagnostic+='; document unavailable';continue}
   try{$documentUrl=([System.Windows.Automation.ValuePattern]$doc.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value}catch{continue}
   if($documentUrl -ne $url){continue}
   # Only this newly opened local extension dashboard is inspected; no other browser content or authentication fields.
   $texts=$doc.FindAll([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,[string]$config.Name)))
   $launchDiagnostic+='; target text count '+$texts.Count
   if($texts.Count -ne 1) {continue}
   $walker=[System.Windows.Automation.TreeWalker]::RawViewWalker
   $node=$texts[0]
   for($i=0;$i -lt 5;$i++) {
    $node=$walker.GetParent($node)
    if($null -eq $node) {break}
    if($node.GetSupportedPatterns().ProgrammaticName -contains 'InvokePatternIdentifiers.Pattern') {break}
   }
   if($null -ne $node -and $node.Current.ControlType -eq [System.Windows.Automation.ControlType]::Group -and $node.GetSupportedPatterns().ProgrammaticName -contains 'InvokePatternIdentifiers.Pattern') {
    $dashboard=$candidate
    $card=$node
    break
   }
  }
 }
 if($null -eq $card) {throw ('Demado dashboard game card not available: '+$launchDiagnostic+'. Check extension and permission prompts manually; no streaming will start.')}
 # This invokes Demado's supported default launch: reuse a matching window, or create the correctly cropped popup.
 if($config.Usage -eq 'moonlight' -and @(Get-GameWindows).Count -gt 0){throw 'A game window appeared before card launch; refusing to reuse it.'}
 ([System.Windows.Automation.InvokePattern]$card.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
 $deadline=(Get-Date).AddSeconds(35)
 do {
  Start-Sleep -Milliseconds 750
  $targets=@(Get-GameWindows)
  if($targets.Count -eq 0){
   $loginTitle=((([char[]]@(0x30ed,0x30b0,0x30a4,0x30f3)) -join '')+' - FANZA - Google Chrome')
   $loginWindows=@(Get-DesktopWindows | Where-Object {$_.Current.NativeWindowHandle -notin $beforeHandles -and $_.Current.Name -eq $loginTitle -and (Get-Process -Id $_.Current.ProcessId -ErrorAction SilentlyContinue).ProcessName -eq 'chrome'})
   if($loginWindows.Count -gt 0){throw 'FANZA login is required. Complete login manually in the opened game window. No credentials are read or entered by this launcher.'}
  }
 } while($targets.Count -eq 0 -and (Get-Date) -lt $deadline)
 if($targets.Count -ne 1) {throw 'Demado did not produce a unique game window. Complete any game login or permission prompt manually.'}
 if($config.Usage -eq 'moonlight') {
  $newGame=$targets[0]
  if($newGame.Current.NativeWindowHandle -in $beforeHandles){throw 'Demado reused an existing window; refusing to claim ownership.'}
  $proc=Get-Process -Id $newGame.Current.ProcessId
  @{handle=$newGame.Current.NativeWindowHandle;pid=$proc.Id;processStartTicks=$proc.StartTime.Ticks;configKey=$config.HelperConfigKey} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'game-owner.json')
 }
 Start-Sleep -Seconds 2
 $openedViaDemado=$true
 }finally{
  if($url){Close-OwnedDashboard $url}
  $dashboardMutex.ReleaseMutex();$dashboardMutex.Dispose()
 }
}
$target=$targets[0]
Assert-OwnedGameWindow $config $stateRoot $target
$pattern=$target.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
$previous=$null
if(Test-Path -LiteralPath $statePath){$previous=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json}
if($null -eq $previous -or -not (Test-WindowIdentity $previous $target.Current.NativeWindowHandle $target.Current.ProcessId (Get-Process -Id $target.Current.ProcessId).StartTime.Ticks) -or -not $previous.active){
 @{ handle=$target.Current.NativeWindowHandle; pid=$target.Current.ProcessId; processStartTicks=(Get-Process -Id $target.Current.ProcessId).StartTime.Ticks; visualState=[int]$pattern.Current.WindowVisualState; active=$true } | ConvertTo-Json | Set-Content -LiteralPath $statePath
}
if ($Maximize) { $pattern.SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Maximized) }
if ($Fullscreen) { & (Join-Path $PSScriptRoot 'fullscreen-pjivn.ps1') -ConfigPath $ConfigPath }
$focused = [PjivnWindow]::Focus([IntPtr]$target.Current.NativeWindowHandle)
$message='Dedicated game ready. Demado launch invoked: '+$openedViaDemado+'. Foreground: '+$focused+'. Maximize requested: '+[bool]$Maximize+'. Handle: '+$target.Current.NativeWindowHandle
Write-Output $message
