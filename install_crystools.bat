@echo off
setlocal EnableExtensions
title ComfyUI-Crystools Installer

rem ============================================================
rem  Installs / updates ComfyUI-Crystools and its requirements.
rem  Place this file in the ComfyUI folder (the one that
rem  contains "custom_nodes") and run it.
rem ============================================================

set "NODE_NAME=ComfyUI-Crystools"
set "REPO_URL=https://github.com/crystian/ComfyUI-Crystools.git"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "NODES_DIR=%ROOT%\custom_nodes"
set "NODE_DIR=%NODES_DIR%\%NODE_NAME%"
set "DISABLED_A=%NODES_DIR%\.disabled\%NODE_NAME%"
set "DISABLED_B=%NODES_DIR%\%NODE_NAME%.disabled"
set "INSTALLED=0"
set "SKIPPED=0"

echo ============================================================
echo   ComfyUI-Crystools Installer
echo ============================================================
echo.

rem ---------- Sanity checks ----------
if not exist "%NODES_DIR%" (
    echo [ERROR] custom_nodes folder not found:
    echo         %NODES_DIR%
    echo         Put this .bat inside the ComfyUI folder.
    goto :failed
)

where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git was not found in PATH. Install it from https://git-scm.com/
    goto :failed
)

rem ---------- Locate Python ----------
set "PYTHON_EXE="
if exist "%ROOT%\..\python_embeded\python.exe" set "PYTHON_EXE=%ROOT%\..\python_embeded\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\python_embeded\python.exe" set "PYTHON_EXE=%ROOT%\python_embeded\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\.venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\.venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\..\venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\..\venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\..\.venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\..\.venv\Scripts\python.exe"
if not defined PYTHON_EXE (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_EXE=python"
)
if not defined PYTHON_EXE (
    echo [ERROR] Python not found. Use ComfyUI's python_embeded or a venv.
    goto :failed
)
echo [INFO] Python: %PYTHON_EXE%
echo.

rem ---------- Disabled copy handling ----------
if exist "%DISABLED_A%" (
    if exist "%NODE_DIR%" (
        echo [INFO] Removing duplicate disabled copy in .disabled ...
        rd /s /q "%DISABLED_A%"
    ) else (
        echo [INFO] Found %NODE_NAME% in .disabled, moving it back to custom_nodes ...
        move "%DISABLED_A%" "%NODE_DIR%" >nul
    )
)
if exist "%DISABLED_B%" (
    if exist "%NODE_DIR%" (
        echo [INFO] Removing duplicate %NODE_NAME%.disabled ...
        rd /s /q "%DISABLED_B%"
    ) else (
        echo [INFO] Found %NODE_NAME%.disabled, restoring it ...
        move "%DISABLED_B%" "%NODE_DIR%" >nul
    )
)

rem ---------- Decide: fresh install / stale folder / update ----------
if not exist "%NODE_DIR%" goto :fresh_install
if not exist "%NODE_DIR%\.git" goto :stale_folder

:update
echo [INFO] %NODE_NAME% found, checking for updates ...
git -C "%NODE_DIR%" fetch --quiet origin
if errorlevel 1 (
    echo [ERROR] git fetch failed. Check your internet connection.
    goto :failed
)

set "LOCAL="
set "REMOTE="
for /f %%i in ('git -C "%NODE_DIR%" rev-parse HEAD') do set "LOCAL=%%i"
for /f %%i in ('git -C "%NODE_DIR%" rev-parse @{u} 2^>nul') do set "REMOTE=%%i"
if not defined REMOTE for /f %%i in ('git -C "%NODE_DIR%" rev-parse origin/HEAD 2^>nul') do set "REMOTE=%%i"

if not defined REMOTE (
    echo [ERROR] Could not determine the remote version.
    goto :failed
)

if "%LOCAL%"=="%REMOTE%" (
    echo [OK] %NODE_NAME% is already up to date, nothing to do.
    set /a SKIPPED+=1
    goto :summary
)

echo [INFO] New version available, updating ...
git -C "%NODE_DIR%" reset --hard %REMOTE% >nul
if errorlevel 1 (
    echo [ERROR] git reset failed.
    goto :failed
)
goto :install_deps

:stale_folder
echo [WARN] %NODE_NAME% folder exists but is not a git repository. Removing it ...
rd /s /q "%NODE_DIR%"
if exist "%NODE_DIR%" (
    echo [ERROR] Could not remove the old folder. Close anything using it and try again.
    goto :failed
)

:fresh_install
echo [INFO] Cloning %NODE_NAME% ...
git clone "%REPO_URL%" "%NODE_DIR%"
if errorlevel 1 (
    echo [ERROR] git clone failed.
    if exist "%NODE_DIR%" rd /s /q "%NODE_DIR%"
    goto :failed
)

:install_deps
rem ---------- Purge stale bytecode ----------
for /d /r "%NODE_DIR%" %%d in (__pycache__) do if exist "%%d" rd /s /q "%%d"

rem ---------- Install requirements ----------
if exist "%NODE_DIR%\requirements.txt" (
    echo [INFO] Installing requirements ...
    "%PYTHON_EXE%" -m pip install -r "%NODE_DIR%\requirements.txt"
    if errorlevel 1 (
        echo [ERROR] pip failed to install the requirements.
        goto :failed
    )
) else (
    echo [WARN] requirements.txt not found in %NODE_NAME%, skipping pip step.
)
set /a INSTALLED+=1

:summary
echo.
echo ============================================================
echo   Summary
echo ============================================================
echo   Installed:          %INSTALLED%
echo   Already up to date: %SKIPPED%
echo ============================================================
echo.
echo Restart ComfyUI to load the node.
echo.
pause
endlocal
exit /b 0

:failed
echo.
echo Installation did not complete.
echo.
pause
endlocal
exit /b 1
