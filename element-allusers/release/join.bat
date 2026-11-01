@echo off
setlocal
cd /d "%~dp0"
set OUT=Element-1.12.30-AllUsers-x64.exe
echo Joining %OUT%
copy /b "%OUT%.001"+"%OUT%.002"+"%OUT%.003" "%OUT%"
if errorlevel 1 (
  echo Join failed.
  exit /b 1
)
echo Expected SHA256:
echo 8a8f23e0859421914175a1f5632b856012bb019593d49ad57c9866def4f3d278
certutil -hashfile "%OUT%" SHA256
echo.
echo Install for all users, silently:
echo   %OUT% /S
echo Custom directory, /D must be last and without quotes:
echo   %OUT% /S /D=C:\Apps\Element
endlocal
