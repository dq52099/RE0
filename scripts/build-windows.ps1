param([switch]$SkipChecks)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$raw = (Select-String '^version:\s*(.+)$' pubspec.yaml).Matches[0].Groups[1].Value.Trim()
$version, $code = $raw.Split('+')
if ($version -notmatch '^\d+\.\d+\.\d+$' -or $code -notmatch '^\d+$') { throw 'Invalid pubspec version' }
flutter pub get
if ($LASTEXITCODE) { throw 'Dependency resolution failed' }
if (!$SkipChecks) {
  flutter analyze
  if ($LASTEXITCODE) { throw 'Analysis failed' }
  flutter test --concurrency=2
  if ($LASTEXITCODE) { throw 'Tests failed' }
}
flutter build windows --release --dart-define=RE0_VERSION_NAME=$version --dart-define=RE0_VERSION_CODE=$code --dart-define=RE0_RELEASE_TAG=v$version
if ($LASTEXITCODE) { throw 'Windows build failed' }
$bundle = 'build/windows/x64/runner/Release'
foreach ($file in @('RE0.exe','flutter_windows.dll','data/app.so','data/icudtl.dat')) {
  if (!(Test-Path "$bundle/$file")) { throw "Missing runtime file: $file" }
}
New-Item -ItemType Directory -Force build/release | Out-Null
$compiler = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (!(Test-Path $compiler)) { throw 'Install Inno Setup 6 before packaging' }
& $compiler "/DAppVersion=$version" installer/re0.iss
if ($LASTEXITCODE) { throw 'Installer packaging failed' }
$installer = Get-Item "build/release/RE0-$version-windows-x64-setup.exe"
Compress-Archive -Path "$bundle/*" -DestinationPath "build/release/RE0-$version-windows-x64-portable.zip" -Force
$manifest = [ordered]@{
  platform='windows-x64'; version_name=$version; version_code=[int]$code
  file_name=$installer.Name; file_size=$installer.Length
  sha256=(Get-FileHash $installer.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  download_url="https://work.6688667.xyz/boxying-desktop/$($installer.Name)"
  release_notes='首次 Windows 安装版：自适应创作工作台、键盘操作、图片另存为、桌面头像裁剪与独立更新。'
}
$manifest | ConvertTo-Json | Set-Content -Encoding utf8 build/release/manifest.json
