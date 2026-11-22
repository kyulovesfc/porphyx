#!/usr/bin/env bash
# backlight-native.sh — deja el brillo de pantalla independiente de la dGPU en portatiles ASUS.
# Con el GUID WMI de NVIDIA presente, el kernel descarta el backlight nativo de amdgpu y deja solo
# nvidia_wmi_ec_backlight; al apagar la dGPU el brillo se pierde. acpi_backlight=native fuerza el de amdgpu.
# Requiere root. Idempotente. rc: 0 ok o nada que hacer, 1 error (revertido), 2 no se pudo aplicar.
# Sin set -e a proposito: cada paso aborta explicito.
set -uo pipefail
PARAM=acpi_backlight=native
GUID=603E9613-EF25-4338-A3D0-C46177516DB7-0
WMI_DIR=${PORPHYX_WMI_DIR:-/sys/bus/wmi/devices}
CMDLINE=${PORPHYX_CMDLINE:-/proc/cmdline}
SDCONF=${PORPHYX_SDBOOT_CONF:-/etc/sdboot-manage.conf}
STAMP=$(date +%Y%m%d-%H%M%S)
[[ $EUID -eq 0 ]] || { echo "ABORT: correr con sudo"; exit 1; }
[[ -e "$WMI_DIR/$GUID" ]] || { echo "backlight: sin backlight WMI de NVIDIA, nada que hacer"; exit 0; }
if grep -q 'acpi_backlight=' "$CMDLINE" 2>/dev/null; then
  echo "backlight: el kernel ya arranco con acpi_backlight ($(grep -o 'acpi_backlight=[^ ]*' "$CMDLINE" | head -1))"; exit 0
fi

if [[ -f "$SDCONF" ]] && command -v sdboot-manage >/dev/null 2>&1; then
  grep -q '^LINUX_OPTIONS="' "$SDCONF" || { echo "ABORT: LINUX_OPTIONS sin el formato esperado en $SDCONF"; exit 2; }
  if grep -q '^LINUX_OPTIONS=".*acpi_backlight=' "$SDCONF"; then echo "backlight: $SDCONF ya define acpi_backlight"; exit 0; fi
  cp -a "$SDCONF" "$SDCONF.bak.$STAMP" || { echo "ABORT: respaldo de $SDCONF"; exit 1; }
  sed -i "s|^LINUX_OPTIONS=\"\(.*\)\"[[:space:]]*\$|LINUX_OPTIONS=\"\1 $PARAM\"|" "$SDCONF"
  if grep -q "^LINUX_OPTIONS=\".* $PARAM\"\$" "$SDCONF" && sdboot-manage gen; then
    echo "backlight: $PARAM agregado en $SDCONF (entradas regeneradas; aplica al reiniciar)"; exit 0
  fi
  cp -a "$SDCONF.bak.$STAMP" "$SDCONF"; echo "ABORT: no pude aplicar $PARAM con sdboot-manage (restaurado $SDCONF)"; exit 1
fi

ESP=${PORPHYX_ESP:-$(bootctl --print-boot-path 2>/dev/null)}
ESP=${ESP:-/boot}
shopt -s nullglob
n=0; done_n=0
for f in "$ESP"/loader/entries/*.conf; do
  grep -q '^options[[:space:]]' "$f" || continue
  n=$((n+1))
  if grep -q '^options[[:space:]].*acpi_backlight=' "$f"; then done_n=$((done_n+1)); continue; fi
  cp -a "$f" "$f.bak.$STAMP" || { echo "ABORT: respaldo de $f"; exit 1; }
  sed -i "/^options[[:space:]]/ s|[[:space:]]*\$| $PARAM|" "$f"
  if grep -q "^options[[:space:]].* $PARAM\$" "$f"; then done_n=$((done_n+1))
  else cp -a "$f.bak.$STAMP" "$f"; echo "ABORT: no pude editar $f (restaurado)"; exit 1; fi
done
if [[ $n -eq 0 ]]; then
  echo "AVISO: no encontre entradas de systemd-boot en $ESP/loader/entries; agrega $PARAM al cmdline a mano"; exit 2
fi
echo "backlight: $PARAM en $done_n de $n entradas de $ESP/loader/entries (aplica al reiniciar)"
exit 0
