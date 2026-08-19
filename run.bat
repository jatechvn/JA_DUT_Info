@echo off
cd /d %~dp0
echo Starting JA_DUT_Info in Windows Desktop Debug Mode...
call flutter run -d windows
pause
