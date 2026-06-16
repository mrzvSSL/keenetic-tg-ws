#!/bin/sh
# Build a source tarball for Keenetic / Entware deployment.
# Usage: sh packaging/keenetic/build-package.sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
VERSION="$(grep -E '^__version__' "$ROOT/proxy/__init__.py" | sed -E "s/.*\"([^\"]+)\".*/\1/")"
STAGE="$(mktemp -d)"
PKG_NAME="tg-ws-proxy-keenetic-mipsel-${VERSION}"
PKG_DIR="$STAGE/$PKG_NAME"

mkdir -p "$PKG_DIR"
cp -R "$ROOT/proxy" "$PKG_DIR/"
cp "$ROOT/LICENSE" "$PKG_DIR/"
cp "$ROOT/packaging/keenetic/install.sh" "$PKG_DIR/"
cp "$ROOT/packaging/keenetic/tgwproxy" "$PKG_DIR/"
cp "$ROOT/packaging/keenetic/S99tgwproxy" "$PKG_DIR/"
cp "$ROOT/packaging/keenetic/tgwproxy.conf.example" "$PKG_DIR/"

chmod 755 "$PKG_DIR/install.sh" "$PKG_DIR/tgwproxy" "$PKG_DIR/S99tgwproxy"

OUT="$ROOT/dist/${PKG_NAME}.tar.gz"
mkdir -p "$ROOT/dist"
tar -C "$STAGE" -czf "$OUT" "$PKG_NAME"
rm -rf "$STAGE"

echo "Created: $OUT"
ls -lh "$OUT"
