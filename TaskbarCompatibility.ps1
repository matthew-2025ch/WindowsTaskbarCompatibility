param([switch]$ValidateOnly, [switch]$Stop)
$ErrorActionPreference = 'Stop'
$sessionId = (Get-Process -Id $PID).SessionId
$eventName = 'Local\CodexSnowTaskbarFixStop-' + $sessionId
if ($Stop) {
    try { $stopEvent = [Threading.EventWaitHandle]::OpenExisting($eventName); [void]$stopEvent.Set(); $stopEvent.Dispose() } catch [Threading.WaitHandleCannotBeOpenedException] {}
    exit
}
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

public static class TaskbarCompatibility {
 const string Property = "NonRudeHWND";
 const string Owned = "CodexSnowTaskbarCompatibilityOwned";
 delegate bool EnumProc(IntPtr hwnd, IntPtr state);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr state);
 [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr GetProp(IntPtr h, string name);
 [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool SetProp(IntPtr h, string name, IntPtr value);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr RemoveProp(IntPtr h, string name);
 [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder name, int size);
 [ComImport, Guid("56FDF344-FD6D-11d0-958A-006097C9A090")] class TaskbarList {}
 [ComImport, Guid("602D4995-B13A-429b-A66E-1935E44F4317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
 interface ITaskbarList2 {
  void HrInit(); void AddTab(IntPtr h); void DeleteTab(IntPtr h); void ActivateTab(IntPtr h); void SetActiveAlt(IntPtr h);
  void MarkFullscreenWindow(IntPtr h, [MarshalAs(UnmanagedType.Bool)] bool fullscreen);
 }
 public static HashSet<string> ReadApplicationNames(string content) {
  HashSet<string> result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  int lineNumber = 0;
  using (StringReader reader = new StringReader(content)) {
   string line;
   while ((line = reader.ReadLine()) != null) {
    lineNumber++;
    string name = line.Trim();
    if (name.Length == 0 || name.StartsWith("#")) continue;
    if (name.EndsWith(".exe",StringComparison.OrdinalIgnoreCase)) name = name.Substring(0,name.Length-4).Trim();
    if (name.Length == 0 || name.IndexOfAny(new char[] {'\\','/',':','*','?','"','<','>','|'}) >= 0)
     throw new FormatException("Invalid application name on line " + lineNumber);
    result.Add(name);
   }
  }
  return result;
 }
 sealed class Context : ApplicationContext {
  readonly Dictionary<IntPtr,uint> windows = new Dictionary<IntPtr,uint>();
  readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
  readonly NotifyIcon tray = new NotifyIcon();
  readonly EventWaitHandle stop;
  readonly ITaskbarList2 taskbar;
  readonly string statusPath;
  readonly string configPath;
  HashSet<string> targets = ReadApplicationNames("chatgpt\nsnow-shot\nsnow_shot\nsnowshot\nocam");
  string lastConfig, configError = "";
  int configRevision;
  readonly Dictionary<uint,string> processNames = new Dictionary<uint,string>();
  IntPtr lastForeground = IntPtr.Zero;
  int applied, errors, ticks;
  string lastError = "";
  bool restored, scanning;
  public Context(EventWaitHandle stopEvent, string status, string config) {
   stop = stopEvent; statusPath = status; configPath = config;
   taskbar = (ITaskbarList2)new TaskbarList(); taskbar.HrInit();
   tray.Icon = SystemIcons.Application;
   tray.Text = "Windows taskbar compatibility";
   ContextMenuStrip menu = new ContextMenuStrip();
   menu.Items.Add("Edit application list", null, delegate {
    try { Process.Start("notepad.exe", "\"" + configPath + "\""); } catch { configError = "Cannot open application list"; }
   });
   menu.Items.Add("Exit and undo compatibility fix", null, delegate { ExitThread(); });
   tray.ContextMenuStrip = menu; tray.Visible = true;
   timer.Interval = 500;
   timer.Tick += delegate {
    if (stop.WaitOne(0)) { ExitThread(); return; }
    if (scanning) return;
    scanning = true;
    try { Scan(); } catch (Exception ex) { errors++; lastError = "Scan:" + ex.GetType().Name + ":" + ex.HResult; }
    finally { scanning = false; }
   };
   Scan(); timer.Start();
  }
  bool IsTarget(IntPtr h, out uint pid) {
   GetWindowThreadProcessId(h, out pid);
   string name;
   if (!processNames.TryGetValue(pid,out name)) {
    try { using(Process p = Process.GetProcessById((int)pid)) { name = p.ProcessName.ToLowerInvariant(); } }
    catch { name = ""; }
    processNames[pid] = name;
   }
   return targets.Contains(name);
  }
  bool ReloadConfiguration() {
   try {
    string content = File.ReadAllText(configPath);
    HashSet<string> next;
    if (content == lastConfig) { configError = ""; return false; }
    next = ReadApplicationNames(content);
    targets = next; lastConfig = content; configRevision++; configError = "";
    return true;
   } catch (Exception ex) { configError = "Application list: " + ex.GetType().Name; return false; }
  }
  void Reset(IntPtr h) { try { taskbar.MarkFullscreenWindow(h,false); } catch (Exception ex) { errors++; lastError = "Reset:" + ex.HResult; } }
  void RaiseTaskbars() {
   EnumWindows(delegate(IntPtr h,IntPtr unused) {
    StringBuilder name = new StringBuilder(128); GetClassName(h,name,128);
    if (name.ToString() == "Shell_TrayWnd" || name.ToString() == "Shell_SecondaryTrayWnd")
     SetWindowPos(h,new IntPtr(-1),0,0,0,0,0x13);
    return true;
   },IntPtr.Zero);
  }
  void Scan() {
   if (ticks % 20 == 0) processNames.Clear();
   bool changed = ticks % 4 == 0 && ReloadConfiguration();
   List<IntPtr> gone = new List<IntPtr>();
   foreach (KeyValuePair<IntPtr,uint> entry in windows) {
    uint current; GetWindowThreadProcessId(entry.Key,out current);
    if (!IsWindow(entry.Key) || current != entry.Value || GetProp(entry.Key,Owned) == IntPtr.Zero) gone.Add(entry.Key);
    else {
     uint targetPid;
     if (!IsTarget(entry.Key,out targetPid)) {
      RemoveProp(entry.Key,Owned); RemoveProp(entry.Key,Property); Reset(entry.Key);
      gone.Add(entry.Key); changed = true;
     }
    }
   }
   foreach(IntPtr h in gone) windows.Remove(h);
   EnumWindows(delegate(IntPtr h,IntPtr unused) {
    if (!IsWindowVisible(h)) return true;
    uint pid; if (!IsTarget(h,out pid)) return true;
    if (GetProp(h,Property) == IntPtr.Zero) {
     if (SetProp(h,Property,new IntPtr(1))) {
      if (!SetProp(h,Owned,new IntPtr(1))) { lastError = "Owned:" + Marshal.GetLastWin32Error(); RemoveProp(h,Property); errors++; return true; }
      windows[h] = pid; applied++; Reset(h); changed = true;
     } else { errors++; lastError = "SetProp:" + Marshal.GetLastWin32Error(); }
    } else if (GetProp(h,Owned) != IntPtr.Zero) windows[h] = pid;
    return true;
   },IntPtr.Zero);
   IntPtr foreground = GetForegroundWindow();
   if (foreground != lastForeground) {
    if (windows.ContainsKey(foreground)) { Reset(foreground); changed = true; }
    lastForeground = foreground;
   }
   if (changed) RaiseTaskbars();
   if (++ticks % 10 == 0 || changed) SaveStatus();
  }
  void SaveStatus() {
   try {
    File.WriteAllText(statusPath,"{\"pid\":" + Process.GetCurrentProcess().Id + ",\"managedWindows\":" + windows.Count + ",\"applied\":" + applied + ",\"errors\":" + errors + ",\"lastError\":\"" + lastError + "\",\"configuredApplications\":" + targets.Count + ",\"configRevision\":" + configRevision + ",\"configError\":\"" + configError + "\",\"updatedUtc\":\"" + DateTime.UtcNow.ToString("o") + "\"}");
   } catch {}
  }
  void Restore() {
   if (restored) return; restored = true; timer.Stop();
   foreach(KeyValuePair<IntPtr,uint> entry in windows) {
    uint current; GetWindowThreadProcessId(entry.Key,out current);
    if (current == entry.Value && GetProp(entry.Key,Owned) != IntPtr.Zero) {
     RemoveProp(entry.Key,Owned); RemoveProp(entry.Key,Property); Reset(entry.Key);
    }
   }
   tray.Visible = false; tray.Dispose(); timer.Dispose();
   Marshal.ReleaseComObject(taskbar);
   try { File.Delete(statusPath); } catch {}
  }
  protected override void ExitThreadCore() { Restore(); base.ExitThreadCore(); }
  protected override void Dispose(bool disposing) { if(disposing) Restore(); base.Dispose(disposing); }
 }
 public static void Run(string statusPath, int sessionId, string configPath) {
  bool created;
  using(Mutex mutex = new Mutex(true,"Local\\CodexSnowTaskbarFix-" + sessionId,out created)) {
   if (!created) return;
   try {
    using(EventWaitHandle stop = new EventWaitHandle(false,EventResetMode.ManualReset,"Local\\CodexSnowTaskbarFixStop-" + sessionId)) {
     stop.Reset(); Application.EnableVisualStyles();
     using(Context context = new Context(stop,statusPath,configPath)) Application.Run(context);
    }
   } finally { mutex.ReleaseMutex(); }
  }
 }
}
'@
if ($ValidateOnly) {
    $names = [TaskbarCompatibility]::ReadApplicationNames([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'apps.txt')))
    'Compilation OK; configured applications: ' + $names.Count
    return
}
$runtimeDirectory = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
[TaskbarCompatibility]::Run((Join-Path $runtimeDirectory 'status.json'), $sessionId, (Join-Path $PSScriptRoot 'apps.txt'))
