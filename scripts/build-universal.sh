#!/usr/bin/env bash
set -euo pipefail

CALEN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CALEN_PRODUCT="calen"
CALEN_OUTPUT="$CALEN_ROOT/bin/$CALEN_PRODUCT"
CALEN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Aayush Pokharel (4538W4A79B)}"
CALEN_TEMP_DIR="$(mktemp -d /tmp/calen-release.XXXXXX)"

cleanup() {
  trash "$CALEN_TEMP_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "$CALEN_ROOT"

swift build -c release --product "$CALEN_PRODUCT" --arch arm64
CALEN_ARM64_DIR="$(swift build -c release --product "$CALEN_PRODUCT" --arch arm64 --show-bin-path)"
cp "$CALEN_ARM64_DIR/$CALEN_PRODUCT" "$CALEN_TEMP_DIR/$CALEN_PRODUCT-arm64"

swift build -c release --product "$CALEN_PRODUCT" --arch x86_64
CALEN_X86_DIR="$(swift build -c release --product "$CALEN_PRODUCT" --arch x86_64 --show-bin-path)"
cp "$CALEN_X86_DIR/$CALEN_PRODUCT" "$CALEN_TEMP_DIR/$CALEN_PRODUCT-x86_64"

lipo -create \
  "$CALEN_TEMP_DIR/$CALEN_PRODUCT-arm64" \
  "$CALEN_TEMP_DIR/$CALEN_PRODUCT-x86_64" \
  -output "$CALEN_TEMP_DIR/$CALEN_PRODUCT"

codesign \
  --force \
  --timestamp \
  --options runtime \
  --sign "$CALEN_IDENTITY" \
  --identifier art.aayush.calen \
  "$CALEN_TEMP_DIR/$CALEN_PRODUCT"

codesign --verify --strict --verbose=2 "$CALEN_TEMP_DIR/$CALEN_PRODUCT"
mkdir -p "$(dirname "$CALEN_OUTPUT")"
install -m 0755 "$CALEN_TEMP_DIR/$CALEN_PRODUCT" "$CALEN_OUTPUT"
lipo -archs "$CALEN_OUTPUT"
