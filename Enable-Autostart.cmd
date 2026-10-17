@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-TaskbarCompatibility.ps1" -Mode Install
pause
