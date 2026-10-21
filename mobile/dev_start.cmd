@echo off
REM ===========================================================================
REM  Dev environment launcher for MCQ (Muallim Carpets)
REM
REM    1. Backend  : node src/server.js  (http://localhost:5000/api)
REM    2. Emulator : Pixel_6 AVD (Android 16)
REM    3. App      : flutter run on the emulator, pointing at the local API
REM
REM  The app uses AppConstants.baseUrl (development: http://10.0.2.2:5000/api).
REM  For production add: --dart-define=API_BASE_URL=https://api.saisinghshope.me/api
REM ===========================================================================
setlocal enabledelayedexpansion

set ROOT=E:\MCQ_Abdullah
set MOBILE=%ROOT%\mobile
set ADB=C:\Users\T460s\AppData\Local\Android\Sdk\platform-tools\adb.exe
set EMU=C:\Users\T460s\AppData\Local\Android\Sdk\emulator\emulator.exe

echo.
echo [1/3] Starting backend...
cd /d %ROOT%\backend
start "MCQ Backend" /min node src/server.js
ping -n 6 127.0.0.1 >nul

echo [2/3] Starting Pixel_6 emulator...
call "%MOBILE%\start_emulator.cmd"
if errorlevel 1 (
  echo Emulator failed to start - aborting.
  exit /b 1
)

echo [3/3] Starting app on the emulator...
cd /d %MOBILE
REM Named-pipe stdin lets hot reload be triggered via the flag files:
REM   hot_reload.flag / hot_restart.flag / quit.flag
start "MCQ Pipe Server" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%MOBILE%\flutter_stdin_server.ps1"
ping -n 3 127.0.0.1 >nul
start "MCQ App" /min "%MOBILE%\run_app.cmd"

echo.
echo Ready. The app is running on the Pixel 6 emulator against the local backend.
echo   hot reload : type "%MOBILE%\hot_reload.flag"  (touch) to hot reload
echo   hot restart: type "%MOBILE%\hot_restart.flag" (touch) to hot restart
echo   app logs   : %MOBILE%\flutter_run_current.log
echo   api logs   : %ROOT%\backend\server.log
echo.
endlocal
