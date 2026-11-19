@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  SmoothMix Wan 2.2 - Custom Nodes Installer
echo ============================================
echo.

set "COMFYUI_DIR=%~dp0"
if "%COMFYUI_DIR:~-1%"=="\" set "COMFYUI_DIR=%COMFYUI_DIR:~0,-1%"

set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set /a INSTALLED=0
set /a UPTODATE=0
set /a FAILED=0
set /a WARNED=0
set "WARN_LIST="
set "FORCE="
if /i "%~1"=="/force" set "FORCE=1"
if /i "%~1"=="--force" set "FORCE=1"
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
echo  Summary
echo ============================================
echo  Installed       : !INSTALLED!
echo  Up to date      : !UPTODATE!
echo  Dep. warnings   : !WARNED!
if !WARNED! gtr 0 echo  Check deps for  :!WARN_LIST!
echo ============================================
if !FAILED! gtr 0 echo  [WARN] Some nodes failed - see messages above.
if !INSTALLED! gtr 0 (
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
:: ─────────────────────────────────────────────────────────────────────────────
set "REPO=%~1"
set "NODE_STATUS="
set "PIP_WARN="
:: Extract folder name from URL (last path segment)
for %%F in (%REPO%) do set "FNAME=%%~nF"
set "NODE_DIR=%CUSTOM_NODES_DIR%\%FNAME%"

echo.
echo ── %FNAME%

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
