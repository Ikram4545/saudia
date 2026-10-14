@echo off
cd /d "%~dp0"
title Driving Care - Ikram Admin Server & Live Portal
echo ========================================================
echo       DRIVING CARE - MASTER ADMIN SERVER (KSA)
echo   Sole Owner: Ikram  ^|  Client: Bilal (+966 53 419 9549)
echo ========================================================
echo.
echo [1/2] Starting Local Server with Live Driver Database...
timeout /t 1 >nul
start "" "http://127.0.0.1:8085/driving-care-portal/index.html"
echo [2/2] Admin Dashboard Opened in Browser!
echo.
echo All live logins and drivers will be tracked here in real-time.
echo.
node server.js
pause
