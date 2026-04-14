@echo off
cd /d "%~dp0"
set "HOSTINGER_FTP_USER=u249558677.sct-africa.site"
title Publication Hostinger SCT Africa
echo Publication simple du site SCT Africa...
echo Le flux regenere deploy, synchronise public_html, publie via WinSCP,
echo verifie la reponse HTTP.
echo Les identifiants FTP enregistres seront reutilises automatiquement.
echo.
echo Lancement du flux one-click...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Executer-Mise-En-Ligne.ps1" -User "%HOSTINGER_FTP_USER%"
exit /b %ERRORLEVEL%
