@echo off
setlocal
set "APP_SCRIPT=%~dp0ResearchDataManager.ps1"

if not exist "%APP_SCRIPT%" (
    echo ResearchDataManager.ps1 was not found in this folder.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%APP_SCRIPT%"

if errorlevel 1 (
    echo.
    echo ResearchData Manager exited with an error.
    pause
)

endlocal
