Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class TaskbarInspect {
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr p);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr h, int i);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
 [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
 [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr result);
 [DllImport("shell32.dll")] public static extern UIntPtr SHAppBarMessage(uint m, ref APPBARDATA d);
 public struct POINT { public int x,y; }
 public struct RECT { public int left,top,right,bottom; }
 public struct APPBARDATA { public uint cbSize; public IntPtr hWnd; public uint uCallbackMessage,uEdge; public RECT rc; public IntPtr lParam; }
}
'@
$items = [System.Collections.Generic.List[object]]::new()
$foreground = [TaskbarInspect]::GetForegroundWindow()
$cb = [TaskbarInspect+EnumProc]{ param($hwnd,$arg)
 $sb = [Text.StringBuilder]::new(256)
 [void][TaskbarInspect]::GetClassName($hwnd,$sb,256)
 [uint32]$windowPid = 0
 [void][TaskbarInspect]::GetWindowThreadProcessId($hwnd,[ref]$windowPid)
 $proc = Get-Process -Id $windowPid -ErrorAction SilentlyContinue
 if (($sb.ToString() -match 'Shell_TrayWnd|Shell_SecondaryTrayWnd') -or ([TaskbarInspect]::IsWindowVisible($hwnd) -and $proc.ProcessName -match 'ChatGPT|snow|ocam')) {
  $rect = [TaskbarInspect+RECT]::new()
  [void][TaskbarInspect]::GetWindowRect($hwnd,[ref]$rect)
  $items.Add([pscustomobject]@{Handle=$hwnd.ToInt64();Process=$proc.ProcessName;Class=$sb.ToString();Visible=[TaskbarInspect]::IsWindowVisible($hwnd);Maximized=[TaskbarInspect]::IsZoomed($hwnd);Foreground=($hwnd -eq $foreground);Rect=$rect;Style=('0x{0:X}' -f [TaskbarInspect]::GetWindowLongPtr($hwnd,-16).ToInt64());ExStyle=('0x{0:X}' -f [TaskbarInspect]::GetWindowLongPtr($hwnd,-20).ToInt64())})
 }
 return $true
}
[void][TaskbarInspect]::EnumWindows($cb,[IntPtr]::Zero)
$pt = [TaskbarInspect+POINT]::new()
$pt.x = [int]([TaskbarInspect]::GetSystemMetrics(0)/2)
$pt.y = [TaskbarInspect]::GetSystemMetrics(1)-1
$edgeWindow = [TaskbarInspect]::WindowFromPoint($pt)
$result = [IntPtr]::Zero
$packed = [IntPtr](($pt.y -shl 16) -bor ($pt.x -band 0xffff))
[void][TaskbarInspect]::SendMessageTimeout($edgeWindow,0x84,[IntPtr]::Zero,$packed,2,500,[ref]$result)
$bar = [TaskbarInspect+APPBARDATA]::new()
$bar.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($bar)
$os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
[pscustomobject]@{OS=$os.ProductName;Build=($os.CurrentBuild+'.'+$os.UBR);Session=(Get-Process -Id $PID).SessionId;ScreenWidth=[TaskbarInspect]::GetSystemMetrics(0);ScreenHeight=[TaskbarInspect]::GetSystemMetrics(1);TaskbarState=[TaskbarInspect]::SHAppBarMessage(4,[ref]$bar).ToUInt64();BottomWindow=$edgeWindow.ToInt64();BottomHitTest=$result.ToInt64();Windows=$items} | ConvertTo-Json -Depth 5
