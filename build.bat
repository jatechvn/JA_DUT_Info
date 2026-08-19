@echo off
cd /d %~dp0
echo [BUILD] Compiling Windows desktop application in Release mode...
call flutter build windows
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo [DIST] Copying release files to \dist...
if not exist "dist" mkdir "dist"
xcopy /s /e /y "build\windows\x64\runner\Release\*" "dist\"
echo [SUCCESS] Release build is complete. Output files copied to \dist
pause
