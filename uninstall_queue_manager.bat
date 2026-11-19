@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  AC ComfyUI Queue Manager  ^|  Uninstaller
echo ============================================
echo.

set "COMFYUI_DIR=%~dp0"
if "%COMFYUI_DIR:~-1%"=="\" set "COMFYUI_DIR=%COMFYUI_DIR:~0,-1%"

set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set "AUTO_YES="
if /i "%~1"=="/y" set "AUTO_YES=1"
set /a REMOVED=0
set /a SKIPPED=0
set /a FAILED=0

:: -- Nodes to remove (same repos as the installer) ------------------------------
set "NODES="
set "NODES=!NODES! https://github.com/abdullahceylan/ac-comfyui-queue-manager.git"

echo [1/3]  Locating ComfyUI installation...
echo  Root         : %COMFYUI_DIR%
echo  custom_nodes : %CUSTOM_NODES_DIR%
echo.
if not exist "%CUSTOM_NODES_DIR%" (
    echo  [ERROR] custom_nodes folder not found. Is this script in the ComfyUI root folder?
    pause & exit /b 1
)

:: -- Confirmation ---------------------------------------------------------------
echo [2/3]  These custom node folders will be DELETED ^(if present^):
for %%U in (%NODES%) do call :show_node "%%U"
echo.
echo  NOTE: other workflows may depend on some of these nodes.
echo        Python packages installed in the environment are NOT removed.
echo        Close ComfyUI before continuing.
echo.
if defined AUTO_YES goto :confirmed
set "CONFIRM="
set /p "CONFIRM= Type Y to continue (anything else cancels): "
if /i not "!CONFIRM!"=="Y" (
    echo.
    echo  Cancelled - nothing was removed.
    pause & exit /b 0
)
:confirmed
echo.

:: -- Remove each node via subroutine --------------------------------------------
echo [3/3]  Removing custom nodes...
for %%U in (%NODES%) do call :remove_node "%%U"

echo.
echo ============================================
echo  Done!  Removed: !REMOVED!  ^|  Not installed: !SKIPPED!
if !FAILED! gtr 0 echo  [WARN] Some folders could not be removed - see messages above.
echo  Please RESTART ComfyUI now.
echo ============================================
echo.
pause
exit /b 0

:: =============================================================================
:show_node
:: %1 = repo URL (prints the folder name only)
:: -----------------------------------------------------------------------------
for %%F in (%~1) do echo    - %%~nF
exit /b 0

:: =============================================================================
:remove_node
:: %1 = repo URL
:: -----------------------------------------------------------------------------
set "REPO=%~1"
:: Extract folder name from URL (last path segment)
for %%F in (%REPO%) do set "FNAME=%%~nF"
set "NODE_DIR=%CUSTOM_NODES_DIR%\%FNAME%"

echo.
echo -- %FNAME%

:: Not installed (neither the normal nor the ComfyUI-Manager ".disabled" folder)
if not exist "%NODE_DIR%" if not exist "%NODE_DIR%.disabled" (
    echo   Not installed - skipping.
    set /a SKIPPED+=1
    goto :end_remove
)

call :delete_dir "%NODE_DIR%"
call :delete_dir "%NODE_DIR%.disabled"

:end_remove
exit /b 0

:: =============================================================================
:delete_dir
:: %1 = full path of the folder to delete
:: -----------------------------------------------------------------------------
set "TARGET=%~1"
if not exist "%TARGET%" exit /b 0
echo   Removing %TARGET% ...
rmdir /s /q "%TARGET%" >nul 2>&1
if exist "%TARGET%" (
    echo   [ERROR] Could not remove it - close ComfyUI and any program using it, then retry.
    set /a FAILED+=1
) else (
    echo   Removed.
    set /a REMOVED+=1
)
exit /b 0
