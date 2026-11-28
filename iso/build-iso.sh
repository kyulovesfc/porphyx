#!/usr/bin/env bash
# Arma la ISO: perfil releng de archiso + instalador porphyx-install (online). El escritorio se instala despues con porphyx setup.
# Requisito: tener todo commiteado (se copia porphyx/porphyx de HEAD, no del working tree).
set -Eeuo pipefail
trap 'echo "ERROR: linea $LINENO: $BASH_COMMAND" >&2' ERR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HERE/.." && pwd)"
W="$HERE/work"
OUT="$HERE/out"
RELENG=/usr/share/archiso/configs/releng

sudo rm -rf "$W"
mkdir -p "$W" "$OUT"
cp -r "$RELENG" "$W/profile"
sed -i 's|^iso_name=.*|iso_name="porphyx"|; s|^iso_application=.*|iso_application="Porphyx Linux Arch Live/Installer"|' "$W/profile/profiledef.sh"

A="$W/profile/airootfs/opt/porphyx"
mkdir -p "$A"
git -C "$REPO_DIR" archive --format=tar HEAD porphyx/porphyx porphyx/porphyx-select.sh porphyx/select-apps.sh porphyx/select-desktop.sh porphyx/categories.conf porphyx/desktops.conf | tar -x -C "$A" --strip-components=1
# KYU-ISO-CFG
python3 "$HERE/gen-config.py" "$HERE" "$A/archinstall.json"
cp -a "$HERE/overlay/." "$W/profile/"
sed -i 's|^  \["/usr/local/bin/choose-mirror"\]="0:0:755"|&\n  ["/usr/local/bin/porphyx-install"]="0:0:755"|' "$W/profile/profiledef.sh"

# KYU-ISO-NM: NetworkManager + nmtui en el live (en vez de iwd/networkd)
P="$W/profile"
grep -qx networkmanager "$P/packages.x86_64" || echo networkmanager >> "$P/packages.x86_64"
S="$P/airootfs/etc/systemd/system"
rm -f "$S/multi-user.target.wants/iwd.service" \
      "$S/multi-user.target.wants/systemd-networkd.service" \
      "$S/network-online.target.wants/systemd-networkd-wait-online.service" \
      "$S"/sockets.target.wants/systemd-networkd*.socket
ln -sf /usr/lib/systemd/system/NetworkManager.service "$S/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service "$S/dbus-org.freedesktop.nm-dispatcher.service"
mkdir -p "$S/network-online.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service "$S/network-online.target.wants/NetworkManager-wait-online.service"

# KYU-ISO-BRAND
bash "$HERE/brand.sh" "$W/profile" "$REPO_DIR"
sudo mkarchiso -v -w "$W/work" -o "$OUT" "$W/profile"
/usr/bin/ls -lh "$OUT"
