@echo off
cd /d %~dp0

set /p remote_url="Enter GitHub repository URL: "
set /p commit_msg="Enter commit message (default 'Update project'): "
if "%commit_msg%"=="" set commit_msg=Update project

if not exist ".git" (
    git init
    git branch -M main
)

git add .
git commit -m "%commit_msg%"
git remote remove origin 2>nul
git remote add origin "%remote_url%"
git push -u origin main

pause
