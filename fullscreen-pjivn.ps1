param([switch]$Restore,[switch]$PlanOnly,[switch]$TestRollback,[int]$Width=2560,[int]$Height=1440,[string]$ConfigPath=(Join-Path $PSScriptRoot 'config.local.json'))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'helper-common.ps1')
if($PlanOnly){if([math]::Abs($Width/$Height-16/9) -gt 0.001){throw 'Target display must be 16:9.'};[pscustomobject]@{Width=$Width;Height=$Height;CssScale=$Width/1280;BrowserZoomChanged=$false;ChangesDisplayResolution=$false;Capture='Entire display'} | ConvertTo-Json;return}
$config=Read-HelperConfig $ConfigPath
$stateRoot=Initialize-StateDirectory
Add-Type -AssemblyName UIAutomationClient,System.Windows.Forms
if(-not ('PjivnNative' -as [type])){Add-Type @'
using System;using System.Runtime.InteropServices;
public class PjivnNative {
 [StructLayout(LayoutKind.Sequential)]public struct POINT{public int x,y;}
 [StructLayout(LayoutKind.Sequential)]public struct RECT{public int left,top,right,bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct PLACEMENT{public int length,flags,showCmd;public POINT min,max;public RECT normal;}
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool BringWindowToTop(IntPtr h);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,IntPtr p);
 [DllImport("kernel32.dll")]public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")]public static extern bool AttachThreadInput(uint a,uint b,bool c);
 [DllImport("user32.dll")]public static extern bool GetWindowPlacement(IntPtr h,ref PLACEMENT p);
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")]public static extern bool SetWindowPlacement(IntPtr h,ref PLACEMENT p);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int z,uint f);
 [DllImport("user32.dll")]public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 public static bool Focus(IntPtr h){uint a=GetCurrentThreadId(),b=GetWindowThreadProcessId(GetForegroundWindow(),IntPtr.Zero);bool c=a!=b&&AttachThreadInput(a,b,true);try{BringWindowToTop(h);SetForegroundWindow(h);return GetForegroundWindow()==h;}finally{if(c)AttachThreadInput(a,b,false);}}
 public static bool RestorePlacement(IntPtr h,int flags,int show,int left,int top,int right,int bottom,int minX,int minY,int maxX,int maxY){PLACEMENT p=new PLACEMENT();p.length=Marshal.SizeOf(typeof(PLACEMENT));p.flags=flags;p.showCmd=show;p.normal.left=left;p.normal.top=top;p.normal.right=right;p.normal.bottom=bottom;p.min.x=minX;p.min.y=minY;p.max.x=maxX;p.max.y=maxY;return SetWindowPlacement(h,ref p);}
}
'@}
$title=([char]0x30a4).ToString()+[char]0x30f4+[char]0x30f3+[char]0x30bf+[char]0x30a4+[char]0x30c8+' - FANZA GAMES'
$allowedTitles=@($title,($title+' - Google Chrome'))
$condition=New-Object System.Windows.Automation.OrCondition((New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,$allowedTitles[0])),(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,$allowedTitles[1])))
$windows=@([System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children,$condition) | Where-Object {(Get-Process -Id $_.Current.ProcessId -ErrorAction SilentlyContinue).ProcessName -eq 'chrome'})
$statePath=Join-Path $stateRoot 'fullscreen-state.json'
if($Restore -and $windows.Count -eq 0){return}
if($windows.Count -ne 1){throw 'Expected exactly one dedicated game window.'}
$hwnd=[IntPtr]$windows[0].Current.NativeWindowHandle;$process=Get-Process -Id $windows[0].Current.ProcessId
$mutex=New-Object System.Threading.Mutex($false,'Local\PjivnFullscreenLauncher')
if(-not $mutex.WaitOne(0)){$mutex.Dispose();throw 'Another fullscreen operation is running.'}
function Get-GameWindow{[System.Windows.Automation.AutomationElement]::FromHandle($hwnd)}
function Focus-Game{if((Get-GameWindow).Current.Name -notin $allowedTitles -or (Get-GameWindow).Current.ProcessId -ne $process.Id -or (Get-Process -Id $process.Id).StartTime.Ticks -ne $process.StartTime.Ticks){throw 'Window identity changed.'};for($i=0;$i -lt 5;$i++){if([PjivnNative]::Focus($hwnd)){return};Start-Sleep -Milliseconds 200};throw 'Cannot focus exact game window.'}
function Toggle-Fullscreen{

 Focus-Game
 if(Test-Fullscreen){
  $p=New-Object PjivnNative+POINT;[void][PjivnNative]::GetCursorPos([ref]$p)
  $b=[System.Windows.Forms.Screen]::FromHandle($hwnd).Bounds;$x=$b.X+[int]($b.Width/2);$y=$b.Y+1
  try{
   [void][PjivnNative]::SetCursorPos($x,$y);Start-Sleep -Milliseconds 750
   $prefix=([char[]]@(0x5168,0x753b,0x9762)) -join ''
   $buttons=@((Get-GameWindow).FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition) | Where-Object {$_.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -and $_.Current.Name.StartsWith($prefix) -and -not $_.Current.IsOffscreen})
   if($buttons.Count -ne 1){throw 'Chrome fullscreen exit button unavailable.'}
   ([System.Windows.Automation.InvokePattern]$buttons[0].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
  }finally{$cursor=New-Object PjivnNative+POINT;[void][PjivnNative]::GetCursorPos([ref]$cursor);if($cursor.x -eq $x -and $cursor.y -eq $y){[void][PjivnNative]::SetCursorPos($p.x,$p.y)}}
 }else{

  $w=Get-GameWindow;$all=$w.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
  $button=$all | Where-Object {$_.Current.AutomationId -eq 'view_1007'} | Select-Object -First 1
  if($null -eq $button){throw 'Dedicated game must have Chrome standard menu enabled.'}
  ([System.Windows.Automation.ExpandCollapsePattern]$button.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)).Expand();Start-Sleep -Milliseconds 250

  $items=@($w.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition) | Where-Object {$_.Current.ControlType -eq [System.Windows.Automation.ControlType]::MenuItem -and $_.Current.Name -match 'F11$'})
  if($items.Count -ne 1){throw 'Unambiguous Chrome fullscreen command unavailable.'}
  ([System.Windows.Automation.InvokePattern]$items[0].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
 }
 Start-Sleep -Milliseconds 500
}
function Test-MonitorBounds($r,$b){
 ([math]::Abs($r.left-$b.Left) -le 2 -and [math]::Abs($r.top-$b.Top) -le 2 -and [math]::Abs($r.right-$b.Right) -le 2 -and [math]::Abs($r.bottom-$b.Bottom) -le 2)
}
function Test-Fullscreen{
 # Chrome document accessibility bounds can use CSS pixels after scaling.
 # Compare the native top-level window and monitor in the same coordinate space.
 $r=New-Object PjivnNative+RECT
 if(-not [PjivnNative]::GetWindowRect($hwnd,[ref]$r)){throw 'Cannot read game window bounds.'}
 $b=[System.Windows.Forms.Screen]::FromHandle($hwnd).Bounds
 if(-not (Test-MonitorBounds $r $b)){return $false}
 $menus=@((Get-GameWindow).FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition) | Where-Object {$_.Current.AutomationId -eq 'view_1007' -and -not $_.Current.IsOffscreen})
 return ($menus.Count -eq 0)
}
function Apply-Snapshot($saved){
 Focus-Game;if(Test-Fullscreen){Toggle-Fullscreen}
 $p=$saved.placement
 if(-not [PjivnNative]::RestorePlacement($hwnd,[int]$p.flags,[int]$p.showCmd,[int]$p.normal.left,[int]$p.normal.top,[int]$p.normal.right,[int]$p.normal.bottom,[int]$p.min.x,[int]$p.min.y,[int]$p.max.x,[int]$p.max.y)){throw 'Placement restoration failed.'}
 Start-Sleep -Milliseconds 300;if($saved.fullscreen){Toggle-Fullscreen}
}
try{
 if($Restore -and -not (Test-Path -LiteralPath $statePath)){return};$saved=$null
 if(Test-Path -LiteralPath $statePath){$c=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json;if((Test-WindowIdentity $c $hwnd.ToInt64() $process.Id $process.StartTime.Ticks) -and $c.active){$saved=$c}}
 if($Restore -and $null -eq $saved){return};Focus-Game;Start-Sleep -Milliseconds 300
 if($Restore){Apply-Snapshot $saved;$saved.active=$false;$saved | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath;Write-Output 'Original fullscreen and placement restored; browser zoom untouched.';return}
 $config=Get-Content -LiteralPath $config.SunshineConfigPath -Raw
 if($config -match '(?m)^\s*output_name\s*=\s*\S+'){throw 'Explicit Sunshine display selection requires review.'}
 $screen=[System.Windows.Forms.Screen]::PrimaryScreen
 if([math]::Abs($screen.Bounds.Width/$screen.Bounds.Height-16/9) -gt 0.001){throw 'Default capture display must be 16:9.'}
 if($null -eq $saved){$p=New-Object PjivnNative+PLACEMENT;$p.length=[Runtime.InteropServices.Marshal]::SizeOf($p);if(-not [PjivnNative]::GetWindowPlacement($hwnd,[ref]$p)){throw 'Cannot save placement.'};$saved=[pscustomobject]@{handle=$hwnd.ToInt64();pid=$process.Id;processStartTicks=$process.StartTime.Ticks;fullscreen=(Test-Fullscreen);placement=$p;active=$true;method='responsive-css-chrome-menu'};$saved | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath}
 try{

  $isFull=(Test-Fullscreen) -and [System.Windows.Forms.Screen]::FromHandle($hwnd).DeviceName -eq $screen.DeviceName
  if(-not $isFull){
   if(Test-Fullscreen){Toggle-Fullscreen}
   ([System.Windows.Automation.WindowPattern](Get-GameWindow).GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)).SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Normal)
   $r=(Get-GameWindow).Current.BoundingRectangle
   if(-not [PjivnNative]::SetWindowPos($hwnd,[IntPtr]::Zero,$screen.Bounds.X+100,$screen.Bounds.Y+100,[int]$r.Width,[int]$r.Height,0x4)){throw 'Cannot move game to capture display.'}
   Start-Sleep -Milliseconds 300;Toggle-Fullscreen
  }
  Focus-Game
  $deadline=(Get-Date).AddSeconds(3)
  do{$ready=(Test-Fullscreen) -and [System.Windows.Forms.Screen]::FromHandle($hwnd).DeviceName -eq $screen.DeviceName;if($ready){break};Start-Sleep -Milliseconds 250}while((Get-Date) -lt $deadline)
  if(-not $ready){$w=Get-GameWindow;throw ('Game did not fill capture display. Window='+$w.Current.BoundingRectangle.ToString()+'; actual display='+[System.Windows.Forms.Screen]::FromHandle($hwnd).DeviceName+'; target='+$screen.DeviceName)}
  if($TestRollback){throw 'Intentional rollback verification failure.'}
  Write-Output ('Game fullscreen ready on '+$screen.DeviceName+' '+$screen.Bounds.Width+'x'+$screen.Bounds.Height+'; responsive CSS; zoom untouched; entire display captured.')
 }catch{$failure=$_;try{Apply-Snapshot $saved;$saved.active=$false;$saved | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath}catch{Write-Warning 'Restore incomplete; original placement retained in fullscreen-state.json.'};throw $failure}
}finally{$mutex.ReleaseMutex();$mutex.Dispose()}
