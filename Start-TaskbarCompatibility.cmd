@echo off
powershell.exe -NoProfile -Command "Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ""%~dp0TaskbarCompatibility.ps1""'"
