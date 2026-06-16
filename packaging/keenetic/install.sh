#!/bin/sh
# Install TG WS Proxy on Keenetic / Entware (mipsel, arm, aarch64).
# Run on the router after copying the package tarball:
#   tar -xzf tg-ws-proxy-keenetic-*.tar.gz -C /tmp
#   sh /tmp/tg-ws-proxy-keenetic-*/install.sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP_ROOT="/opt/share/tg-ws-proxy"
ETC_DIR="/opt/etc/tg-ws-proxy"
BIN_LINK="/opt/bin/tgwproxy"
INIT_DST="/opt/etc/init.d/S99tgwproxy"

if [ ! -x /opt/bin/opkg ]; then
    echo "Entware not found (/opt/bin/opkg)." >&2
    echo "Install Entware on internal storage or USB — see docs/README.keenetic.md" >&2
    exit 1
fi

ARCH="$(/opt/bin/opkg print-architecture 2>/dev/null | awk '/arch /{print $2; exit}')"
echo "Entware architecture: ${ARCH:-unknown}"

echo "Installing dependencies..."
/opt/bin/opkg update
# python3-light is minimal; proxy needs these stdlib splits on Entware.
/opt/bin/opkg install \
    python3-light \
    python3-asyncio \
    python3-logging \
    python3-urllib \
    python3-email \
    python3-idna \
    python3-codecs \
    python3-ctypes \
    python3-openssl \
    libopenssl \
    ca-bundle \
    ca-certificates

echo "Installing application to $APP_ROOT ..."
rm -rf "$APP_ROOT"
mkdir -p "$APP_ROOT"
cp -R "$SCRIPT_DIR/proxy" "$APP_ROOT/"
cp "$SCRIPT_DIR/LICENSE" "$APP_ROOT/" 2>/dev/null || true

mkdir -p "$ETC_DIR"
if [ ! -f "$ETC_DIR/tgwproxy.conf" ]; then
    cp "$SCRIPT_DIR/tgwproxy.conf.example" "$ETC_DIR/tgwproxy.conf"
fi

if [ -f "$ETC_DIR/tgwproxy.conf" ]; then
    [ -n "${TGWS_PORT:-}" ] && sed -i "s/^PORT=.*/PORT=$TGWS_PORT/" "$ETC_DIR/tgwproxy.conf"
    [ -n "${TGWS_POOL_SIZE:-}" ] && sed -i "s/^POOL_SIZE=.*/POOL_SIZE=$TGWS_POOL_SIZE/" "$ETC_DIR/tgwproxy.conf"
    [ -n "${TGWS_BUF_KB:-}" ] && sed -i "s/^BUF_KB=.*/BUF_KB=$TGWS_BUF_KB/" "$ETC_DIR/tgwproxy.conf"
    [ -n "${TGWS_NO_CFPROXY:-}" ] && sed -i "s/^NO_CFPROXY=.*/NO_CFPROXY=$TGWS_NO_CFPROXY/" "$ETC_DIR/tgwproxy.conf"
fi

cp "$SCRIPT_DIR/tgwproxy" "$BIN_LINK"
cp "$SCRIPT_DIR/S99tgwproxy" "$INIT_DST"
chmod 755 "$BIN_LINK" "$INIT_DST"

if [ ! -f "$ETC_DIR/secret" ]; then
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 16 >"$ETC_DIR/secret"
    else
        /opt/bin/python3 -c 'import os; print(os.urandom(16).hex())' >"$ETC_DIR/secret"
    fi
    chmod 600 "$ETC_DIR/secret"
fi

echo ""
echo "=== TG WS Proxy installed ==="
echo "Config:  $ETC_DIR/tgwproxy.conf"
echo "Secret:  $ETC_DIR/secret"
echo "Logs:    /opt/var/log/tg-ws-proxy.log"
echo ""
echo "Start:   /opt/etc/init.d/S99tgwproxy start"
echo "Status:  /opt/etc/init.d/S99tgwproxy status"
echo "Link:    grep 'tg://proxy' /opt/var/log/tg-ws-proxy.log"
echo ""
echo "На Keenetic откройте порт $(
    grep -E '^PORT=' "$ETC_DIR/tgwproxy.conf" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 1443
) для LAN, если включён межсетевой экран."
