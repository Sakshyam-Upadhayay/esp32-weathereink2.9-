@echo off
rem Lilas Robotics e-ink weather station - Windows launcher.
rem Double-click to install tools, build and flash, or run e.g.
rem   flash.bat --wifi "Home" --pass "secret" --city "Pokhara, Nepal"
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\flash.ps1" %*
set "LILAS_ERR=%ERRORLEVEL%"
rem keep the window open when started by double-click
echo "%CMDCMDLINE%" | find /i "%~nx0" >nul && pause
exit /b %LILAS_ERR%
