@echo off
setlocal EnableExtensions
title ComfyUI-Crystools ^| Uninstaller

rem ============================================================
rem  Removes ComfyUI-Crystools from custom_nodes, including any
rem  disabled copy. Place this file in the ComfyUI folder (the one
rem  that contains "custom_nodes"), or one level above it.
rem  Python packages are NOT removed.
rem ============================================================

set "NODE_NAME=ComfyUI-Crystools"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "COMFYUI_DIR=%ROOT%"
if not exist "%ROOT%\custom_nodes" if exist "%ROOT%\ComfyUI\custom_nodes" set "COMFYUI_DIR=%ROOT%\ComfyUI"
set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set "NODE_DIR=%CUSTOM_NODES_DIR%\%NODE_NAME%"
set "DISABLED_A=%CUSTOM_NODES_DIR%\.disabled\%NODE_NAME%"
set "DISABLED_B=%CUSTOM_NODES_DIR%\%NODE_NAME%.disabled"

set "REMOVED=0"
set "SKIPPED=0"
set "FAILED=0"

echo ======================================================
echo  ComfyUI-Crystools ^| Uninstaller
echo ======================================================
echo.

echo [1/3]  Locating ComfyUI installation...
echo  Root         : %COMFYUI_DIR%
echo  custom_nodes : %CUSTOM_NODES_DIR%
echo.
if not exist "%CUSTOM_NODES_DIR%" (
    echo  [ERROR] custom_nodes folder not found. Put this .bat in the ComfyUI folder.
    echo.
    pause
    endlocal & exit /b 1
)

echo [2/3]  This custom node folder will be DELETED (if present):
echo    - %NODE_NAME%
echo.
echo  NOTE: other workflows may depend on this node.
echo        Python packages installed in the environment are NOT removed.
echo        Close ComfyUI before continuing.
echo.

echo [3/3]  Removing custom node...
echo.
echo -- %NODE_NAME%

if exist "%NODE_DIR%" goto :do_remove
if exist "%DISABLED_A%" goto :do_remove
if exist "%DISABLED_B%" goto :do_remove
echo   Not installed - skipping.
set "SKIPPED=1"
goto :summary

:do_remove
call :delete_dir "%NODE_DIR%"
call :delete_dir "%DISABLED_B%"
call :delete_dir "%DISABLED_A%"

:summary
echo.
echo ======================================================
echo  Done!  Removed: %REMOVED%  ^|  Not installed: %SKIPPED%
if not "%FAILED%"=="0" echo  [WARN] Some folders could not be removed - see messages above.
echo  Please RESTART ComfyUI now.
echo ======================================================
echo.
pause
set "EXIT_CODE=0"
if not "%FAILED%"=="0" set "EXIT_CODE=1"
endlocal & exit /b %EXIT_CODE%

rem ---------- Delete one folder and count the result ----------
:delete_dir
if not exist "%~1" exit /b 0
echo   Removing %~1 ...
rd /s /q "%~1" 2>nul
if exist "%~1" goto :delete_err
echo   Removed.
set /a REMOVED+=1
exit /b 0

:delete_err
echo   [ERROR] Could not remove it - check permissions / close ComfyUI, then retry.
set /a FAILED+=1
exit /b 0
