@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  WAN 2.2 Smooth Workflow img2vid
echo  Custom Nodes Installer
echo ============================================
echo.

set "COMFYUI_DIR=%~dp0"
if "%COMFYUI_DIR:~-1%"=="\" set "COMFYUI_DIR=%COMFYUI_DIR:~0,-1%"

set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set "PYTHON_EXE="
set "PY_S_FLAG="

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
    set "PY_S_FLAG=-s"
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

:: comfy-mtb          - ColorMatch, Pick From Batch
call :install_node https://github.com/melMass/comfy_mtb

:: rgthree-comfy      - Label, Power Lora Loader, Seed
call :install_node https://github.com/rgthree/rgthree-comfy

:: comfyui-kjnodes    - ImageResizeKJv2
call :install_node https://github.com/kijai/ComfyUI-KJNodes

:: comfyui-easy-use   - easy cleanGpuUsed, easy showAnything
call :install_node https://github.com/yolain/ComfyUI-Easy-Use

:: comfyui-gguf       - UnetLoaderGGUF
call :install_node https://github.com/city96/ComfyUI-GGUF

:: comfyui-videohelpersuite - VHS_VideoCombine
call :install_node https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite

:: comfyui-frame-interpolation - RIFE VFI
:: NOTE: this repo ships NO plain requirements.txt (only requirements-no-cupy.txt /
:: requirements-with-cupy.txt) and needs a CUDA-version-aware cupy install, so the
:: generic pip step below always silently no-ops for it. We run its own install.py
:: instead - that's what was causing ComfyUI to fail to import/recognize this node.
call :install_node https://github.com/Fannovel16/ComfyUI-Frame-Interpolation install.py

:: comfyui-mxtoolkit  - mxSlider2D
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
:: %2 = (optional) custom installer script, relative to the node's own folder,
::      to run INSTEAD of the generic requirements.txt pip step. Use this for
::      nodes that ship their own install.py/install.bat and don't provide a
::      plain requirements.txt.
:: ─────────────────────────────────────────────────────────────────────────────
set "REPO=%~1"
set "CUSTOM_INSTALLER=%~2"
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
:: A node's own installer (if specified) takes priority over the generic
:: requirements.txt step.
if not "%CUSTOM_INSTALLER%"=="" if exist "%NODE_DIR%\%CUSTOM_INSTALLER%" (
    echo   Running node's own installer ^(%CUSTOM_INSTALLER%^)...
    cd /d "%NODE_DIR%"
    "%PYTHON_EXE%" %PY_S_FLAG% "%CUSTOM_INSTALLER%"
    cd /d "%COMFYUI_DIR%"
    goto :purge
)
if exist "%NODE_DIR%\requirements.txt" (
    echo   Installing requirements...
    "%PYTHON_EXE%" -m pip install -r "%NODE_DIR%\requirements.txt" --quiet
) else (
    echo   No requirements.txt - skipping pip.
)

:purge
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
