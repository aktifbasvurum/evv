@echo off
chcp 65001 >nul
title Mullvad VPN Durdurucu
echo Mullvad baglantisi kesiliyor...
"C:\Program Files\Mullvad VPN\resources\mullvad.exe" disconnect
taskkill /f /fi "WINDOWTITLE eq Mullvad VPN Otomatik IP Degistirici*" >nul 2>&1
echo.
echo VPN baglantisi kesildi ve otomatik degistirici durduruldu.
echo.
pause
