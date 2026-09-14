@echo off
setlocal enabledelayedexpansion
title Build Release Packager

set WORKSPACE_DIR=%~dp0
cd /d "%WORKSPACE_DIR%"

taskkill /IM ja_dut_info.exe /F 2>nul
echo [BUILD] Compiling Windows desktop application in Release mode...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %ERRORLEVEL%
)

set REL=build\windows\x64\runner\Release

if exist %REL%\config.json del /f /q %REL%\config.json
if exist %REL%\config.ini del /f /q %REL%\config.ini
if exist %REL%\logs rmdir /s /q %REL%\logs

if exist bin xcopy /e /i /y /q bin %REL%\bin\
if exist assets xcopy /e /i /y /q assets %REL%\assets\
if exist i18n xcopy /e /i /y /q i18n %REL%\i18n\
if exist debug.bat copy /y debug.bat %REL%\
if exist ABOUT.txt copy /y ABOUT.txt %REL%\
if exist README.md copy /y README.md %REL%\
if exist CHANGELOG.md copy /y CHANGELOG.md %REL%\
if exist LICENSE copy /y LICENSE %REL%\

if exist dist rmdir /s /q dist
mkdir dist
xcopy /e /i /y /q %REL%\*.* dist\

if exist "dist_pack" rmdir /s /q "dist_pack"
mkdir "dist_pack\JA_DUT_Info_v2.1.0_Windows_x64"
xcopy /e /i /y /q "dist\*.*" "dist_pack\JA_DUT_Info_v2.1.0_Windows_x64\"
powershell -Command "Compress-Archive -Path 'dist_pack\*' -DestinationPath 'dist\JA_DUT_Info_v2.1.0_Windows_x64.zip' -Force"
if exist "dist_pack" rmdir /s /q "dist_pack"

echo [SUCCESS] Release packaged at dist\JA_DUT_Info_v2.1.0_Windows_x64.zip
pause
