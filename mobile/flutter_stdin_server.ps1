# Named-pipe stdin server for `flutter run`.
#
# Lets another process send hot-reload commands to a `flutter run` that was
# started with:  flutter run ... -RedirectStandardInput \\.\pipe\mcqflutter
#
# Control files (create the file to trigger, it is consumed automatically):
#   hot_reload.flag   -> hot reload   (same as pressing "r")
#   hot_restart.flag  -> hot restart  (same as pressing "R")
#   quit.flag         -> stop the app (same as pressing "q")
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File flutter_stdin_server.ps1

$ErrorActionPreference = 'Continue'

$root      = 'E:\MCQ_Abdullah\mobile'
$pipeName  = 'mcqflutter'
$reloadFl  = Join-Path $root 'hot_reload.flag'
$restartFl = Join-Path $root 'hot_restart.flag'
$quitFl    = Join-Path $root 'quit.flag'
$logFile   = Join-Path $root 'flutter_stdin.log'

Remove-Item $reloadFl, $restartFl, $quitFl -ErrorAction SilentlyContinue
Set-Content -LiteralPath $logFile -Value '' -Encoding utf8

function Write-Log([string]$msg) {
  $line = "[{0}] {1}" -f (Get-Date -f 'HH:mm:ss'), $msg
  Add-Content -LiteralPath $logFile -Value $line -Encoding utf8
}

Write-Log "pipe server starting on \\.\pipe\$pipeName"

$pipe = New-Object System.IO.Pipes.NamedPipeServerStream(
  $pipeName,
  [System.IO.Pipes.PipeDirection]::Out,
  1,                                   # maxNumberOfServerInstances
  [System.IO.Pipes.PipeTransmissionMode]::Byte,
  [System.IO.Pipes.PipeOptions]::Asynchronous
)

$pipe.WaitForConnection()
Write-Log "client connected (flutter run stdin)"

try {
  while ($true) {
    if (Test-Path $reloadFl) {
      Remove-Item $reloadFl -ErrorAction SilentlyContinue
      $pipe.Write([char]'r', 0, 1); $pipe.Flush()
      Write-Log "-> hot reload"
    }
    if (Test-Path $restartFl) {
      Remove-Item $restartFl -ErrorAction SilentlyContinue
      $pipe.Write([char]'R', 0, 1); $pipe.Flush()
      Write-Log "-> hot restart"
    }
    if (Test-Path $quitFl) {
      Remove-Item $quitFl -ErrorAction SilentlyContinue
      $pipe.Write([char]'q', 0, 1); $pipe.Flush()
      Write-Log "-> quit"
    }
    Start-Sleep -Milliseconds 250
  }
}
finally {
  Write-Log "pipe server exiting"
  $pipe.Dispose()
}
