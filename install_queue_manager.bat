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
    echo  Repo found - syncing to latest clean state...
    cd /d "%NODE_DIR%"
    git fetch --prune
    git reset --hard origin/main
    git clean -fdx
    cd /d "%COMFYUI_DIR%"
    goto :pip_install
)
if exist "%NODE_DIR%" (
    echo  Stale folder found ^(no .git^) - removing and re-cloning...
    rmdir /s /q "%NODE_DIR%"
    if errorlevel 1 (
        echo  [ERROR] Cannot remove %NODE_DIR% - close any programs using it.
        pause & exit /b 1
    )
)
echo  Cloning into: %NODE_DIR%
echo.
git clone "%REPO_URL%" "%NODE_DIR%"
if errorlevel 1 ( echo  [ERROR] git clone failed. & pause & exit /b 1 )

:pip_install
echo.
echo [5/5]  Installing Python dependencies...
if not exist "%NODE_DIR%\requirements.txt" (
    echo  No requirements.txt - skipping pip install.
    goto :purge_trash
)
"%PYTHON_EXE%" -m pip install -r "%NODE_DIR%\requirements.txt"
if errorlevel 1 ( echo  [ERROR] pip install failed. & pause & exit /b 1 )

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
echo.
echo ============================================
echo  Done! Restart ComfyUI to activate the node.
echo ============================================
echo.
pause
