param([switch]$Elevated, [switch]$Stop)
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($Elevated) { throw 'Administrator approval was not granted.' }
    $powershellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $PSCommandPath + '" -Elevated'
    if ($Stop) { $arguments += ' -Stop' }
    Start-Process -FilePath $powershellPath -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments
    return
}
$sessionId = (Get-Process -Id $PID).SessionId
$eventName = 'Local\CodexSnowTaskbarFixStop-' + $sessionId
$mutexName = 'Local\CodexSnowTaskbarFix-' + $sessionId
try {
    $stopEvent = [Threading.EventWaitHandle]::OpenExisting($eventName)
    [void]$stopEvent.Set()
    $stopEvent.Dispose()
} catch [Threading.WaitHandleCannotBeOpenedException] {}
try {
    $mutex = [Threading.Mutex]::OpenExisting($mutexName)
    $owned = $false
    try {
        try { $owned = $mutex.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) { throw 'Existing helper did not stop within 15 seconds.' }
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
} catch [Threading.WaitHandleCannotBeOpenedException] {}
if (-not $Stop) { & (Join-Path $PSScriptRoot 'TaskbarCompatibility.ps1') }
