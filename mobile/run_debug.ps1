Set-Location 'E:\MCQ_Abdullah\mobile'
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000/api 2>&1 | Tee-Object -FilePath 'E:\MCQ_Abdullah\mobile\flutter_run_current.log'
Write-Host ''
Write-Host '--- flutter run exited ---' -ForegroundColor Yellow