@echo off
cd /d E:\MCQ_Abdullah\mobile
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000/api > E:\MCQ_Abdullah\mobile\flutter_run_current.log 2>&1