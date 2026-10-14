@echo off
cd /d "%~dp0"
title Driving Care - System Launcher
echo ========================================================
echo        DRIVING CARE - SYSTEM LAUNCHER (KSA)
echo   Partner: Ikram  ^|  Client: Bilal (+966 53 419 9549)
echo ========================================================
echo.
echo Starting Driving Care server on http://127.0.0.1:8085 ...
timeout /t 1 >nul
start "" "http://127.0.0.1:8085/driving-care-app/index.html"
start "" "http://127.0.0.1:8085/driving-care-portal/index.html"
node server.js
if %ERRORLEVEL% NEQ 0 (
    echo Node.js not found, trying python...
    python -m http.server 8085
)
pause
