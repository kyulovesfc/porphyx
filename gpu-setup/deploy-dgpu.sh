#!/usr/bin/env bash
# deploy-dgpu.sh — instala el control de la dGPU (backends: firmware ASUS, runtime-pm). Requiere root. Idempotente.
# nvidia-powerd queda deshabilitado al arranque: porphyx-dgpu lo arranca/para con la dGPU.
set -uo pipefail
[[ $EUID -eq 0 ]] || { echo "ABORT: correr con sudo"; exit 1; }
D="$(cd "$(dirname "$0")" && pwd)"
B="$(bash "$D/porphyx-dgpu" backend)"
[[ "$B" != none ]] || { echo "sin backend para la dGPU: nada que instalar en esta maquina"; exit 0; }
echo "backend de la dGPU: $B"
MAP=(
  "porphyx-dgpu:/usr/local/bin/porphyx-dgpu:755"
  "org.porphyx.dgpu.policy:/usr/share/polkit-1/actions/org.porphyx.dgpu.policy:644"
  "49-porphyx-dgpu.rules:/etc/polkit-1/rules.d/49-porphyx-dgpu.rules:644"
  "porphyx-dgpu-boot.service:/etc/systemd/system/porphyx-dgpu-boot.service:644"
)
for m in "${MAP[@]}"; do
  IFS=: read -r src dst mode <<< "$m"
  install -Dm"$mode" "$D/$src" "$dst" && cmp -s "$D/$src" "$dst" || { echo "ABORT: $dst"; exit 1; }
  echo "ok  $dst"
done
systemctl daemon-reload && systemctl enable porphyx-dgpu-boot.service && systemctl disable nvidia-powerd.service || { echo "ABORT: systemctl"; exit 1; }
echo "DGPU DEPLOY OK"
