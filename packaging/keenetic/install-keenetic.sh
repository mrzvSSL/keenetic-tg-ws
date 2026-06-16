#!/usr/bin/env bash
# TG WS Proxy — установщик «под ключ» для Keenetic (с ПК по SSH).
#
# Однострочник (Linux / macOS / Git Bash на Windows):
#   curl -sL https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main/packaging/keenetic/install-keenetic.sh | bash
#
# С параметрами:
#   TGWS_ROUTER_IP=192.168.1.1 TGWS_ROUTER_PASS=secret bash install-keenetic.sh
#
# Переменные:
#   TGWS_ROUTER_IP      — IP роутера (спросит, если пусто)
#   TGWS_ROUTER_USER    — логин SSH (admin)
#   TGWS_ROUTER_PASS    — пароль (иначе интерактивно / SSH-ключ)
#   TGWS_STORAGE        — storage:/ | USB-метка (storage:/ по умолчанию)
#   TGWS_ENTWARE_ARCH   — mipsel | aarch64 (автоопределение)
#   TGWS_SKIP_ENTWARE   — 1 если Entware уже установлен
#   TGWS_REPO_RAW       — URL raw-файлов GitHub
#   TGWS_VERSION        — версия релиза
#   TGWS_NONINTERACTIVE — 1 без вопросов

set -euo pipefail

TGWS_VERSION="${TGWS_VERSION:-1.7.2}"
TGWS_REPO_RAW="${TGWS_REPO_RAW:-https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main}"
TGWS_ROUTER_USER="${TGWS_ROUTER_USER:-admin}"
TGWS_ROUTER_IP="${TGWS_ROUTER_IP:-}"
TGWS_STORAGE="${TGWS_STORAGE:-storage:/}"
TGWS_PORT="${TGWS_PORT:-1443}"
TGWS_POOL_SIZE="${TGWS_POOL_SIZE:-2}"
TGWS_BUF_KB="${TGWS_BUF_KB:-128}"
TGWS_ENTWARE_WAIT="${TGWS_ENTWARE_WAIT:-900}"

ENTWARE_URL_MIPSEL="https://bin.entware.net/mipselsf-k3.4/installer/mipsel-installer.tar.gz"
ENTWARE_URL_AARCH64="https://bin.entware.net/aarch64-k3.10/installer/aarch64-installer.tar.gz"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { printf "${GREEN}==>${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!!>${NC} %s\n" "$*"; }
err()  { printf "${RED}ERR>${NC} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

prompt() {
    local default="$1" question="$2" answer=""
    if [[ -n "${TGWS_NONINTERACTIVE:-}" ]]; then
        echo "$default"
        return
    fi
    read -r -p "$question [$default]: " answer
    if [[ -z "$answer" ]]; then echo "$default"; else echo "$answer"; fi
}

confirm() {
    local question="$1" default="${2:-y}"
    if [[ -n "${TGWS_NONINTERACTIVE:-}" ]]; then
        [[ "$default" == "y" ]]
        return
    fi
    local answer=""
    read -r -p "$question [y/N]: " answer
    case "$answer" in
        y|Y|yes|YES|д|Д|да|Да) return 0 ;;
        *) return 1 ;;
    esac
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Нужна команда: $1"
}

ssh_cmd() {
    local cmd="$1"
    if [[ -n "${TGWS_ROUTER_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
        sshpass -p "$TGWS_ROUTER_PASS" ssh "${SSH_OPTS[@]}" "$TGWS_ROUTER_USER@$TGWS_ROUTER_IP" "$cmd"
    else
        ssh "${SSH_OPTS[@]}" "$TGWS_ROUTER_USER@$TGWS_ROUTER_IP" "$cmd"
    fi
}

ssh_cli() {
    local cmd="$1"
    ssh_cmd "$cmd"
}

ssh_shell() {
    local script="$1"
    ssh_cmd "exec sh -c $(printf '%q' "$script")"
}

fetch_router_info() {
  ssh_cli "show version" 2>/dev/null || true
}

guess_entware_arch() {
    local info="$1"
    if [[ -n "${TGWS_ENTWARE_ARCH:-}" ]]; then
        echo "$TGWS_ENTWARE_ARCH"
        return
    fi
    if echo "$info" | grep -qiE 'aarch64|arm64|mt798|mt7622|kn-3[4-9]|kn-4'; then
        echo "aarch64"
        return
    fi
    if echo "$info" | grep -qiE '"arch"[[:space:]]*:[[:space:]]*"aarch64"'; then
        echo "aarch64"
        return
    fi
    echo "mipsel"
}

entware_url_for() {
    case "$1" in
        aarch64|arm64) echo "$ENTWARE_URL_AARCH64" ;;
        *) echo "$ENTWARE_URL_MIPSEL" ;;
    esac
}

entware_installed() {
    ssh_shell "test -x /opt/bin/opkg" 2>/dev/null
}

wait_entware() {
    local deadline=$((SECONDS + TGWS_ENTWARE_WAIT))
    log "Ожидание установки Entware (до $((TGWS_ENTWARE_WAIT / 60)) мин)..."
    while (( SECONDS < deadline )); do
        if entware_installed; then
            log "Entware готов"
            return 0
        fi
        sleep 10
        printf '.'
    done
    echo ""
    die "Entware не установился за отведённое время. Проверьте журнал роутера."
}

install_entware() {
    local arch="$1"
    local url
    url="$(entware_url_for "$arch")"
    log "Установка Entware ($arch) на $TGWS_STORAGE"
    warn "Убедитесь: Приложения → OPKG → накопитель выбран и «Доступ» включён"
    ssh_cli "no opkg disk" 2>/dev/null || true
    ssh_cli "opkg disk $TGWS_STORAGE $url"
    wait_entware
}

