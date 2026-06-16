# TG WS Proxy — запуск установщика Keenetic на Windows
# Требуется: Git Bash, WSL или OpenSSH + curl в PATH
#
#   powershell -ExecutionPolicy Bypass -File packaging\keenetic\install-keenetic.ps1

$ErrorActionPreference = "Stop"

$RepoRaw = if ($env:TGWS_REPO_RAW) { $env:TGWS_REPO_RAW } else {
    "https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main"
}
$InstallerUrl = "$RepoRaw/packaging/keenetic/install-keenetic.sh"

$bash = $null
foreach ($candidate in @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "bash",
    "wsl"
)) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $bash = $candidate
        break
    }
}

if (-not $bash) {
    Write-Host "Не найден bash (Git Bash или WSL)." -ForegroundColor Red
    Write-Host ""
    Write-Host "Вариант 1 — установите Git for Windows и повторите."
    Write-Host "Вариант 2 — вручную в Git Bash:"
    Write-Host "  curl -sL $InstallerUrl | bash"
    exit 1
}

Write-Host "Запуск установщика через: $bash" -ForegroundColor Green
Write-Host ""

if ($bash -eq "wsl") {
    wsl bash -c "curl -fsSL '$InstallerUrl' | bash"
} else {
    & $bash -lc "curl -fsSL '$InstallerUrl' | bash"
}
