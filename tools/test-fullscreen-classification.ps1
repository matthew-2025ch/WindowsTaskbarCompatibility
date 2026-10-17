Add-Type @'
using System;
using System.Runtime.InteropServices;
public class FullscreenClassification {
 [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern bool SetProp(IntPtr h,string name,IntPtr value);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr h,string name);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c,string t);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int z,uint f);
 [ComImport,Guid("56FDF344-FD6D-11d0-958A-006097C9A090")] public class TaskbarList {}
 [ComImport,Guid("602D4995-B13A-429b-A66E-1935E44F4317"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 public interface ITaskbarList2 {
 void HrInit(); void AddTab(IntPtr h); void DeleteTab(IntPtr h); void ActivateTab(IntPtr h); void SetActiveAlt(IntPtr h);
 void MarkFullscreenWindow(IntPtr h,[MarshalAs(UnmanagedType.Bool)] bool fullscreen);
 }
 public static void Reset(IntPtr h) { var t=(ITaskbarList2)new TaskbarList(); t.HrInit(); t.MarkFullscreenWindow(h,false); Marshal.ReleaseComObject(t); }
}
'@
$hwnd=[FullscreenClassification]::GetForegroundWindow()
$old=[FullscreenClassification]::GetProp($hwnd,'NonRudeHWND')
$set=[FullscreenClassification]::SetProp($hwnd,'NonRudeHWND',[IntPtr]1)
[FullscreenClassification]::Reset($hwnd)
$bar=[FullscreenClassification]::FindWindow('Shell_TrayWnd',$null)
[void][FullscreenClassification]::SetWindowPos($bar,[IntPtr](-1),0,0,0,0,0x13)
[pscustomobject]@{Window=$hwnd.ToInt64();PreviousProperty=$old.ToInt64();SetProperty=$set;CurrentProperty=[FullscreenClassification]::GetProp($hwnd,'NonRudeHWND').ToInt64()} | ConvertTo-Json
& "$PSScriptRoot/inspect-taskbar.ps1"
