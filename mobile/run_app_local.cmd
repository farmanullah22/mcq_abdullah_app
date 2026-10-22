@echo off
REM Temporary verification runner: same as run_app.cmd but points the app at
REM the LOCAL backend (which carries the product-payload fix) so the stock
REM screens can be checked before the production APK is built.
setlocal
cd /d E:\MCQ_Abdullah\mobile

set DART=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter\bin\cache\dart-sdk\bin\dart.exe
set PKG=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter\packages\flutter_tools\.dart_tool\package_config.json
set SNAP=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter\bin\cache\flutter_tools.snapshot
set FLUTTER_ROOT=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter

"%DART%" --packages="%PKG%" "%SNAP%" run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000/api < \\.\pipe\mcqflutter > flutter_run_current.log 2> flutter_run_err.log
endlocal
