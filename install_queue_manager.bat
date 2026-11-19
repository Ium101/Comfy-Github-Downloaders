@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  AC ComfyUI Queue Manager  ^|  Installer
echo ============================================
echo.

set "COMFYUI_DIR=%~dp0"
if "%COMFYUI_DIR:~-1%"=="\" set "COMFYUI_DIR=%COMFYUI_DIR:~0,-1%"

set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set "NODE_DIR=%CUSTOM_NODES_DIR%\ac-comfyui-queue-manager"
set "REPO_URL=https://github.com/abdullahceylan/ac-comfyui-queue-manager.git"
set "PYTHON_EXE="
set "NODE_STATUS="
set "DEPS_STATUS=not attempted"
set /a INSTALLED=0
set /a UPTODATE=0
set /a FAILED=0
set "FORCE="
if /i "%~1"=="/force" set "FORCE=1"
if /i "%~1"=="--force" set "FORCE=1"

echo [1/5]  Locating ComfyUI installation...
echo  Root         : %COMFYUI_DIR%
echo  custom_nodes : %CUSTOM_NODES_DIR%
echo.

:: ── Detect Python ─────────────────────────────────────────────────────────────
echo [2/5]  Detecting Python runtime...
if exist "%COMFYUI_DIR%\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%COMFYUI_DIR%\.venv\Scripts\python.exe"
    echo  Found: Desktop/venv  ^(.venv\Scripts\python.exe^)
    goto :python_found
)
if exist "%COMFYUI_DIR%\python_embeded\python.exe" (
    set "PYTHON_EXE=%COMFYUI_DIR%\python_embeded\python.exe"
    echo  Found: Portable  ^(python_embeded\python.exe^)
    goto :python_found
)
where python >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_EXE=python"
    echo  [WARN] Using system Python.
    goto :python_found
)
echo  [ERROR] No Python found. Is this script in the ComfyUI root folder?
pause & exit /b 1
:python_found
echo.

:: ── Check Git ─────────────────────────────────────────────────────────────────
echo [3/5]  Checking for Git...
where git >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Git not found. Install from https://git-scm.com and retry.
    pause & exit /b 1
)
for /f "tokens=*" %%v in ('git --version') do echo  Found: %%v
echo.

:: ── Clone / update / repair ───────────────────────────────────────────────────
echo [4/5]  Installing custom node...
echo.

if exist "%NODE_DIR%\.git" (
    echo  Repo found - checking for updates...
    git -C "%NODE_DIR%" fetch --prune
    if errorlevel 1 (
        echo  [ERROR] git fetch failed - could not check for updates.
        set "NODE_STATUS=failed"
        goto :done
    )
    set "LOCAL_SHA="
    set "REMOTE_SHA="
    set "LOCAL_DIRTY="
    set "REMOTE_REF=@{u}"
    git -C "%NODE_DIR%" rev-parse --verify --quiet @{u} >nul 2>&1
    if errorlevel 1 set "REMOTE_REF=origin/main"
    for /f %%H in ('git -C "%NODE_DIR%" rev-parse HEAD 2^>nul') do set "LOCAL_SHA=%%H"
    for /f %%H in ('git -C "%NODE_DIR%" rev-parse !REMOTE_REF! 2^>nul') do set "REMOTE_SHA=%%H"
    git -C "%NODE_DIR%" diff --quiet HEAD >nul 2>&1
    if errorlevel 1 set "LOCAL_DIRTY=1"
    if not defined FORCE if defined LOCAL_SHA if "!LOCAL_SHA!"=="!REMOTE_SHA!" if not defined LOCAL_DIRTY (
        echo  Already up to date - skipping dependencies and cleanup.
        set "NODE_STATUS=uptodate"
        set "DEPS_STATUS=skipped - already up to date"
        goto :done
    )
    echo  Update available or repair needed - syncing to latest clean state...
    set "NODE_STATUS=updated"
    git -C "%NODE_DIR%" reset --hard !REMOTE_REF!
    if errorlevel 1 set "NODE_STATUS=update_failed"
    git -C "%NODE_DIR%" clean -fdx
    if "!NODE_STATUS!"=="update_failed" echo  [ERROR] git sync failed - node may be outdated.
    goto :pip_install
)
if exist "%NODE_DIR%" (
    echo  Stale folder found ^(no .git^) - removing and re-cloning...
    rmdir /s /q "%NODE_DIR%"
    if errorlevel 1 (
        echo  [ERROR] Cannot remove %NODE_DIR% - close any programs using it.
        set "NODE_STATUS=failed"
        goto :done
    )
)
echo  Cloning into: %NODE_DIR%
echo.
git clone "%REPO_URL%" "%NODE_DIR%"
if errorlevel 1 (
    echo  [ERROR] git clone failed.
    set "NODE_STATUS=failed"
    goto :done
)
set "NODE_STATUS=installed"

:pip_install
echo.
echo [5/5]  Installing Python dependencies...
if not exist "%NODE_DIR%\requirements.txt" (
    echo  No requirements.txt - skipping pip install.
    set "DEPS_STATUS=none needed"
    goto :purge_trash
)
"%PYTHON_EXE%" -m pip install -r "%NODE_DIR%\requirements.txt"
if errorlevel 1 (
    echo  [ERROR] pip install failed.
    set "DEPS_STATUS=FAILED"
    set "NODE_STATUS=failed"
    goto :done
)
set "DEPS_STATUS=installed"

:purge_trash
:: ── Remove all __pycache__ folders and .pyc files recursively ─────────────────
echo.
echo  Purging __pycache__ and .pyc files...
for /d /r "%NODE_DIR%" %%d in (__pycache__) do (
    if exist "%%d" rmdir /s /q "%%d"
)
for /r "%NODE_DIR%" %%f in (*.pyc) do (
    if exist "%%f" del /f /q "%%f"
)
for /r "%NODE_DIR%" %%f in (*.pyo) do (
    if exist "%%f" del /f /q "%%f"
)

:done
if "%NODE_STATUS%"=="installed" set /a INSTALLED=1
if "%NODE_STATUS%"=="updated" set /a INSTALLED=1
if "%NODE_STATUS%"=="uptodate" set /a UPTODATE=1
if "%NODE_STATUS%"=="failed" set /a FAILED=1
if "%NODE_STATUS%"=="update_failed" set /a FAILED=1
echo.
echo ============================================
echo  Summary
echo ============================================
echo  Installed    : !INSTALLED!
echo  Up to date   : !UPTODATE!
echo  Dependencies : !DEPS_STATUS!
echo ============================================
if !FAILED! gtr 0 (
    echo  Install did not complete - see messages above.
) else if !UPTODATE! gtr 0 (
    echo  Already up to date - nothing was changed.
) else (
    echo  Done! Restart ComfyUI to activate the node.
)
echo ============================================
echo.
pause
