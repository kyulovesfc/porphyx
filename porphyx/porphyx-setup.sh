#!/usr/bin/env bash
# porphyx-setup.sh — second stage: Umbriel + Noctalia + Luciole + noctalia-greeter + dotfiles (install.sh).
set -Eeuo pipefail
trap 'echo "ERROR: linea $LINENO: $BASH_COMMAND" >&2' ERR
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
export PORPHYX=1
die() { echo "ABORT: $*" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || die "run as your user, not as root"
command -v sudo >/dev/null 2>&1 || die "sudo is missing"

# no prompts: no PKGBUILD review or per-package confirmation, build with all cores, sudo asked once
export PORPHYX_ASSUME_YES="${PORPHYX_ASSUME_YES:-1}"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n -v 2>/dev/null; sleep 50; done ) &
SUDO_KEEP=$!
trap 'kill "$SUDO_KEEP" 2>/dev/null || true' EXIT

echo "== Network =="
# KYU-NET-CHECK: without network, open nmtui to connect and retry
if ! ping -c1 -W5 archlinux.org >/dev/null 2>&1; then
  echo "No connection. Connect to continue."
  command -v nmtui >/dev/null 2>&1 && nmtui
  ping -c1 -W5 archlinux.org >/dev/null 2>&1 || die "no internet; connect (nmtui) and run porphyx setup again"
fi
echo "ok"

echo "== Official packages =="
mapfile -t PKGS < <(sed "s/#.*//" "$HERE/official-packages.txt" | tr -s " \t" "\n" | grep -v "^$")
# KYU-APPS: optional apps by category (categories.conf)
. "$HERE/select-apps.sh"
select_apps
# KYU-AUR-APPS: entries prefixed with aur: in categories.conf are built from the AUR
SEL_AUR=(); SEL_FLAT=(); _off=()
for _p in "${SEL[@]}"; do case "$_p" in aur:*) SEL_AUR+=("${_p#aur:}") ;; flatpak:*) SEL_FLAT+=("${_p#flatpak:}") ;; *) _off+=("$_p") ;; esac; done
SEL=("${_off[@]}")
# KYU-DESKTOP: choose the desktop environment (desktops.conf); Umbriel + Noctalia is the default
. "$HERE/select-desktop.sh"
select_desktop
NOCT=0
if [ -n "$DE_NOCT_FIRST" ]; then NOCT=1; fi
if [ "$NOCT" = 1 ]; then mapfile -t -O "${#PKGS[@]}" PKGS < <(sed "s/#.*//" "$HERE/noctalia-packages.txt" | tr -s " \t" "\n" | grep -v "^$"); fi
# multilib (steam/wine)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  grep -q '^\[multilib\]' /etc/pacman.conf || { echo "ERROR: could not enable multilib" >&2; exit 1; }
fi
sudo pacman -Syu --needed --noconfirm base-devel git less xdg-utils desktop-file-utils "${PKGS[@]}" "${SEL[@]}" "${DE_PKGS[@]}"
sudo systemctl enable --now fstrim.timer paccache.timer || echo "WARNING: could not enable the timers" >&2

echo "== Umbriel (prebuilt [porphyx] repo; if it fails, built from AUR) =="
if ! grep -q '^\[porphyx\]' /etc/pacman.conf; then
  printf '\n[porphyx]\nSigLevel = Optional TrustAll\nServer = https://github.com/kyulovesfc/porphyx/releases/download/repo\n' | sudo tee -a /etc/pacman.conf >/dev/null
fi
if [ "$DE_HAS_UMBRIEL" = 1 ] && ! sudo pacman -Sy --needed --noconfirm umbriel-git xdg-desktop-portal-umbriel-git; then
  echo "WARNING: prebuilt repo not available, building from AUR" >&2
  bash "$HERE/aur-install.sh" xdg-desktop-portal-umbriel-git || die "xdg-desktop-portal-umbriel-git not installed; umbriel-git needs it"
  bash "$HERE/aur-install.sh" umbriel-git || die "umbriel-git not installed; there is no session without it"
fi
if [ "$NOCT" = 1 ]; then
  sudo pacman -S --needed --noconfirm luciole-git lavat oh-my-zsh-git zsh-theme-powerlevel10k-git || echo "WARNING: luciole-git/lavat are not in the prebuilt repo, trying AUR" >&2
fi
echo "== Flatpak (user) =="
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || echo "WARNING: could not add flathub" >&2
for a in "${SEL_FLAT[@]}"; do
  flatpak install --user -y --noninteractive flathub "$a" || echo "WARNING: $a not installed" >&2
done
echo "== AUR: rest =="
for p in oh-my-zsh-git zsh-theme-powerlevel10k-git lavat tty-clock luciole-git heroic-games-launcher-bin pear-desktop-bin; do
  if [ "$NOCT" != 1 ]; then
    case "$p" in oh-my-zsh-git|zsh-theme-powerlevel10k-git|lavat|tty-clock|luciole-git) continue ;; esac
  fi
  bash "$HERE/aur-install.sh" "$p" || echo "WARNING: $p not installed" >&2
done

for p in "${SEL_AUR[@]}"; do
  bash "$HERE/aur-install.sh" "$p" || echo "WARNING: $p not installed" >&2
done

# install.sh calls paru and pacman -S paru (CachyOS); on plain Arch paru does not exist: a shim that uses aur-install.sh
TMPBIN="$(mktemp -d)"
trap 'rm -rf "$TMPBIN"' EXIT
{
  printf '\043\041/usr/bin/env bash\n'
  printf 'args=()\nfor a in "$@"; do case "$a" in -*) ;; *) args+=("$a") ;; esac; done\n'
  printf 'bash "%s/aur-install.sh" "${args[@]}" || echo "WARNING: aur-install failed (continuing)" >&2\nexit 0\n' "$HERE"
} > "$TMPBIN/paru"
chmod +x "$TMPBIN/paru"

echo "== Dotfiles, Noctalia and Umbriel (install.sh) =="
if [ "$NOCT" = 1 ]; then
  PORPHYX_SESSIONS="${DE_LIST[*]}" PORPHYX_SESSION="$DE_NOCT_FIRST" PATH="$TMPBIN:$PATH" bash "$REPO/install.sh"
else
  echo "Vanilla desktop: Porphyx dotfiles skipped."
fi

if [ -z "$DE_DM_SERVICE" ]; then
  echo "== noctalia-greeter =="
  bash "$REPO/greeter-setup/install-greeter.sh"
else
  echo "== Login manager ($DE_DM_SERVICE) =="
  sudo systemctl disable greetd.service 2>/dev/null || true
  sudo systemctl enable "$DE_DM_SERVICE"
fi

echo "✓ porphyx setup finished — reboot to log in through the greeter"
