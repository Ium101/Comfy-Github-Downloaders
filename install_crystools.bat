@echo off
setlocal EnableExtensions
title ComfyUI-Crystools ^| Installer

rem ============================================================
rem  Installs / updates ComfyUI-Crystools and its requirements.
rem  Place this file in the ComfyUI folder (the one that contains
rem  "custom_nodes"), or one level above it.
rem  The node is only downloaded when it is missing or outdated.
rem  Pass -f / --force to reinstall even if it is up to date.
rem ============================================================

set "NODE_NAME=ComfyUI-Crystools"
set "REPO_URL=https://github.com/crystian/ComfyUI-Crystools.git"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "COMFYUI_DIR=%ROOT%"
if not exist "%ROOT%\custom_nodes" if exist "%ROOT%\ComfyUI\custom_nodes" set "COMFYUI_DIR=%ROOT%\ComfyUI"
set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set "NODE_DIR=%CUSTOM_NODES_DIR%\%NODE_NAME%"
set "DISABLED_A=%CUSTOM_NODES_DIR%\.disabled\%NODE_NAME%"
set "DISABLED_B=%CUSTOM_NODES_DIR%\%NODE_NAME%.disabled"

set "PYTHON_EXE="
set "PY_S_FLAG="
set "NODE_STATUS="
set "DEPS_STATUS=not attempted"
set "INSTALLED=0"
set "UPTODATE=0"
set "ENABLED=0"
set "FAILED=0"

set "FORCE=0"
if /i "%~1"=="-f" set "FORCE=1"
if /i "%~1"=="--force" set "FORCE=1"

echo ======================================================
echo  ComfyUI-Crystools ^| Installer
echo ======================================================
echo.

echo [1/5]  Locating ComfyUI installation...
echo  Root         : %COMFYUI_DIR%
echo  custom_nodes : %CUSTOM_NODES_DIR%
echo.
if not exist "%CUSTOM_NODES_DIR%" (
    echo  [ERROR] custom_nodes folder not found. Put this .bat in the ComfyUI folder.
    goto :abort
)

rem ---------- Detect Python ----------
echo [2/5]  Detecting Python runtime...
if exist "%ROOT%\..\python_embeded\python.exe" set "PYTHON_EXE=%ROOT%\..\python_embeded\python.exe" & set "PY_S_FLAG=-s"
if not defined PYTHON_EXE if exist "%ROOT%\python_embeded\python.exe" set "PYTHON_EXE=%ROOT%\python_embeded\python.exe" & set "PY_S_FLAG=-s"
if not defined PYTHON_EXE if exist "%ROOT%\.venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\.venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%COMFYUI_DIR%\.venv\Scripts\python.exe" set "PYTHON_EXE=%COMFYUI_DIR%\.venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%COMFYUI_DIR%\venv\Scripts\python.exe" set "PYTHON_EXE=%COMFYUI_DIR%\venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\..\.venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\..\.venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%ROOT%\..\venv\Scripts\python.exe" set "PYTHON_EXE=%ROOT%\..\venv\Scripts\python.exe"
if defined PYTHON_EXE goto :python_found
where python >nul 2>&1
if errorlevel 1 goto :python_missing
set "PYTHON_EXE=python"
echo  [WARN] Using system python.
goto :python_done

:python_missing
echo  [ERROR] No Python found. Use ComfyUI's python_embeded or a venv.
goto :abort

:python_found
echo  Found: %PYTHON_EXE%

:python_done
echo.

rem ---------- Check Git ----------
echo [3/5]  Checking for Git...
where git >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Git not found. Install it from https://git-scm.com/
    goto :abort
)
for /f "delims=" %%i in ('git --version') do echo  Found: %%i
echo.

rem ---------- Clone / update / repair ----------
echo [4/5]  Installing custom node...
echo.

call :restore_one "%DISABLED_A%"
call :restore_one "%DISABLED_B%"
if "%NODE_STATUS%"=="failed" goto :deps_step

if exist "%NODE_DIR%\.git" goto :update_node
if exist "%NODE_DIR%" goto :stale_folder
goto :clone_node

:update_node
echo  Repo found - checking for updates...
git -C "%NODE_DIR%" fetch --prune
if errorlevel 1 (
    echo  [ERROR] git fetch failed - could not check for updates.
    set "NODE_STATUS=failed"
    goto :deps_step
)

rem Compare against the upstream branch; fall back to origin/HEAD, then origin/main
set "REMOTE_REF=@{u}"
git -C "%NODE_DIR%" rev-parse --verify --quiet "%REMOTE_REF%" >nul 2>&1
if errorlevel 1 set "REMOTE_REF=origin/HEAD"
git -C "%NODE_DIR%" rev-parse --verify --quiet "%REMOTE_REF%" >nul 2>&1
if errorlevel 1 set "REMOTE_REF=origin/main"

set "LOCAL_SHA="
set "REMOTE_SHA="
for /f %%i in ('git -C "%NODE_DIR%" rev-parse HEAD 2^>nul') do set "LOCAL_SHA=%%i"
for /f %%i in ('git -C "%NODE_DIR%" rev-parse "%REMOTE_REF%" 2^>nul') do set "REMOTE_SHA=%%i"

set "DIRTY=0"
git -C "%NODE_DIR%" diff --quiet HEAD >nul 2>&1
if errorlevel 1 set "DIRTY=1"

