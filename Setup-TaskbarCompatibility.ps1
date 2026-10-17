param([ValidateSet('Install','Remove')][string]$Mode = 'Install')
$ErrorActionPreference = 'Stop'
$helperPath = Join-Path $PSScriptRoot 'TaskbarCompatibility.ps1'
$linkPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex-SnowShot-TaskbarCompatibility.lnk'
$powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shell = New-Object -ComObject WScript.Shell
if (Test-Path -LiteralPath $linkPath) {
    $existing = $shell.CreateShortcut($linkPath)
    if ($existing.Arguments -notlike ('*"' + $helperPath + '"*')) {
        throw 'A different shortcut already uses this name. No changes made.'
    }
}
if ($Mode -eq 'Remove') {
    if (Test-Path -LiteralPath $linkPath) { Remove-Item -LiteralPath $linkPath }
    & $helperPath -Stop
    'Autostart removed. Compatibility helper stopped.'
} else {
    $shortcut = $shell.CreateShortcut($linkPath)
    $shortcut.TargetPath = $powerShellPath
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $helperPath + '"'
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.WindowStyle = 7
    $shortcut.Description = 'Auto-hide taskbar compatibility for Codex, Snow Shot and oCam. Exit via tray icon.'
    $shortcut.Save()
    Start-Process -FilePath $powerShellPath -WindowStyle Hidden -ArgumentList $shortcut.Arguments
    'Autostart enabled. Compatibility helper running.'
}
[void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
