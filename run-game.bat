@echo off
REM Change to the directory where this script lives, then launch LOVE with current folder
pushd "%~dp0"
"C:\Program Files\LOVE\love.exe" .
popd
