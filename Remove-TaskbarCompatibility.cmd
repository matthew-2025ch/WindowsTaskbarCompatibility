@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Setup-TaskbarCompatibility.ps1" -Mode Remove
pause
