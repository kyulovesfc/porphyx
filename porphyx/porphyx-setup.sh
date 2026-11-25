#!/usr/bin/env bash
# porphyx-setup.sh — segunda etapa: Umbriel + Noctalia + Luciole + noctalia-greeter + dotfiles (install.sh).
set -Eeuo pipefail
trap 'echo "ERROR: linea $LINENO: $BASH_COMMAND" >&2' ERR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
export PORPHYX=1
die() { echo "ABORT: $*" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || die "corre como tu usuario, no como root"
command -v sudo >/dev/null 2>&1 || die "falta sudo"

# sin preguntas: no mostrar PKGBUILD ni confirmar cada paquete, compilar con todos los nucores, sudo una sola vez
export PORPHYX_ASSUME_YES="${PORPHYX_ASSUME_YES:-1}"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) &

echo "== Red =="
# KYU-NET-CHECK: si no hay red, abre nmtui para conectar y vuelve a probar
if ! ping -c1 -W5 archlinux.org >/dev/null 2>&1; then
  echo "Sin conexion. Conectate para continuar."
  command -v nmtui >/dev/null 2>&1 && nmtui
  ping -c1 -W5 archlinux.org >/dev/null 2>&1 || die "sin internet; conectate (nmtui) y vuelve a correr: porphyx setup"
fi
echo "ok"

echo "== Paquetes oficiales =="
mapfile -t PKGS < <(sed "s/#.*//" "$HERE/official-packages.txt" | tr -s " \t" "\n" | grep -v "^$")
# multilib (steam/wine)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  grep -q '^\[multilib\]' /etc/pacman.conf || { echo "ERROR: no se pudo habilitar multilib" >&2; exit 1; }
fi
sudo pacman -Syu --needed --noconfirm base-devel git less xdg-utils desktop-file-utils "${PKGS[@]}"

echo "== Umbriel (repo precompilado [porphyx]; si falla, se compila del AUR) =="
if ! grep -q '^\[porphyx\]' /etc/pacman.conf; then
  printf '\n[porphyx]\nSigLevel = Optional TrustAll\nServer = https://github.com/kyulovesfc/porphyx/releases/download/repo\n' | sudo tee -a /etc/pacman.conf >/dev/null
fi
if ! sudo pacman -Sy --needed --noconfirm umbriel-git xdg-desktop-portal-umbriel-git; then
  echo "AVISO: repo precompilado no disponible, se compila del AUR" >&2
  bash "$HERE/aur-install.sh" xdg-desktop-portal-umbriel-git || die "xdg-desktop-portal-umbriel-git no se instalo; umbriel-git lo necesita"
  bash "$HERE/aur-install.sh" umbriel-git || die "umbriel-git no se instalo; sin el no hay sesion"
fi
sudo pacman -S --needed --noconfirm luciole-git lavat oh-my-zsh-git zsh-theme-powerlevel10k-git || echo "AVISO: luciole-git/lavat no estan en el repo precompilado, se intentan del AUR" >&2
echo "== Flatpak (usuario) =="
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || echo "AVISO: no se pudo agregar flathub" >&2
for a in io.mrarm.mcpelauncher org.vinegarhq.Sober org.vinegarhq.Vinegar; do
  flatpak install --user -y --noninteractive flathub "$a" || echo "AVISO: $a no se instalo" >&2
done
echo "== AUR: resto =="
for p in oh-my-zsh-git zsh-theme-powerlevel10k-git lavat zen-browser-bin luciole-git shelly-bin shelly-flatpak-backend-bin heroic-games-launcher-bin artcraft-launcher pear-desktop-bin; do
  bash "$HERE/aur-install.sh" "$p" || echo "AVISO: $p no se instalo" >&2
done

# install.sh llama a paru y a pacman -S paru (CachyOS); en Arch puro paru no existe: shim que usa aur-install.sh
TMPBIN="$(mktemp -d)"
trap 'rm -rf "$TMPBIN"' EXIT
{
  printf '\043\041/usr/bin/env bash\n'
  printf 'args=()\nfor a in "$@"; do case "$a" in -*) ;; *) args+=("$a") ;; esac; done\n'
  printf 'bash "%s/aur-install.sh" "${args[@]}" || echo "AVISO: aur-install fallo (se continua)" >&2\nexit 0\n' "$HERE"
} > "$TMPBIN/paru"
chmod +x "$TMPBIN/paru"

echo "== Dotfiles, Noctalia y Umbriel (install.sh) =="
PATH="$TMPBIN:$PATH" bash "$REPO/install.sh"

echo "== noctalia-greeter =="
bash "$REPO/greeter-setup/install-greeter.sh"

echo "✓ porphyx setup terminado — reinicia para entrar por el greeter"
