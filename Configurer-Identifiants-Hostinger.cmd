@echo off
cd /d "%~dp0"
set "HOSTINGER_FTP_USER=u249558677.sct-africa.site"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\enregistrer_identifiants_hostinger.ps1" -User "%HOSTINGER_FTP_USER%"
echo.
pause