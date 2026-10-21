@echo off
REM Runs the Flutter app on the emulator with stdin bound to the named pipe
REM \\.\pipe\mcqflutter so hot reload can be triggered by flutter_stdin_server.ps1
REM (create hot_reload.flag / hot_restart.flag / quit.flag in this folder).
setlocal
cd /d E:\MCQ_Abdullah\mobile

set DART=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter\bin\cache\dart-sdk\bin\dart.exe
set PKG=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter\packages\flutter_tools\.dart_tool\package_config.json
set SNAP=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter\bin\cache\flutter_tools.snapshot
set FLUTTER_ROOT=C:\Users\T460s\dev\flutter_windows_3.32.4-stable\flutter

"%DART%" --packages="%PKG%" "%SNAP%" run -d emulator-5554 < \\.\pipe\mcqflutter > flutter_run_current.log 2> flutter_run_err.log
endlocal
