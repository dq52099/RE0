$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$installer = (Get-ChildItem 'build/release/*-setup.exe' | Select-Object -First 1).FullName
$testRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$destination = Join-Path $testRoot 're0-install-test'
$install = Start-Process $installer -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=`"$destination`"" -Wait -PassThru
if ($install.ExitCode -ne 0) { throw "Installer failed: $($install.ExitCode)" }
$app = Start-Process "$destination/RE0.exe" -WorkingDirectory $destination -PassThru
try {
  $ready = $false
  for ($attempt=0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Seconds 2
    $app.Refresh()
    if ($app.HasExited) { throw "Application exited: $($app.ExitCode)" }
    if ($app.MainWindowHandle -ne 0 -and $app.Responding) { $ready = $true; break }
  }
  if (!$ready) { throw 'Application did not create a responsive window' }
  Add-Type -AssemblyName System.Windows.Forms,System.Drawing
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width,$bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
  $bitmap.Save((Join-Path (Get-Location) 'build/release/windows-smoke.png'))
  $graphics.Dispose(); $bitmap.Dispose()
  @{responsive=$app.Responding;title=$app.MainWindowTitle;installed=$true} | ConvertTo-Json | Set-Content build/release/windows-smoke.json
} finally {
  if (!$app.HasExited) { $app.CloseMainWindow() | Out-Null; if (!$app.WaitForExit(10000)) { $app.Kill() } }
}
$uninstall = Start-Process "$destination/unins000.exe" -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru -Wait
if ($uninstall.ExitCode -ne 0) { throw 'Uninstall failed' }
if (Test-Path "$destination/RE0.exe") { throw 'Application remained after uninstall' }
