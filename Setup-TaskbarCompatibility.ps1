param([ValidateSet('Install','Remove')][string]$Mode = 'Install', [switch]$Elevated)
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$runtimePath = Join-Path $PSScriptRoot 'runtime'
$resultPath = Join-Path $runtimePath 'setup-result.json'
New-Item -ItemType Directory -Path $runtimePath -Force | Out-Null
if (-not $isAdmin) {
    if ($Elevated) { throw 'Administrator approval was not granted.' }
    $arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $PSCommandPath + '" -Mode ' + $Mode + ' -Elevated'
    $installer = Start-Process -FilePath $powerShellPath -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -PassThru -Wait
    if ($installer.ExitCode -ne 0) {
        if (Test-Path -LiteralPath $resultPath) { Write-Host ([IO.File]::ReadAllText($resultPath)) }
        throw ('Administrator setup failed with exit code ' + $installer.ExitCode)
    }
    Write-Host ('Administrator autostart ' + $Mode.ToLowerInvariant() + ' completed.')
    return
}
$taskName = 'WindowsTaskbarCompatibility'
$marker = 'WindowsTaskbarCompatibility.ManagedTask.v1'
$userSid = $identity.User.Value
$launcherPath = Join-Path $PSScriptRoot 'Start-TaskbarCompatibility-Admin.ps1'
function Remove-LegacyShortcut {
    $linkPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex-SnowShot-TaskbarCompatibility.lnk'
    if (-not (Test-Path -LiteralPath $linkPath)) { return }
    $shell = New-Object -ComObject WScript.Shell
    try {
        $link = $shell.CreateShortcut($linkPath)
        $isOurs = [IO.Path]::GetFileName($link.TargetPath) -ieq 'powershell.exe' -and
            $link.Arguments -match '(?i)-File\s+"[^\"]*\\TaskbarCompatibility\.ps1"' -and
            $link.Description -like '*taskbar compatibility*'
        if ($isOurs) { Remove-Item -LiteralPath $linkPath }
        else { throw 'Legacy shortcut ownership could not be verified; it was not removed.' }
    } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
}
try {
    if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) { throw 'Administrator launcher is missing.' }
    $scheduler = New-Object -ComObject 'Schedule.Service'
    $scheduler.Connect()
    $folder = $scheduler.GetFolder('\')
    $existing = $null
    try { $existing = $folder.GetTask($taskName) }
    catch { if ($_.Exception.GetBaseException().HResult -ne -2147024894) { throw } }
    if ($null -ne $existing -and $existing.Definition.Data -ne $marker) {
        throw 'Another scheduled task already uses this name; no changes made.'
    }
    if ($Mode -eq 'Remove') {
        if ($null -ne $existing) { $folder.DeleteTask($taskName,0) }
        Remove-LegacyShortcut
        & $launcherPath -Elevated -Stop
        $message = 'Administrator login task removed. Compatibility helper stopped.'
    } else {
        $definition = $scheduler.NewTask(0)
        $definition.Data = $marker
        $definition.RegistrationInfo.Description = 'Auto-hide taskbar compatibility for configured applications, running as the logged-in user with highest privileges.'
        $definition.RegistrationInfo.Author = $identity.Name
        $definition.Principal.UserId = $userSid
        $definition.Principal.LogonType = 3
        $definition.Principal.RunLevel = 1
        $trigger = $definition.Triggers.Create(9)
        $trigger.UserId = $userSid
        $trigger.Delay = 'PT3S'
        $trigger.Enabled = $true
        $action = $definition.Actions.Create(0)
        $action.Path = $powerShellPath
        $action.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $launcherPath + '" -Elevated'
        $action.WorkingDirectory = $PSScriptRoot
        $definition.Settings.Enabled = $true
        $definition.Settings.StartWhenAvailable = $true
        $definition.Settings.AllowDemandStart = $true
        $definition.Settings.DisallowStartIfOnBatteries = $false
        $definition.Settings.StopIfGoingOnBatteries = $false
        $definition.Settings.ExecutionTimeLimit = 'PT0S'
        $definition.Settings.MultipleInstances = 2
        $definition.Settings.RestartCount = 3
        $definition.Settings.RestartInterval = 'PT1M'
        $task = $folder.RegisterTaskDefinition($taskName,$definition,6,$userSid,$null,3)
        Remove-LegacyShortcut
        [void]$task.Run($null)
        $message = 'Administrator login task enabled and started.'
    }
    [pscustomobject]@{Success=$true;Mode=$Mode;TaskName=$taskName;Message=$message} | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Write-Host $message
} catch {
    [pscustomobject]@{Success=$false;Mode=$Mode;Message=$_.Exception.Message;Line=$_.InvocationInfo.ScriptLineNumber} | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
    throw
}
