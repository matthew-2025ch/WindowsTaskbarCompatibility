param([switch]$Integration)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $projectRoot 'TaskbarCompatibility.ps1') -ValidateOnly
function Assert-True($Condition, $Message) { if (-not $Condition) { throw $Message } }
$parsed = [TaskbarCompatibility]::ReadApplicationNames("# comment`n Example.EXE `nexample`nsecond-app.exe`n")
Assert-True ($parsed.Count -eq 2 -and $parsed.Contains('EXAMPLE') -and $parsed.Contains('second-app')) 'Name normalization failed'
Assert-True ([TaskbarCompatibility]::ReadApplicationNames("# empty`n").Count -eq 0) 'Empty list failed'
foreach ($bad in @('C:\Apps\example.exe','*.exe','.exe')) {
    $rejected = $false
    try { [void][TaskbarCompatibility]::ReadApplicationNames($bad) } catch { $rejected = $true }
    Assert-True $rejected ('Invalid entry accepted: ' + $bad)
}
'Parser checks passed'
if (-not $Integration) { return }
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TaskbarConfigTestWindow {
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr CreateWindowEx(uint ex,string cls,string title,uint style,int x,int y,int w,int h,IntPtr parent,IntPtr menu,IntPtr instance,IntPtr param);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr h,string name);
 [DllImport("user32.dll")] public static extern bool DestroyWindow(IntPtr h);
}
'@
$configPath = Join-Path $projectRoot 'apps.txt'
$statusPath = Join-Path $projectRoot 'runtime\status.json'
$original = [IO.File]::ReadAllText($configPath)
$testName = (Get-Process -Id $PID).ProcessName
$testWindow = [TaskbarConfigTestWindow]::CreateWindowEx(0x08000080,'STATIC','Taskbar configuration test',[uint32]2415919104,-30000,-30000,1,1,[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero)
Assert-True ($testWindow -ne [IntPtr]::Zero) 'Cannot create offscreen test window'
function Wait-For($Check, $Message) {
    for ($i=0; $i -lt 50; $i++) {
        if (& $Check) { return }
        Start-Sleep -Milliseconds 200
    }
    throw $Message
}
try {
    $before = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    [IO.File]::WriteAllText($configPath,($original + "`n" + $testName + ".exe`n"))
    Wait-For { [TaskbarConfigTestWindow]::GetProp($testWindow,'CodexSnowTaskbarCompatibilityOwned') -ne [IntPtr]::Zero } 'New application was not applied'
    $loaded = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    Assert-True ($loaded.pid -eq $before.pid -and $loaded.configRevision -gt $before.configRevision) 'Configuration did not reload in the existing process'
    [IO.File]::WriteAllText($configPath,"C:\invalid\application.exe`n")
    Wait-For { (Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json).configError -ne '' } 'Invalid configuration was not reported'
    Assert-True ([TaskbarConfigTestWindow]::GetProp($testWindow,'NonRudeHWND') -ne [IntPtr]::Zero) 'Invalid configuration discarded the active list'
    [IO.File]::WriteAllText($configPath,$original)
    Wait-For { [TaskbarConfigTestWindow]::GetProp($testWindow,'NonRudeHWND') -eq [IntPtr]::Zero } 'Removed application retained compatibility properties'
    Wait-For { (Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json).configError -eq '' } 'Configuration error did not clear'
    'Integration checks passed: add, reload without restart, invalid configuration retention, removal and recovery'
} finally {
    [IO.File]::WriteAllText($configPath,$original)
    [void][TaskbarConfigTestWindow]::DestroyWindow($testWindow)
}
