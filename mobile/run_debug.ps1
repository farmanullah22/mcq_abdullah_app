Set-Location 'E:\MCQ_Abdullah\mobile'
flutter run -d emulator-5554 2>&1 | Tee-Object -FilePath 'E:\MCQ_Abdullah\mobile\flutter_run_current.log'
Write-Host ''
Write-Host '--- flutter run exited ---' -ForegroundColor Yellow