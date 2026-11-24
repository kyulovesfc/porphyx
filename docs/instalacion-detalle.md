# porphyx: instalacion en detalle

Referencia detallada. El indice del repo esta en [../README.md](../README.md).

Dotfiles y scripts del entorno Noctalia v5 + Umbriel de Porphyx. Config, scripts de GPU PRIME,
overrides de MangoHud para flatpaks.

## Instalación rápida (cualquier máquina, sin llave SSH)

El repo es público — clonar por HTTPS no requiere configurar nada:

```bash
git clone https://github.com/kyulovesfc/porphyx.git ~/porphyx && \
cd ~/porphyx && \
./install.sh
```

`install.sh` es idempotente: si algo ya está instalado o configurado, lo detecta y lo omite.
Todo archivo que reemplaza se respalda como `archivo.bak.<timestamp>` antes de sobreescribirse.

> Si vas a contribuir cambios de vuelta al repo (no solo desplegar config), necesitas el
> remote por SSH y una llave agregada en https://github.com/settings/ssh/new — para solo
> instalar en una máquina, HTTPS basta.

## Qué instala `install.sh`

- **Cursor**: paquete `capitaine-cursors`. El tema y el tamaño los gobierna
  `config/niri/cfg/cursor.kdl` (fuente única). En Umbriel el tema activo es
  `capitaine-cursors` (`config/umbriel/config.toml`); `cursor.kdl` es de niri y es legado.
- **Noctalia**: `noctalia-full-config.toml` (bar, dock, tema) + overlay `zz-porphyx.toml` (hooks) + `kbd-color-sync.toml`
  (sat=1.6 val=0.85).
- **MangoHud**: paquete + `MangoHud.conf` + overrides para Sober y mcpelauncher si están
  instalados (Vulkan layer vía Flatpak).
- **Luciole + papirus-icon-theme**: gestor de archivos e iconos; el recoloreo lo hace la plantilla `papirus-icons` de Noctalia.
- **niri**: todos los `.kdl` de `config/niri/cfg/` + `config.kdl` (window-rules, blur).
- **Zsh**: paquete + `cachyos-zsh-config` + zoxide + eza + `.zshrc`/`.p10k.zsh`, y cambia la
  shell por defecto del usuario (`chsh`, pide password del usuario).
- **Completions de noctalia**: `noctalia completions zsh` →
  `~/.local/share/zsh/site-functions/_noctalia`. Se generan del esquema vivo, así que
  **incluyen los subcomandos de los plugins instalados en ese momento** — regenerar con
  el mismo comando tras instalar o quitar plugins. El `zshrc` agrega ese directorio a
  `fpath` antes de `cachyos-config.zsh`, que es quien corre `compinit`; si se mueve esa
  línea después, las completions dejan de cargar en silencio.
- **Foot**: paquete + config + tema dinámico Noctalia.
- **Zen Browser**: paquete `zen-browser-bin` (AUR; en CachyOS viene del repo `cachyos`).
- **Umbriel** (compositor principal): `umbriel-git` + `xdg-desktop-portal-umbriel-git` desde AUR con paru; `config/umbriel/config.toml` → `~/.config/umbriel/` (portado de `config/niri/cfg`; layout dwindle por defecto, `Mod+M` alterna master/scrolling) y `drm.toml` solo en ASUS con `dgpu_disable` (excluye la dGPU, equivalente al `ignore-drm-device` de niri). Es el entorno principal: el instalador ofrece eliminar otros entornos instalados (pide confirmacion).
- **Scripts** de `bin/` → `~/.local/bin/` (kbd-color-sync, mangohud-color-sync,
  porphyx-gpu-prime, porphyx-gpu-launch, porphyx-gpu-flatpak-sync).

## Placeholders de rutas

Los archivos de `config/` no llevan rutas absolutas: `install.sh` las sustituye al
desplegar, para que el repo funcione con cualquier usuario. Tres formas, cada una con
su `sed` y su guardia que aborta si algo queda sin sustituir:

| Placeholder | Archivos | Se reemplaza por |
|---|---|---|
| `"HOME/` | `noctalia/zz-porphyx.toml`, `noctalia/kbd-color-sync.toml` | `"$HOME/` |
| `=HOME/` | `MangoHud/MangoHud.conf` | `=$HOME/` |
| `"HOOK"` | `noctalia/zz-porphyx.toml` | ruta a `rgb-sync-hook.sh` |

**Al editar estos archivos, nunca commitear rutas absolutas.** `noctalia-full-config.toml`
usa `/home/kyu/` como placeholder (`s|/home/kyu/|$HOME/|g`); los otros usan los de la tabla.

Consecuencia para diagnóstico: un `diff` crudo entre `config/noctalia/noctalia-full-config.toml`
y `~/.config/noctalia/noctalia-full-config.toml` siempre muestra estas líneas y no indica
drift. Para comparar de verdad hay que normalizar primero con el mismo `sed` que aplica `install.sh`.

Si se agrega un archivo nuevo con rutas, agregar las tres piezas: placeholder en el
archivo, `sed` en `install.sh`, y `grep` que aborte.

## Módulos manuales (no los corre `install.sh`)

Estos requieren pasos que no son seguros de automatizar de un tirón (compilar de AUR,
tocar el display manager del sistema, o dependen de contexto que varía por máquina):

- **`greeter-setup/`** — reemplaza SDDM por greetd + noctalia-greeter. Lo corre `porphyx setup`
  despues de `install.sh`; con `install.sh` solo, corre `greeter-setup/install-greeter.sh` a mano.
  El rollback esta en `greeter-setup/README.md`.

## Estructura

- `config/`: dotfiles (noctalia, niri, umbriel, foot, zsh, MangoHud)
- `bin/`: scripts desplegados a `~/.local/bin`
- `greeter-setup/`: greetd + noctalia-greeter
- Imagenes: `config/wallpapers/` las trae; `install.sh` las copia a `~/Pictures/Wallpapers/` (sin pisar las
  existentes) y `noctalia-full-config.toml` apunta ahi, avatar incluido.

## Descargar la ISO desde cualquier equipo

    curl -fsSL https://raw.githubusercontent.com/kyulovesfc/porphyx/main/get-iso.sh | bash

Descarga `porphyx-latest-x86_64.iso` desde el release `iso`, verifica el sha256 y la deja en ~/Downloads.
Para grabarla directo a un USB: `USB=/dev/sdX` antes del `bash` (pide confirmación). Publicar una ISO nueva: `iso/publish-iso.sh`.
