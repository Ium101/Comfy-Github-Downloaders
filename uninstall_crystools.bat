@echo off
setlocal EnableExtensions
title ComfyUI-Crystools Uninstaller

rem ============================================================
rem  Removes ComfyUI-Crystools from custom_nodes (including any
rem  disabled copy). Place this file in the ComfyUI folder (the
rem  one that contains "custom_nodes") and run it.
rem  Python packages are NOT removed, since other nodes may use them.
rem ============================================================

set "NODE_NAME=ComfyUI-Crystools"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "NODES_DIR=%ROOT%\custom_nodes"
set "NODE_DIR=%NODES_DIR%\%NODE_NAME%"
set "DISABLED_A=%NODES_DIR%\.disabled\%NODE_NAME%"
set "DISABLED_B=%NODES_DIR%\%NODE_NAME%.disabled"
set "REMOVED=0"
set "HAD_ERROR=0"

echo ============================================================
echo   ComfyUI-Crystools Uninstaller
echo ============================================================
echo.

if not exist "%NODES_DIR%" (
    echo [ERROR] custom_nodes folder not found:
    echo         %NODES_DIR%
    echo         Put this .bat inside the ComfyUI folder.
    echo.
    pause
    endlocal
    exit /b 1
)

echo [INFO] Make sure ComfyUI is closed before continuing.
echo.

call :remove_dir "%NODE_DIR%"
call :remove_dir "%DISABLED_A%"
call :remove_dir "%DISABLED_B%"

set "NOT_FOUND=0"
if "%REMOVED%"=="0" if "%HAD_ERROR%"=="0" (
    set "NOT_FOUND=1"
    echo [OK] %NODE_NAME% is not installed, nothing to remove.
)

echo.
echo ============================================================
echo   Summary
echo ============================================================
echo   Removed:       %REMOVED%
echo   Not installed: %NOT_FOUND%
echo ============================================================
echo.
pause
endlocal & exit /b %HAD_ERROR%

:remove_dir
if not exist "%~1" exit /b 0
echo [INFO] Removing %~1 ...
rd /s /q "%~1"
if exist "%~1" goto :remove_dir_error
echo [OK] Removed.
set /a REMOVED+=1
exit /b 0

:remove_dir_error
echo [ERROR] Could not remove the folder. Close ComfyUI and anything using it, then try again.
set "HAD_ERROR=1"
exit /b 0
