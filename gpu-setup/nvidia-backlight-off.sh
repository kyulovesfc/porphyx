#!/usr/bin/env bash
# nvidia-backlight-off.sh — impide que el driver NVIDIA registre /sys/class/backlight/nvidia_0.
# Al encender la dGPU (gaming mode) aparecia un segundo backlight "nvidia_0" (100/100) que no controla el
# panel (cuelga de amdgpu_bl1) y el escritorio dejaba de poder cambiar el brillo.
# Requiere root. Idempotente. rc: 0 ok o nada que hacer, 1 error, 2 el driver no tiene el parametro.
set -uo pipefail
CONF=${PORPHYX_NVBL_CONF:-/etc/modprobe.d/porphyx-nvidia-backlight.conf}
LINE="options nvidia NVreg_EnableBacklightHandler=0"
[[ $EUID -eq 0 ]] || { echo "ABORT: correr con sudo"; exit 1; }
if ! modinfo -p nvidia 2>/dev/null | grep -q '^NVreg_EnableBacklightHandler'; then
  echo "AVISO: el modulo nvidia no tiene NVreg_EnableBacklightHandler; no se cambia nada"; exit 2
fi
if [[ -f "$CONF" ]] && grep -qxF "$LINE" "$CONF"; then echo "nvidia-backlight: ya configurado ($CONF)"; exit 0; fi
printf '# porphyx: el panel usa amdgpu_bl1; sin esto nvidia registra nvidia_0 al encender la dGPU\n%s\n' "$LINE" > "$CONF" \
  && grep -qxF "$LINE" "$CONF" || { echo "ABORT: no pude escribir $CONF"; exit 1; }
echo "nvidia-backlight: $CONF escrito (aplica al proximo load del modulo nvidia)"
