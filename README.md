# Porphyx Linux

A lightweight Arch Linux with a Noctalia desktop: the Umbriel Wayland compositor, the Noctalia v5 shell and a greetd login, installed from its own ISO in two phases.

> **Status:** in development. The full flow is validated in a virtual machine; testing on real hardware is ongoing.

## Download

**[porphyx-latest-x86_64.iso](https://github.com/kyulovesfc/porphyx/releases/download/iso/porphyx-latest-x86_64.iso)** (UEFI only)

Or from any Linux terminal, which also verifies the sha256:

```bash
curl -fsSL https://raw.githubusercontent.com/kyulovesfc/porphyx/main/get-iso.sh | bash
```

To write it straight to a USB stick (it asks you to type `BORRAR` before erasing anything):

```bash
curl -fsSL https://raw.githubusercontent.com/kyulovesfc/porphyx/main/get-iso.sh | USB=/dev/sdX bash
```

## Installation

Porphyx installs in two phases. Both need an internet connection and offer a text UI to connect if there is none.

**Phase 1: base system.** Boot the ISO and run:

```bash
porphyx-install
```

It is a basic `archinstall` with the project defaults already set: Latin American keyboard, `es_MX` locale, `America/Mexico_City` timezone, hostname `porphyx` and systemd-boot. You only pick the disk and your user. Reboot when it finishes.

**Phase 2: desktop.** Log in on the TTY with your user and run:

```bash
porphyx setup
```

It installs the desktop packages, deploys the dotfiles and sets up greetd. It asks for sudo once. Reboot, and you land in the Noctalia greeter and an Umbriel session.

Optional variables: `PORPHYX_REPO` (clone location, default `~/porphyx`), `PORPHYX_AUR_CACHE` and `PORPHYX_ASSUME_YES=1` (build AUR packages without showing the PKGBUILDs).

### On an existing Arch install

Not tested outside the ISO:

```bash
git clone https://github.com/kyulovesfc/porphyx.git ~/porphyx
bash ~/porphyx/porphyx/porphyx-setup.sh
```

## What is included

| Layer | Component |
|---|---|
| Base | Arch Linux, `linux` kernel, systemd-boot, NetworkManager, zram swap, PipeWire, Bluetooth, keyd |
| Compositor | Umbriel with `xdg-desktop-portal-umbriel` and custom effects |
| Shell | Noctalia v5: bar, launcher, control center, OSD, lock screen and plugins |
| Login | greetd + noctalia-greeter |
| Files | Luciole, Papirus icons |
| Terminal | foot, zsh with oh-my-zsh, powerlevel10k, zoxide, eza and fzf |
| Browser | Zen Browser |
| Packages | Shelly: pacman, AUR and Flatpak manager |
| Extras | flatpak, cava, cmatrix, lavat, playerctl |

Umbriel, Luciole, lavat, oh-my-zsh and powerlevel10k come precompiled from the `[porphyx]` pacman repo (unsigned, GitHub release `repo`), so `porphyx setup` compiles nothing. Only Zen Browser and Shelly come from the AUR (prebuilt binaries), and the AUR is also the fallback if the repo is unreachable.

## Keybindings

`Mod` is the Super key. The full list is in `config/umbriel/config.toml` and can be edited with `umbriel-keybinds`. `Mod+Shift+Escape` opens the cheatsheet.

| Shortcut | Action |
|---|---|
| `Mod+Return` | Terminal (foot) |
| `Mod+Space` / `Mod+S` | Launcher / Noctalia control center |
| `Mod+B` / `Mod+E` | Zen Browser / Luciole |
| `Mod+Alt+L` | Lock session |
| `Mod+Q` | Close window |
| `Mod+Z` | Terminal scratchpad |
| `Mod+T` / `Mod+F` | Toggle floating / maximize column |
| `Mod+O` | Overview |
| `Mod+1`..`9` | Go to workspace |
| `Print` | Region screenshot |

Volume, brightness and media keys go through Noctalia, with an OSD.

## Building the ISO

From an Arch system with `archiso`, `git`, `python` and `sudo`:

```bash
cd ~/porphyx
iso/check-packages.sh   # check that target-packages.txt resolves on plain Arch
iso/build-iso.sh        # writes the ISO to iso/out/
```

Everything must be committed: `porphyx/porphyx` is taken from `HEAD`.

## Repository layout

| Path | Description |
|---|---|
| [`install.sh`](install.sh) | Deploys dotfiles and configures Umbriel, Noctalia and the apps; called by `porphyx setup` |
| `porphyx/` | The `porphyx` command, `porphyx-setup.sh`, the AUR fallback installer and package lists |
| `iso/` | ISO build: archiso profile, `porphyx-install`, branding |
| [`config/`](config/README.md) | Dotfiles: Noctalia, Umbriel, foot, zsh (`config/niri` is legacy) |
| [`bin/`](bin/README.md) | Scripts installed to `~/.local/bin` |
| [`greeter-setup/`](greeter-setup/README.md) | greetd + noctalia-greeter |
| `logind/` | Power button: short press locks and suspends, long press powers off |
| [`docs/`](docs/) | Detailed install notes and the Odyssey port notes (in Spanish) |
| [`alienware-setup/`](alienware-setup/README.md) | RGB for an Alienware, unsupported |

## Limitations

- The base is fixed for an AMD iGPU and an NVIDIA dGPU (`mesa`, `vulkan-radeon`, `nvidia-open`).
- UEFI with systemd-boot only.
- Umbriel and Noctalia are under active development and their config schema may change.
- The Odyssey port (Void, runit) is a work in progress and untested: see [docs/notas-odyssey.md](docs/notas-odyssey.md).
