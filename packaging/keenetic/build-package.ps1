# Build Keenetic deployment tarball on Windows.
# Usage: powershell -ExecutionPolicy Bypass -File packaging\keenetic\build-package.ps1

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Version = (Select-String -Path (Join-Path $Root "proxy\__init__.py") -Pattern '__version__ = "([^"]+)"').Matches.Groups[1].Value
$PkgName = "tg-ws-proxy-keenetic-mipsel-$Version"
$DistDir = Join-Path $Root "dist"
$StageDir = Join-Path $env:TEMP $PkgName

if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
New-Item -ItemType Directory -Path $StageDir | Out-Null

Copy-Item -Recurse (Join-Path $Root "proxy") $StageDir
Copy-Item (Join-Path $Root "LICENSE") $StageDir
Copy-Item (Join-Path $PSScriptRoot "install.sh") $StageDir
Copy-Item (Join-Path $PSScriptRoot "tgwproxy") $StageDir
Copy-Item (Join-Path $PSScriptRoot "S99tgwproxy") $StageDir
Copy-Item (Join-Path $PSScriptRoot "tgwproxy.conf.example") $StageDir

if (-not (Test-Path $DistDir)) { New-Item -ItemType Directory -Path $DistDir | Out-Null }
$Out = Join-Path $DistDir "$PkgName.tar.gz"
if (Test-Path $Out) { Remove-Item -Force $Out }

tar -czf $Out -C (Split-Path $StageDir -Parent) $PkgName
Remove-Item -Recurse -Force $StageDir

Write-Host "Created: $Out"
Get-Item $Out | Format-List FullName, Length, LastWriteTime
