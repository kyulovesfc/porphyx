#!/usr/bin/env bash
# timeshift-setup.sh — deja Timeshift preconfigurado. Se llama desde porphyx-setup.sh (como root).
# Detecta si / es btrfs (modo BTRFS) o no (modo RSYNC). Nunca sobrescribe una config existente.
set -Eeuo pipefail
trap 'echo "ERROR: linea $LINENO: $BASH_COMMAND" >&2' ERR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
TEMPLATE="$REPO/config/timeshift/timeshift.json.in"
DEST=/etc/timeshift/timeshift.json

[ "$(id -u)" -eq 0 ] || { echo "ABORT: correr con sudo" >&2; exit 1; }
command -v timeshift >/dev/null 2>&1 || { echo "ABORT: falta timeshift (official-packages.txt)" >&2; exit 1; }
[ -f "$TEMPLATE" ] || { echo "ABORT: falta $TEMPLATE" >&2; exit 1; }

ROOT_FS="$(findmnt -no FSTYPE /)"
ROOT_UUID="$(findmnt -no UUID /)"
[ -n "$ROOT_UUID" ] || { echo "ABORT: no pude leer el UUID de /" >&2; exit 1; }
if [ "$ROOT_FS" = btrfs ]; then BTRFS=true; else BTRFS=false; fi

install -d -m 755 /etc/timeshift
if [ -f "$DEST" ]; then
  echo "= $DEST ya existe, no lo toco"
else
  sed -e "s/@UUID@/$ROOT_UUID/" -e "s/@BTRFS@/$BTRFS/" "$TEMPLATE" > "$DEST"
  python3 -m json.tool "$DEST" >/dev/null || { rm -f "$DEST"; echo "ABORT: json invalido" >&2; exit 1; }
  chmod 644 "$DEST"
  echo "+ $DEST (fs=$ROOT_FS, btrfs_mode=$BTRFS)"
fi

for u in timeshift-boot.service timeshift-hourly.timer timeshift-daily.timer timeshift-weekly.timer timeshift-monthly.timer; do
  if systemctl list-unit-files "$u" --no-legend 2>/dev/null | grep -q .; then
    systemctl enable --now "$u" >/dev/null && echo "+ $u"
  fi
done
echo "✓ timeshift listo (los horarios los decide timeshift.json)"
