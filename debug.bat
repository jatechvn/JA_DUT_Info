@echo off
cd /d %~dp0
for %%i in (*.exe) do (
    start "" "%%i" -debug
    exit
)
