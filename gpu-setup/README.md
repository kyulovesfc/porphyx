# gpu-setup/

Control de la dGPU en portátiles con GPU híbrida. `install.sh` lo despliega con
`sudo gpu-setup/deploy-dgpu.sh`.

| Archivo | Para qué |
|---|---|
| `deploy-dgpu.sh` | Instalador. Requiere root y es idempotente. Deja `nvidia-powerd` deshabilitado al arranque |
| `backlight-native.sh` | Lo llama `deploy-dgpu.sh`. Solo si el equipo expone el backlight WMI de NVIDIA: agrega `acpi_backlight=native` al cmdline (con `sdboot-manage` o editando las entradas de systemd-boot) para que el brillo use amdgpu y siga funcionando con la dGPU apagada. Requiere root, es idempotente y aplica al reiniciar |
| `nvidia-backlight-off.sh` | Lo llama `deploy-dgpu.sh`. Escribe `/etc/modprobe.d/porphyx-nvidia-backlight.conf` con `NVreg_EnableBacklightHandler=0` para que el driver NVIDIA no registre el backlight `nvidia_0` al encender la dGPU (rompia el control de brillo). Requiere root, idempotente |
| `porphyx-dgpu` | Enciende o apaga la dGPU con el mejor backend disponible: `firmware-asus` (la quita del bus PCI y la corta por firmware; `off` verifica que nadie la use) o `runtime-pm` (genérico: deja el runtime PM en `auto`, mejor esfuerzo, sin probar fuera de ASUS). `porphyx-dgpu backend` imprime el elegido y se puede forzar con `BACKEND=` en `/etc/porphyx/dgpu.conf`. Corre como root vía pkexec o desde el servicio de arranque |
| `porphyx-dgpu-boot.service` | Servicio de sistema que apaga la dGPU al arrancar y otra vez al apagar el equipo, para que el siguiente arranque empiece sin dGPU (cachyos-drm-awaiter falla si la ve al inicio y nvidia no carga) |
| `org.porphyx.dgpu.policy` | Acción polkit `org.porphyx.dgpu` para usar pkexec sin contraseña de root |
| `49-porphyx-dgpu.rules` | Regla polkit; `deploy-dgpu.sh` la instala en `/etc/polkit-1/rules.d/` |

Lo usa `bin/porphyx-gpu-prime`. El modo juego (`gaming-mode/`) enciende la dGPU a través de este
módulo.
