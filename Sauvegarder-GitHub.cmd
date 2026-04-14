@echo off
setlocal

cd /d "%~dp0"

set "GIT_EXE=git"
if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_EXE=%ProgramFiles%\Git\cmd\git.exe"

set "COMMIT_MESSAGE=%*"
if not defined COMMIT_MESSAGE (
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "STAMP=%%i"
    set "COMMIT_MESSAGE=Backup %STAMP%"
)

echo.
echo [1/3] Verification du depot Git...
%GIT_EXE% rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo Ce dossier n'est pas un depot Git.
    exit /b 1
)

echo.
echo [2/3] Ajout des fichiers...
%GIT_EXE% add .
if errorlevel 1 exit /b %errorlevel%

%GIT_EXE% diff --cached --quiet
if errorlevel 1 (
    echo.
    echo [3/3] Commit et push...
    %GIT_EXE% commit -m "%COMMIT_MESSAGE%"
    if errorlevel 1 exit /b %errorlevel%
) else (
    echo.
    echo Aucun changement a committer. Push uniquement.
)

%GIT_EXE% push
exit /b %errorlevel%