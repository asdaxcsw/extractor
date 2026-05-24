$ErrorActionPreference = 'Stop'
$vsix = 'c:\Users\Administrator\Desktop\cursor-free-2.4.11.vsix'
$log = 'C:\Users\Administrator\.cursor\projects\empty-window\install-vsix-log.txt'

function Log($msg) { Add-Content -Path $log -Value $msg }

"" | Set-Content -Path $log
Log "Started: $(Get-Date -Format o)"
Log "VSIX exists: $(Test-Path -LiteralPath $vsix)"

$candidates = @(
  "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd",
  "$env:LOCALAPPDATA\Programs\Cursor\resources\app\bin\cursor.cmd",
  "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe",
  "$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe",
  "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
  "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
  "$env:ProgramFiles\Cursor\Cursor.exe"
)

$cli = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cli) {
  Log "ERROR: No cursor/code CLI found. Checked:"
  $candidates | ForEach-Object { Log "  $_ -> $(Test-Path $_)" }
  exit 1
}

Log "Using CLI: $cli"
$args = @('--install-extension', $vsix)
Log "Command: $cli $($args -join ' ')"

try {
  $output = & $cli @args 2>&1 | Out-String
  Log "Output:"
  Log $output
  Log "Exit code: $LASTEXITCODE"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} catch {
  Log "EXCEPTION: $_"
  exit 1
}

Log "Done: $(Get-Date -Format o)"
