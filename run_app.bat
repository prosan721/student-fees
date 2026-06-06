@echo off
title Tuition Manager Pro Launcher
echo ==================================================
echo         Tuition Manager Pro is Starting
echo ==================================================
echo.
echo Please keep this window open while using the app.
echo.

node server.js
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to start server. Please make sure Node.js is installed.
    pause
)
