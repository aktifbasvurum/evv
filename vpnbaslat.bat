@echo off
chcp 65001 >nul
title Mullvad VPN Halkbank Kontrollu IP Degistirici
cd /d "%~dp0"

echo ====================================================
echo   Mullvad VPN Kontrollu IP Degistirici Baslatiliyor...
echo   Kural:
echo   - Siteye girerse: 20 DK AYNI IP'DE KALIR
echo   - Siteye girmezse: ANINDA BASKA IP'YE GECER
echo ====================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rotate.ps1"

pause
