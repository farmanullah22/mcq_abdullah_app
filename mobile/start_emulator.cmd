@echo off
REM Starts the Pixel_6 emulator (native Pixel 6 skin, 1080x2400 @ 420dpi),
REM cold-boots it and waits until Android reports boot complete.
REM NOTE: use "ping -n" for delays; "timeout" refuses to run when stdin is redirected.
setlocal
set ADB=C:\Users\T460s\AppData\Local\Android\Sdk\platform-tools\adb.exe
set EMU=C:\Users\T460s\AppData\Local\Android\Sdk\emulator\emulator.exe

echo [1/4] Killing any running emulator...
"%ADB%" emu kill >nul 2>&1
ping -n 4 127.0.0.1 >nul
taskkill /F /IM emulator.exe >nul 2>&1
taskkill /F /IM qemu-system-x86_64.exe >nul 2>&1
ping -n 3 127.0.0.1 >nul

echo [2/4] Stopping Gradle daemons to free RAM...
cd /d E:\MCQ_Abdullah\mobile\android
call gradlew.bat --stop >nul 2>&1
cd /d E:\MCQ_Abdullah\mobile

echo [3/4] Starting Pixel_6 (cold boot, native skin, 1536MB, gpu host)...
start "" "%EMU%" -avd Pixel_6 -no-snapshot-load -no-snapshot-save -no-boot-anim -no-audio -gpu host -memory 1536

echo [4/4] Waiting for boot to complete...
for /l %%i in (1,1,60) do (
  "%ADB%" -s emulator-5554 shell getprop sys.boot_completed > "%TEMP%\boot.txt" 2>nul
  findstr /C:"1" "%TEMP%\boot.txt" >nul 2>&1 && (
    echo BOOT COMPLETED after %%i checks.
    "%ADB%" devices
    exit /b 0
  )
  ping -n 9 127.0.0.1 >nul
)
echo TIMEOUT: emulator did not finish booting.
exit /b 1
