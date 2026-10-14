@echo off
cd /d "%~dp0"
title Driving Care - Cloudflare Global Tunnel
echo ========================================================
echo        DRIVING CARE - CLOUDFLARE SECURE TUNNEL
echo ========================================================
echo.
echo Connecting your Local Laptop to Cloudflare Global Network...
echo.
echo NOTE: Mobile phones anywhere in the world will connect
echo directly to your laptop through this secure HTTPS link!
echo.
"F:\tools\cloudflared.exe" tunnel --url http://127.0.0.1:8085
pause
