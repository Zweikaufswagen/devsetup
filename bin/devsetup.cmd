@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\powershell\devsetup.ps1" %*
exit /b %errorlevel%
