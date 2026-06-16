#!/bin/sh
# TG WS Proxy — установка на роутере (Entware / Keenetic).
# Вызывается с ПК через SSH или вручную: wget -qO- URL | exec sh
#
# Переменные окружения (опционально):
#   TGWS_TARBALL_URL   — URL архива .tar.gz
#   TGWS_VERSION       — версия для URL релиза (по умолчанию из скрипта)
#   TGWS_PORT          — порт прокси (1443)
#   TGWS_POOL_SIZE     — pool size (2)
#   TGWS_BUF_KB        — буфер KB (128)
#   TGWS_NO_CFPROXY    — 1 отключить CF fallback
#   TGWS_NONINTERACTIVE — 1 без вопросов
#   TGWS_REPO_RAW      — базовый URL raw GitHub

set -e

TGWS_VERSION="${TGWS_VERSION:-1.7.2}"
TGWS_REPO_RAW="${TGWS_REPO_RAW:-https://raw.githubusercontent.com/Flowseal/tg-ws-proxy/main}"
TGWS_RELEASE_BASE="${TGWS_RELEASE_BASE:-https://github.com/Flowseal/tg-ws-proxy/releases/download/v${TGWS_VERSION}}"
TGWS_WORK="${TGWS_WORK:-/storage/tmp/tg-ws-proxy-install}"
TGWS_PORT="${TGWS_PORT:-1443}"
TGWS_POOL_SIZE="${TGWS_POOL_SIZE:-2}"
TGWS_BUF_KB="${TGWS_BUF_KB:-128}"
TGWS_NO_CFPROXY="${TGWS_NO_CFPROXY:-0}"

log() { printf '%s\n' "$*"; }
die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }

prompt() {
    _default="$1"
    _question="$2"
    if [ -n "${TGWS_NONINTERACTIVE:-}" ]; then
        printf '%s' "$_default"
        return
    fi
    if [ ! -t 0 ] && [ -z "${TGWS_FORCE_INTERACTIVE:-}" ]; then
        printf '%s' "$_default"
        return
    fi
    printf '%s [%s]: ' "$_question" "$_default"
    read -r _ans
    if [ -z "$_ans" ]; then
        printf '%s' "$_default"
    else
        printf '%s' "$_ans"
    fi
}

confirm() {
    _question="$1"
    _default="${2:-y}"
    if [ -n "${TGWS_NONINTERACTIVE:-}" ]; then
        [ "$_default" = "y" ]
        return
    fi
    if [ ! -t 0 ]; then
        [ "$_default" = "y" ]
        return
    fi
    printf '%s [y/N]: ' "$_question"
    read -r _ans
    case "$_ans" in
        y|Y|yes|YES|д|Д|да|Да) return 0 ;;
        *) return 1 ;;
    esac
}

detect_entware_arch() {
    if [ -x /opt/bin/opkg ]; then
        /opt/bin/opkg print-architecture 2>/dev/null | awk '/arch /{print $2; exit}'
        return
    fi
    _m="$(uname -m 2>/dev/null || true)"
    case "$_m" in
        aarch64|arm64) printf 'aarch64' ;;
        mips|mipsel) printf 'mipsel' ;;
        *) printf 'mipsel' ;;
    esac
}

pick_tarball_url() {
    if [ -n "${TGWS_TARBALL_URL:-}" ]; then
        printf '%s' "$TGWS_TARBALL_URL"
        return
    fi
    _arch="$(detect_entware_arch)"
    case "$_arch" in
        aarch64|arm64)
            printf '%s/tg-ws-proxy-keenetic-aarch64-%s.tar.gz' "$TGWS_RELEASE_BASE" "$TGWS_VERSION"
            ;;
        *)
            printf '%s/tg-ws-proxy-keenetic-mipsel-%s.tar.gz' "$TGWS_RELEASE_BASE" "$TGWS_VERSION"
            ;;
    esac
}

download() {
    _url="$1"
    _dest="$2"
    case "$_url" in
        file://*)
            _src="${_url#file://}"
            cp "$_src" "$_dest" && return 0
            return 1
            ;;
    esac
    if [ -x /opt/bin/wget ]; then
        /opt/bin/wget -qO "$_dest" "$_url" && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$_dest" "$_url" && return 0
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$_dest" "$_url" && return 0
    fi
    return 1
}

get_lan_ip() {
    ip -4 addr show br0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1
}

print_summary() {
    _lan="$(get_lan_ip)"
    _secret=""
    _port="$TGWS_PORT"
    if [ -f /opt/etc/tg-ws-proxy/secret ]; then
        _secret="$(tr -d ' \n\r\t' < /opt/etc/tg-ws-proxy/secret)"
    fi
    log ""
    log "=============================================="
    log "  TG WS Proxy установлен"
    log "=============================================="
    log "  LAN IP:   ${_lan:-?}"
    log "  Порт:     $_port"
    log "  Secret:   $_secret"
    log ""
    if [ -n "$_lan" ] && [ -n "$_secret" ]; then
        log "  Ссылка для Telegram:"
        log "  tg://proxy?server=${_lan}&port=${_port}&secret=dd${_secret}"
    fi
    log ""
    log "  Управление:"
    log "    /opt/etc/init.d/S99tgwproxy status|restart"
    log "    tail -f /opt/var/log/tg-ws-proxy.log"
    log "=============================================="
}

# --- main ---

log "TG WS Proxy — установка на роутере"

[ -x /opt/bin/opkg ] || die "Entware не найден (/opt/bin/opkg). Сначала установите Entware."

_arch="$(detect_entware_arch)"
log "Архитектура Entware: $_arch"

if [ -z "${TGWS_NONINTERACTIVE:-}" ] && { [ -t 0 ] || [ -n "${TGWS_FORCE_INTERACTIVE:-}" ]; }; then
    TGWS_PORT="$(prompt "$TGWS_PORT" "Порт MTProto-прокси")"
    TGWS_POOL_SIZE="$(prompt "$TGWS_POOL_SIZE" "POOL_SIZE")"
    TGWS_BUF_KB="$(prompt "$TGWS_BUF_KB" "BUF_KB")"
    if confirm "Отключить Cloudflare fallback?" n; then
        TGWS_NO_CFPROXY=1
    fi
fi

_tarball="$(pick_tarball_url)"
log "Загрузка: $_tarball"

mkdir -p "$TGWS_WORK"
_pkg="$TGWS_WORK/package.tar.gz"
download "$_tarball" "$_pkg" || die "Не удалось скачать архив. Укажите TGWS_TARBALL_URL или загрузите .tar.gz вручную."

cd "$TGWS_WORK"
tar -xzf "$_pkg"
_pkgdir="$(find "$TGWS_WORK" -maxdepth 1 -type d -name 'tg-ws-proxy-keenetic-*' | head -1)"
[ -n "$_pkgdir" ] || die "Неверный формат архива"

export TGWS_PORT TGWS_POOL_SIZE TGWS_BUF_KB TGWS_NO_CFPROXY
sh "$_pkgdir/install.sh"

if confirm "Запустить прокси сейчас?" y; then
    /opt/etc/init.d/S99tgwproxy restart || /opt/etc/init.d/S99tgwproxy start
    sleep 3
    /opt/etc/init.d/S99tgwproxy status || true
fi

print_summary
