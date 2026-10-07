#!/bin/sh
set -eu

OVPN_DIR="padavan-ng/trunk/user/openvpn"
OVPN_PATCH="$OVPN_DIR/openvpn-orig.patch"

BASE="https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.6.14/patches"

echo "Adding OpenVPN XOR/Scramble obfuscation patches..."

for PATCH in \
    02-tunnelblick-openvpn_xorpatch-a.diff \
    03-tunnelblick-openvpn_xorpatch-b.diff \
    04-tunnelblick-openvpn_xorpatch-c.diff \
    05-tunnelblick-openvpn_xorpatch-d.diff \
    06-tunnelblick-openvpn_xorpatch-e.diff
do
    echo "Adding $PATCH"
    printf '\n' >> "$OVPN_PATCH"
    wget -qO- "$BASE/$PATCH" >> "$OVPN_PATCH"
done

echo "OpenVPN XOR/Scramble patches added."
