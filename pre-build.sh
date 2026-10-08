#!/usr/bin/env bash

# OpenVPN 2.6.14 + Tunnelblick XOR/Scramble
# for Padavan-NG / padavan-builder-workflow

OVPN_VER="2.6.14"
OVPN_DIR="padavan-ng/trunk/user/openvpn"
OVPN_MAKEFILE="${OVPN_DIR}/Makefile"
OVPN_PATCH="${OVPN_DIR}/openvpn-orig.patch"

OPENVPN_URL="https://github.com/OpenVPN/openvpn/archive/refs/tags/v${OVPN_VER}.tar.gz"

XOR_BASE="https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-${OVPN_VER}/patches"

die()
{
    echo
    echo "::error::$1"
    echo "========== PRE-BUILD FAILED =========="
    exit 1
}

echo
echo "=================================================="
echo " OpenVPN ${OVPN_VER} + XOR/Scramble for Padavan"
echo "=================================================="

# --------------------------------------------------
# 1. Проверяем структуру Padavan
# --------------------------------------------------

[ -d "$OVPN_DIR" ] || die "OpenVPN directory not found: $OVPN_DIR"
[ -f "$OVPN_MAKEFILE" ] || die "OpenVPN Makefile not found"
[ -f "$OVPN_PATCH" ] || die "openvpn-orig.patch not found"

echo "[1/6] Padavan OpenVPN directory found"

# --------------------------------------------------
# 2. Меняем OpenVPN 2.6.15 -> 2.6.14
# --------------------------------------------------

sed -i \
    "s/^SRC_NAME=.*/SRC_NAME=openvpn-${OVPN_VER}/" \
    "$OVPN_MAKEFILE" \
    || die "Cannot change SRC_NAME"

sed -i \
    "s|^SRC_URL=.*|SRC_URL=${OPENVPN_URL}|" \
    "$OVPN_MAKEFILE" \
    || die "Cannot change SRC_URL"

grep -q "^SRC_NAME=openvpn-${OVPN_VER}$" "$OVPN_MAKEFILE" \
    || die "SRC_NAME was not changed"

echo "[2/6] OpenVPN version changed to ${OVPN_VER}"

# --------------------------------------------------
# 3. Скачиваем XOR/Scramble patches
# --------------------------------------------------

TMPDIR_XOR="$(mktemp -d)" || die "Cannot create temp directory"

PATCHES="
02-tunnelblick-openvpn_xorpatch-a.diff
03-tunnelblick-openvpn_xorpatch-b.diff
04-tunnelblick-openvpn_xorpatch-c.diff
05-tunnelblick-openvpn_xorpatch-d.diff
06-tunnelblick-openvpn_xorpatch-e.diff
"

echo "[3/6] Downloading Tunnelblick XOR patches"

for P in $PATCHES
do
    echo "      -> $P"

    wget -q \
        --no-check-certificate \
        "${XOR_BASE}/${P}" \
        -O "${TMPDIR_XOR}/${P}" \
        || die "Cannot download $P"

    [ -s "${TMPDIR_XOR}/${P}" ] \
        || die "$P is empty"

    grep -q "^diff " "${TMPDIR_XOR}/${P}" \
        || die "$P does not look like a valid patch"
done

# --------------------------------------------------
# 4. Добавляем XOR patches к Padavan openvpn patch
# --------------------------------------------------

echo "[4/6] Adding XOR patches to Padavan patch"

for P in $PATCHES
do
    printf '\n' >> "$OVPN_PATCH" \
        || die "Cannot modify openvpn-orig.patch"

    cat "${TMPDIR_XOR}/${P}" >> "$OVPN_PATCH" \
        || die "Cannot append $P"
done

# Убеждаемся, что scramble реально появился в patch
grep -q '"scramble"' "$OVPN_PATCH" \
    || die "scramble option not found in combined patch"

grep -q 'xormethod' "$OVPN_PATCH" \
    || die "xormethod not found in combined patch"

grep -q 'buffer_xorptrpos' "$OVPN_PATCH" \
    || die "XOR functions not found in combined patch"

echo "      scramble       : OK"
echo "      xormethod       : OK"
echo "      buffer_xorptrpos: OK"

# --------------------------------------------------
# 5. Проверяем применение patch ДО основной сборки
# --------------------------------------------------

echo "[5/6] Testing patches against OpenVPN ${OVPN_VER}"

TARBALL="${TMPDIR_XOR}/openvpn-${OVPN_VER}.tar.gz"

wget -q \
    --no-check-certificate \
    "$OPENVPN_URL" \
    -O "$TARBALL" \
    || die "Cannot download OpenVPN ${OVPN_VER}"

[ -s "$TARBALL" ] \
    || die "Downloaded OpenVPN archive is empty"

tar -xzf "$TARBALL" -C "$TMPDIR_XOR" \
    || die "Cannot extract OpenVPN source"

PATCH_LOG="${TMPDIR_XOR}/patch-test.log"

patch \
    --dry-run \
    --batch \
    -d "${TMPDIR_XOR}/openvpn-${OVPN_VER}" \
    -p1 \
    -i "$(realpath "$OVPN_PATCH")" \
    >"$PATCH_LOG" 2>&1

PATCH_RESULT=$?

if [ "$PATCH_RESULT" -ne 0 ]; then
    echo
    echo "========== PATCH LOG =========="
    cat "$PATCH_LOG"
    echo "==============================="
    die "XOR patch test FAILED"
fi

echo "      XOR patch dry-run: SUCCESS"

# Используем уже скачанный архив при реальной сборке
cp "$TARBALL" \
   "${OVPN_DIR}/openvpn-${OVPN_VER}.tar.gz" \
   || die "Cannot copy OpenVPN archive"

# --------------------------------------------------
# 6. Финальная проверка
# --------------------------------------------------

echo "[6/6] Final check"

echo
echo "OpenVPN Makefile:"
grep -E '^SRC_NAME=|^SRC_URL=' "$OVPN_MAKEFILE"

echo
echo "=================================================="
echo " SUCCESS"
echo " OpenVPN ${OVPN_VER}"
echo " Tunnelblick XOR/Scramble ENABLED"
echo " scramble obfuscate ENABLED"
echo "=================================================="
echo

rm -rf "$TMPDIR_XOR"
