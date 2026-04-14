@echo off
cd /d "%~dp0"
call ".\Publier-Site-Final.cmd"
exit /b %ERRORLEVEL%
