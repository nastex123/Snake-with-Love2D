@echo off
pushd "%~dp0"
"C:\Program Files\LOVE\love.exe" . > error.log 2>&1
popd
pause