if "%FORCE%"=="1" goto :sync_node
if not defined LOCAL_SHA goto :sync_node
if not defined REMOTE_SHA goto :sync_node
if not "%LOCAL_SHA%"=="%REMOTE_SHA%" goto :sync_node
if "%DIRTY%"=="1" goto :sync_node

echo  Already up to date - skipping.
set "NODE_STATUS=uptodate"
goto :deps_step

:sync_node
echo  Update available or repair needed - syncing to latest clean state...
set "NODE_STATUS=updated"
git -C "%NODE_DIR%" reset --hard %REMOTE_REF%
if errorlevel 1 set "NODE_STATUS=update_failed"
git -C "%NODE_DIR%" clean -fdx >nul 2>&1
if "%NODE_STATUS%"=="update_failed" echo  [ERROR] git sync failed - node may be outdated.
goto :deps_step

:stale_folder
echo  Stale folder found (no .git) - removing and re-cloning...
rd /s /q "%NODE_DIR%"
if exist "%NODE_DIR%" (
    echo  [ERROR] Cannot remove the old folder - close any programs using it.
    set "NODE_STATUS=failed"
    goto :deps_step
)

:clone_node
echo  Cloning into: %NODE_DIR%
git clone "%REPO_URL%" "%NODE_DIR%"
if errorlevel 1 (
    echo  [ERROR] git clone failed. Check your internet connection.
    set "NODE_STATUS=failed"
    goto :deps_step
)
set "NODE_STATUS=installed"

:deps_step
echo.
rem ---------- Install dependencies (only when installed or updated) ----------
if "%NODE_STATUS%"=="uptodate" goto :deps_skipped
if "%NODE_STATUS%"=="failed" goto :tally

echo [5/5]  Installing Python dependencies...
if not exist "%NODE_DIR%\requirements.txt" goto :deps_none
"%PYTHON_EXE%" %PY_S_FLAG% -m pip install -r "%NODE_DIR%\requirements.txt"
if errorlevel 1 goto :deps_failed
set "DEPS_STATUS=installed"
goto :purge

:deps_failed
echo  [WARN] pip install failed - the node may not work until the requirements are installed.
set "DEPS_STATUS=FAILED - see messages above"
goto :purge

:deps_none
echo  No requirements.txt found - skipping pip install.
set "DEPS_STATUS=none needed"
goto :purge

:deps_skipped
echo [5/5]  Dependencies skipped - already up to date.
set "DEPS_STATUS=skipped - already up to date"
goto :tally

rem ---------- Remove all __pycache__ folders and .pyc / .pyo files ----------
:purge
echo.
echo  Purging __pycache__ and .pyc files...
for /d /r "%NODE_DIR%" %%d in (__pycache__) do if exist "%%d" rd /s /q "%%d"
del /s /q "%NODE_DIR%\*.pyc" >nul 2>&1
del /s /q "%NODE_DIR%\*.pyo" >nul 2>&1

:tally
if "%NODE_STATUS%"=="installed" set "INSTALLED=1"
if "%NODE_STATUS%"=="updated" set "INSTALLED=1"
if "%NODE_STATUS%"=="uptodate" set "UPTODATE=1"
if "%NODE_STATUS%"=="failed" set "FAILED=1"
if "%NODE_STATUS%"=="update_failed" set "FAILED=1"

echo.
echo ======================================================
echo  Summary
echo ======================================================
echo  Installed    : %INSTALLED%
echo  Up to date   : %UPTODATE%
if not "%ENABLED%"=="0" echo  Re-enabled   : %ENABLED%
echo  Dependencies : %DEPS_STATUS%
echo ======================================================
if "%FAILED%"=="1" goto :msg_failed
if not "%ENABLED%"=="0" goto :msg_enabled
if "%UPTODATE%"=="1" goto :msg_uptodate
echo  Done! Restart ComfyUI to activate the node.
goto :msg_end

:msg_failed
echo  Install did not complete - see messages above.
goto :msg_end

:msg_enabled
echo  Node re-enabled - restart ComfyUI to activate it.
goto :msg_end

:msg_uptodate
echo  Already up to date - nothing was changed.

:msg_end
echo ======================================================
echo.
pause
endlocal & exit /b %FAILED%

:abort
echo.
pause
endlocal & exit /b 1

rem ---------- Re-enable a disabled copy instead of keeping a duplicate ----------
rem Looks for custom_nodes\.disabled\<name> and custom_nodes\<name>.disabled
rem (ComfyUI-Manager's two ways of disabling a node). A disabled copy is moved back
rem to custom_nodes; if an active copy already exists, the duplicate is removed.
:restore_one
if not exist "%~1" exit /b 0
if exist "%NODE_DIR%" goto :restore_dup
echo   Found disabled copy - moving it back to custom_nodes...
move "%~1" "%NODE_DIR%" >nul
if errorlevel 1 goto :restore_err
set /a ENABLED+=1
exit /b 0

:restore_dup
echo   Disabled duplicate found - active copy exists, removing the duplicate...
rd /s /q "%~1"
if exist "%~1" goto :restore_err
exit /b 0

:restore_err
echo   [ERROR] Could not restore or remove the disabled copy.
set "NODE_STATUS=failed"
exit /b 0
