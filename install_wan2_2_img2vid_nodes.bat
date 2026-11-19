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
set /a INSTALLED=0
set /a UPTODATE=0
set /a ENABLED=0
set /a FAILED=0
set /a WARNED=0
set "WARN_LIST="
set "FORCE="
if /i "%~1"=="/force" set "FORCE=1"
if /i "%~1"=="--force" set "FORCE=1"
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
echo  Summary
echo ============================================
echo  Installed       : !INSTALLED!
echo  Up to date      : !UPTODATE!
if !ENABLED! gtr 0 echo  Re-enabled      : !ENABLED!
echo  Dep. warnings   : !WARNED!
if !WARNED! gtr 0 echo  Check deps for  :!WARN_LIST!
echo ============================================
if !FAILED! gtr 0 echo  [WARN] Some nodes failed - see messages above.
set /a CHANGED=INSTALLED+ENABLED
if !CHANGED! gtr 0 (
    echo  Please RESTART ComfyUI now.
) else (
    echo  Nothing changed - no restart needed.
)
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
set "NODE_STATUS="
set "PIP_WARN="
set "CUSTOM_INSTALLER=%~2"
:: Extract folder name from URL (last path segment)
for %%F in (%REPO%) do set "FNAME=%%~nF"
set "NODE_DIR=%CUSTOM_NODES_DIR%\%FNAME%"

echo.
echo ── %FNAME%

:: Re-enable: a copy parked in custom_nodes\.disabled\ (or named <name>.disabled)
:: is moved back to custom_nodes instead of being left behind as a duplicate.
set "RESTORE_ERR="
for %%D in ("%CUSTOM_NODES_DIR%\.disabled\%FNAME%" "%NODE_DIR%.disabled") do (
    if exist "%%~D" (
        if exist "!NODE_DIR!" (
            echo   Disabled duplicate found - active copy exists, removing the duplicate...
            rmdir /s /q "%%~D"
            if exist "%%~D" (
                echo   [ERROR] Could not remove the disabled duplicate.
                set "RESTORE_ERR=1"
            )
        ) else (
            echo   Found disabled copy - moving it back to custom_nodes...
            move "%%~D" "!NODE_DIR!" >nul
            if errorlevel 1 (
                echo   [ERROR] Could not move the disabled copy back.
                set "RESTORE_ERR=1"
            ) else (
                set /a ENABLED+=1
            )
        )
    )
)
if defined RESTORE_ERR (
    set "NODE_STATUS=failed"
    goto :end_node
)

:: Case A: valid git repo → sync to clean latest
if exist "%NODE_DIR%\.git" (
    echo   Repo found - checking for updates...
    git -C "%NODE_DIR%" fetch --prune
    if errorlevel 1 (
        echo   [ERROR] git fetch failed - could not check for updates, skipping.
        set "NODE_STATUS=failed"
        goto :end_node
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
        echo   Already up to date - skipping.
        set "NODE_STATUS=uptodate"
        goto :end_node
    )
    echo   Update available or repair needed - syncing to latest clean state...
    set "NODE_STATUS=updated"
    git -C "%NODE_DIR%" reset --hard !REMOTE_REF!
    if errorlevel 1 set "NODE_STATUS=update_failed"
    git -C "%NODE_DIR%" clean -fdx
    if "!NODE_STATUS!"=="update_failed" echo   [ERROR] git sync failed - node may be outdated.
    goto :do_pip
)

:: Case B: stale folder with no .git → remove then re-clone
if exist "%NODE_DIR%" (
    echo   Stale folder found ^(no .git^) - removing and re-cloning...
    rmdir /s /q "%NODE_DIR%"
    if errorlevel 1 (
        echo   [ERROR] Cannot remove %NODE_DIR% - skipping.
        set "NODE_STATUS=failed"
        goto :end_node
    )
)

:: Case C: fresh clone
echo   Cloning...
git clone --depth=1 "%REPO%" "%NODE_DIR%"
if errorlevel 1 (
    echo   [ERROR] git clone failed - skipping.
    set "NODE_STATUS=failed"
    goto :end_node
)
set "NODE_STATUS=installed"

:do_pip
:: A node's own installer (if specified) takes priority over the generic
:: requirements.txt step.
if not "%CUSTOM_INSTALLER%"=="" if exist "%NODE_DIR%\%CUSTOM_INSTALLER%" (
    echo   Running node's own installer ^(%CUSTOM_INSTALLER%^)...
    cd /d "%NODE_DIR%"
    "%PYTHON_EXE%" %PY_S_FLAG% "%CUSTOM_INSTALLER%"
    if errorlevel 1 (
        echo   [WARN] node installer reported errors.
        set "PIP_WARN=1"
    )
    cd /d "%COMFYUI_DIR%"
    goto :purge
)
if exist "%NODE_DIR%\requirements.txt" (
    echo   Installing requirements...
    "%PYTHON_EXE%" -m pip install -r "%NODE_DIR%\requirements.txt" --quiet
    if errorlevel 1 (
        echo   [WARN] pip install reported errors.
        set "PIP_WARN=1"
    )
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
if "%NODE_STATUS%"=="installed" set /a INSTALLED+=1
if "%NODE_STATUS%"=="updated" set /a INSTALLED+=1
if "%NODE_STATUS%"=="uptodate" set /a UPTODATE+=1
if "%NODE_STATUS%"=="failed" set /a FAILED+=1
if "%NODE_STATUS%"=="update_failed" set /a FAILED+=1
if defined PIP_WARN (
    set /a WARNED+=1
    set "WARN_LIST=!WARN_LIST! !FNAME!"
)
exit /b 0
