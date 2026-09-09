@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  SmoothMix Wan 2.2 - Custom Nodes Installer
echo ============================================
echo.

set "COMFYUI_DIR=%~dp0"
if "%COMFYUI_DIR:~-1%"=="\" set "COMFYUI_DIR=%COMFYUI_DIR:~0,-1%"

set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set "PYTHON_EXE="

echo [1/3]  Locating ComfyUI installation...
echo  Root         : %COMFYUI_DIR%
echo  custom_nodes : %CUSTOM_NODES_DIR%
echo.

:: ── Detect Python ─────────────────────────────────────────────────────────────
echo [2/3]  Detecting Python runtime...
if exist "%COMFYUI_DIR%\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%COMFYUI_DIR%\.venv\Scripts\python.exe"
    echo  Found: Desktop/venv  ^(.venv\Scripts\python.exe^)
    goto :python_found
)
if exist "%COMFYUI_DIR%\venv\Scripts\python.exe" (
    set "PYTHON_EXE=%COMFYUI_DIR%\venv\Scripts\python.exe"
    echo  Found: venv  ^(venv\Scripts\python.exe^)
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
where git >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Git not found. Install from https://git-scm.com and retry.
    pause & exit /b 1
)

:: ── Install each node via subroutine ─────────────────────────────────────────
echo [3/3]  Installing custom nodes...

call :install_node https://github.com/Alectriciti/comfyui-adaptiveprompts
call :install_node https://github.com/melMass/comfy_mtb
call :install_node https://github.com/rgthree/rgthree-comfy
call :install_node https://github.com/kijai/ComfyUI-MMAudio
call :install_node https://github.com/kijai/ComfyUI-WanVideoWrapper
call :install_node https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
call :install_node https://github.com/GACLove/ComfyUI-VFI
call :install_node https://github.com/kijai/ComfyUI-KJNodes
call :install_node https://github.com/yolain/ComfyUI-Easy-Use
call :install_node https://github.com/scottmudge/ComfyUI-NAG
call :install_node https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
call :install_node https://github.com/city96/ComfyUI-GGUF
call :install_node https://github.com/Smirnov75/ComfyUI-mxToolkit

echo.
echo ============================================
echo  All done! Please RESTART ComfyUI now.
echo ============================================
echo.
pause
exit /b 0

:: ═════════════════════════════════════════════════════════════════════════════
:install_node
:: %1 = repo URL
:: ─────────────────────────────────────────────────────────────────────────────
set "REPO=%~1"
:: Extract folder name from URL (last path segment)
for %%F in (%REPO%) do set "FNAME=%%~nF"
set "NODE_DIR=%CUSTOM_NODES_DIR%\%FNAME%"

echo.
echo ── %FNAME%

:: Case A: valid git repo → sync to clean latest
if exist "%NODE_DIR%\.git" (
    echo   Repo found - syncing to latest clean state...
    cd /d "%NODE_DIR%"
    git fetch --prune
    git reset --hard origin/main
    git clean -fdx
    cd /d "%COMFYUI_DIR%"
    goto :do_pip
)

:: Case B: stale folder with no .git → remove then re-clone
if exist "%NODE_DIR%" (
    echo   Stale folder found ^(no .git^) - removing and re-cloning...
    rmdir /s /q "%NODE_DIR%"
    if errorlevel 1 (
        echo   [ERROR] Cannot remove %NODE_DIR% - skipping.
        goto :end_node
    )
)

:: Case C: fresh clone
echo   Cloning...
git clone --depth=1 "%REPO%" "%NODE_DIR%"
if errorlevel 1 (
    echo   [ERROR] git clone failed - skipping.
    goto :end_node
)

:do_pip
if exist "%NODE_DIR%\requirements.txt" (
    echo   Installing requirements...
    "%PYTHON_EXE%" -m pip install -r "%NODE_DIR%\requirements.txt" --quiet
) else (
    echo   No requirements.txt - skipping pip.
)

:: Purge __pycache__ and bytecode files (all paths, every run)
echo   Purging __pycache__ and .pyc files...
for /d /r "%NODE_DIR%" %%d in (__pycache__) do (
    if exist "%%d" rmdir /s /q "%%d"
)
for /r "%NODE_DIR%" %%f in (*.pyc *.pyo) do (
    if exist "%%f" del /f /q "%%f"
)

:end_node
exit /b 0
