# Porphyx Linux

## Get the ISO

Copy and paste this in any Linux terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/kyulovesfc/porphyx/main/get-iso.sh | bash
```

It downloads `porphyx-latest-x86_64.iso` to `~/Downloads` and verifies its sha256.

To write it straight to a USB stick (asks you to type BORRAR before erasing anything):

```bash
curl -fsSL https://raw.githubusercontent.com/kyulovesfc/porphyx/main/get-iso.sh | USB=/dev/sdX bash
```

Boot the stick and run `porphyx-install`.


Arch Linux ligero con el entorno de Noctalia: compositor Wayland Umbriel, shell Noctalia v5, login con
greetd y las apps básicas ya integradas. Se instala desde una ISO propia, en dos pasos: la base de Arch
y `porphyx setup`.

Estado: en desarrollo. El flujo completo se está validando en máquina virtual. La parte de GPU híbrida
es opcional y solo existe para ASUS TUF.

## Qué incluye

| Capa | Componente |
|---|---|
| Base | Arch Linux, kernel `linux`, systemd-boot, NetworkManager, swap en zram (zstd), PipeWire, Bluetooth, keyd |
| Compositor | Umbriel (Wayland, basado en wlroots) con `xdg-desktop-portal-umbriel` y efectos propios en `config/umbriel/effects/` |
| Shell | Noctalia v5: barra, launcher, centro de control, OSD, bloqueo de sesión y 13 plugins que se habilitan en el primer arranque |
| Login | greetd + noctalia-greeter |
| Archivos | Luciole, con iconos Papirus |
| Terminal | foot y zsh con oh-my-zsh, powerlevel10k, zoxide, eza y fzf |
| Navegador | Zen Browser |
| Extras | MangoHud, flatpak, cava, cmatrix, lavat, playerctl y el cursor capitaine |

Umbriel, Luciole, lavat, oh-my-zsh y powerlevel10k se instalan precompilados desde el repo pacman `[porphyx]`
(release `repo` de GitHub, sin firmar): `porphyx setup` no compila nada. Solo Zen Browser viene del AUR (binario).

## Instalación

1. Arranca la ISO (UEFI) con internet disponible y ejecuta `porphyx-install`. Es archinstall con la
   configuración del proyecto: teclado latam, `es_MX`, zona `America/Mexico_City`, hostname `porphyx` y
   systemd-boot ya definidos. Disco y usuario se eligen en el menú.
2. Reinicia e inicia sesión en la TTY con tu usuario.
3. Con internet (`nmtui` si hace falta) ejecuta:

```bash
porphyx setup
```

Instala los paquetes oficiales y los del repo `[porphyx]`, despliega los dotfiles (`install.sh`) y configura greetd.
Pide sudo una vez. Si el repo precompilado no está disponible, cae al AUR y muestra cada PKGBUILD (sal del visor con `q`).
Al terminar, reinicia: entras por el greeter de Noctalia a una sesión Umbriel.

Variables opcionales: `PORPHYX_REPO` (dónde clonar; por defecto `~/porphyx`), `PORPHYX_AUR_CACHE`,
`PORPHYX_ASSUME_YES=1` (compila sin mostrar los PKGBUILD) y `PORPHYX_GPU=s` o `n` (responde de antemano
la pregunta de GPU híbrida).

### Sobre un Arch ya instalado

Sin probar fuera de la ISO:

```bash
git clone https://github.com/kyulovesfc/porphyx.git ~/porphyx
bash ~/porphyx/porphyx/porphyx-setup.sh
```

## Construir la ISO

Desde un Arch con `archiso`, `git`, `python` y `sudo` (`imagemagick` es opcional, para el splash):

```bash
cd ~/porphyx
iso/check-packages.sh   # verifica que target-packages.txt resuelva en Arch puro
iso/build-iso.sh        # deja la ISO en iso/out/
```

Todo debe estar commiteado: `porphyx/porphyx` se toma de HEAD.

## Atajos de Umbriel

`Mod` es la tecla Super. La lista completa está en `config/umbriel/config.toml` y se edita con
`umbriel-keybinds`. `Mod+Shift+Escape` abre el cheatsheet.

| Atajo | Acción |
|---|---|
| `Mod+Return` | Terminal (foot) |
| `Mod+Space` / `Mod+S` | Launcher / centro de control de Noctalia |
| `Mod+B` / `Mod+E` | Zen Browser / Luciole |
| `Mod+Alt+L` | Bloquear sesión |
| `Mod+Q` | Cerrar ventana |
| `Mod+Z` | Scratchpad de terminal |
| `Mod+T` / `Mod+F` | Flotar o tilear / maximizar la columna |
| `Mod+M` | Cambiar de layout (dwindle, scrolling, master) |
| `Mod+O` | Overview |
| `Mod+1`..`9` | Ir a un workspace |
| `Mod+Tab` | Volver al workspace anterior |
| `Print` | Captura de región |
| `Mod+Escape` | Inhibir los atajos (útil en máquinas virtuales) |

Volumen, brillo y multimedia pasan por Noctalia, con OSD.

## GPU híbrida y energía (opcional, solo ASUS TUF)

`install.sh` pregunta si instalar esta parte y solo la ofrece en una ASUS TUF. Usa sysfs, udev, polkit y
systemd, sin asusctl ni supergfxctl. Los perfiles de CPU los lleva power-profiles-daemon.

| Modo | dGPU | Consumo en reposo* |
|---|---|---|
| Ahorro | Apagada por firmware | unos 9 W |
| Híbrido | Encendida | unos 23 W |
| Modo juego | Encendida, con PRIME offload en apps nativas y flatpaks | n/d |

\* Medido el 6 de noviembre de 2026 con perfil `power-saver`, en batería. Detalle en
[docs/notas-odyssey.md](docs/notas-odyssey.md).

```bash
sudo porphyx-dgpu off    # ahorro
sudo porphyx-dgpu on     # híbrido
porphyx-dgpu status
```

Más detalle en [`gpu-setup/`](gpu-setup/README.md) y [`gaming-mode/`](gaming-mode/README.md).

## Mapa del repo

| Ruta | Qué es |
|---|---|
| [`install.sh`](install.sh) | Despliega los dotfiles y configura Umbriel, Noctalia y las apps. Lo llama `porphyx setup` |
| `porphyx/` | Comando `porphyx`, `porphyx-setup.sh`, instalador de respaldo del AUR y listas de paquetes |
| `iso/` | Construcción de la ISO: perfil archiso, `porphyx-install`, branding |
| [`config/`](config/README.md) | Dotfiles: Noctalia, Umbriel, foot, zsh, MangoHud, launcher (`config/niri` es legado) |
| [`bin/`](bin/README.md) | Scripts que van a `~/.local/bin` |
| [`greeter-setup/`](greeter-setup/README.md) | greetd + noctalia-greeter |
| [`gpu-setup/`](gpu-setup/README.md), [`gaming-mode/`](gaming-mode/README.md) | GPU híbrida y modo juego (opcional) |
| `logind/` | Botón de apagado: pulsación corta bloquea y suspende, larga apaga |
| [`docs/`](docs/) | [Instalación en detalle](docs/instalacion-detalle.md) y [notas de port a Odyssey](docs/notas-odyssey.md) |
| [`alienware-setup/`](alienware-setup/README.md) | RGB para un Alienware, sin soporte |

## Limitaciones

- La base está fija para iGPU AMD y dGPU NVIDIA (`mesa`, `vulkan-radeon`, `nvidia-open`).
- Solo UEFI con systemd-boot.
- Umbriel y Noctalia siguen en desarrollo: pueden cambiar su esquema de configuración.
- El port a Odyssey (Void, runit) está en curso y nada se ha probado ahí: ver
  [docs/notas-odyssey.md](docs/notas-odyssey.md).