run_remote_installer() {
    log "Загрузка и запуск install-remote.sh на роутере..."

    local pipe_script
    pipe_script="$(mktemp)"
    trap 'rm -f "$pipe_script"' RETURN

    {
        printf 'export TGWS_VERSION=%q\n' "$TGWS_VERSION"
        printf 'export TGWS_REPO_RAW=%q\n' "$TGWS_REPO_RAW"
        printf 'export TGWS_PORT=%q\n' "$TGWS_PORT"
        printf 'export TGWS_POOL_SIZE=%q\n' "$TGWS_POOL_SIZE"
        printf 'export TGWS_BUF_KB=%q\n' "$TGWS_BUF_KB"
        [[ -n "${TGWS_NONINTERACTIVE:-}" ]] && printf 'export TGWS_NONINTERACTIVE=1\n'
        [[ -n "${TGWS_TARBALL_URL:-}" ]] && printf 'export TGWS_TARBALL_URL=%q\n' "$TGWS_TARBALL_URL"
        curl -fsSL "$TGWS_REPO_RAW/packaging/keenetic/install-remote.sh"
    } >"$pipe_script"

    if [[ -n "${TGWS_ROUTER_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
        sshpass -p "$TGWS_ROUTER_PASS" ssh -t "${SSH_OPTS[@]}" "$TGWS_ROUTER_USER@$TGWS_ROUTER_IP" "exec sh" <"$pipe_script"
    else
        ssh -t "${SSH_OPTS[@]}" "$TGWS_ROUTER_USER@$TGWS_ROUTER_IP" "exec sh" <"$pipe_script"
    fi
}

banner() {
    cat <<'BANNER'

  ╔══════════════════════════════════════════╗
  ║   TG WS Proxy — установщик для Keenetic  ║
  ║   MTProto-прокси на роутере (без флешки) ║
  ╚══════════════════════════════════════════╝

BANNER
}

main() {
    banner
    need_cmd ssh
    need_cmd curl
    if [[ -f "dist/tg-ws-proxy-keenetic-mipsel-${TGWS_VERSION}.tar.gz" ]] || \
       [[ -f "dist/tg-ws-proxy-keenetic-aarch64-${TGWS_VERSION}.tar.gz" ]]; then
        need_cmd scp
    fi

    SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

    if [[ -z "$TGWS_ROUTER_IP" ]]; then
        TGWS_ROUTER_IP="$(prompt "192.168.1.1" "IP роутера Keenetic")"
    fi

    log "Проверка SSH: $TGWS_ROUTER_USER@$TGWS_ROUTER_IP"
    ssh_cmd "show version" >/dev/null || die "Не удалось подключиться по SSH. Включите «Сервер SSH» и доступ для пользователя."

    local version_info
    version_info="$(fetch_router_info)"
    local model arch
    model="$(echo "$version_info" | grep -oE 'KN-[0-9]+' | head -1 || true)"
    arch="$(guess_entware_arch "$version_info")"

    log "Модель: ${model:-неизвестна}, Entware: $arch"

    if [[ -z "${TGWS_STORAGE:-}" ]] || [[ "$TGWS_STORAGE" == "storage:/" ]]; then
        if confirm "Установить Entware на встроенное хранилище (storage:/)? (без USB)" y; then
            TGWS_STORAGE="storage:/"
        else
            TGWS_STORAGE="$(prompt "storage:/" "Укажите накопитель OPKG (storage:/ или метка USB)")"
        fi
    fi

    TGWS_PORT="$(prompt "$TGWS_PORT" "Порт прокси")"
    TGWS_POOL_SIZE="$(prompt "$TGWS_POOL_SIZE" "POOL_SIZE")"
    TGWS_BUF_KB="$(prompt "$TGWS_BUF_KB" "BUF_KB")"

    if ! entware_installed; then
        if [[ -n "${TGWS_SKIP_ENTWARE:-}" ]]; then
            die "Entware не найден, а TGWS_SKIP_ENTWARE=1"
        fi
        warn "Перед установкой Entware в веб-интерфейсе:"
        warn "  Приложения → OPKG → выберите накопитель → Доступ ✓ → Сохранить"
        if ! confirm "Продолжить установку Entware?" y; then
            die "Отменено"
        fi
        if [[ "$arch" == "aarch64" ]] && ! confirm "Определена архитектура aarch64. Верно?" y; then
            arch="mipsel"
            warn "Используем mipsel по вашему выбору"
        fi
        install_entware "$arch"
    else
        log "Entware уже установлен — пропускаем"
    fi

    local local_tarball=""
    case "$arch" in
        aarch64) local_tarball="dist/tg-ws-proxy-keenetic-aarch64-${TGWS_VERSION}.tar.gz" ;;
        *) local_tarball="dist/tg-ws-proxy-keenetic-mipsel-${TGWS_VERSION}.tar.gz" ;;
    esac
    if [[ -z "${TGWS_TARBALL_URL:-}" ]] && [[ -f "$local_tarball" ]]; then
        log "Локальный архив: $local_tarball → копируем на роутер"
        local remote_pkg="/storage/tmp/$(basename "$local_tarball")"
        if [[ -n "${TGWS_ROUTER_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
            sshpass -p "$TGWS_ROUTER_PASS" scp "${SSH_OPTS[@]}" "$local_tarball" "$TGWS_ROUTER_USER@$TGWS_ROUTER_IP:$remote_pkg"
        else
            scp "${SSH_OPTS[@]}" "$local_tarball" "$TGWS_ROUTER_USER@$TGWS_ROUTER_IP:$remote_pkg"
        fi
        TGWS_TARBALL_URL="file://$remote_pkg"
    fi

    run_remote_installer

    log "Готово!"
}

main "$@"
