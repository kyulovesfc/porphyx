#!/usr/bin/env bash
# install.sh — deploys the Porphyx dotfiles and the Noctalia/Umbriel environment (Arch).
# Usage: clone the repo and run ./install.sh from its root.
set -Eeuo pipefail
trap 'echo "ERROR: line $LINENO: $BASH_COMMAND" >&2' ERR
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

backup_and_copy() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then cp -r "$dst" "$dst.bak.$(date +%s)"; fi
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -rT "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
}

echo "== Cursor theme =="
# El tema y el tamaño los define config/umbriel/config.toml ([input.cursor]).
# El cursor Skyrim se copia mas abajo (assets/cursors).

echo "== Noctalia config =="
# La config es noctalia-full-config.toml mas el overlay zz-porphyx.toml (se despliegan abajo).
# Noctalia fusiona todos los *.toml de ~/.config/noctalia/: un config.toml suelto se mezclaria con la full-config.
if [ -f "$HOME/.config/noctalia/config.toml" ]; then
  echo "WARNING: ~/.config/noctalia/config.toml exists and Noctalia merges it with noctalia-full-config.toml." >&2
  echo "       If it is left over from a previous install, move it out of that folder (e.g. to config.toml.old)." >&2
fi

# KYU-PALETTE-INSTALL
# Paleta Kyu_Pallete y config completa de Noctalia (rutas /home/kyu resueltas a $HOME).
# Cursor Skyrim (assets/cursors) -> ~/.local/share/icons; no pisa una instalacion existente
mkdir -p "$HOME/.local/share/icons"
for d in "$REPO_DIR"/assets/cursors/*/; do
  [ -d "$d" ] || continue
  [ -e "$HOME/.local/share/icons/$(basename "$d")" ] || cp -r "$d" "$HOME/.local/share/icons/"
done
# KYU-GTK-CURSOR: GTK/libadwaita leen el cursor de gsettings (no de XCURSOR_THEME); tema y tamano salen de config/umbriel/config.toml
cur_get() { awk -v k="$1" '/^\[input\.cursor\]/{f=1;next} /^\[/{f=0} f && $1==k {gsub(/[" ]/,"",$3); print $3; exit}' "$REPO_DIR/config/umbriel/config.toml"; }
CUR_THEME=$(cur_get theme 2>/dev/null || true); CUR_SIZE=$(cur_get size 2>/dev/null || true)
if command -v gsettings >/dev/null 2>&1 && [ -n "$CUR_THEME" ]; then
  gset() { if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then gsettings set "$@"; else dbus-run-session -- gsettings set "$@"; fi; }
  gset org.gnome.desktop.interface cursor-theme "$CUR_THEME" || echo "WARNING: could not set the GTK cursor" >&2
  [ -n "$CUR_SIZE" ] && { gset org.gnome.desktop.interface cursor-size "$CUR_SIZE" || echo "WARNING: could not set the GTK cursor size" >&2; }
fi
# KYU-ASSETS
# Fondos y avatar en ~/Pictures/Wallpapers (ruta fija en ingles); las imagenes vienen en config/wallpapers.
mkdir -p "$HOME/Pictures/Wallpapers"
for f in "$REPO_DIR"/config/wallpapers/*; do
  [ -e "$HOME/Pictures/Wallpapers/$(basename "$f")" ] || cp "$f" "$HOME/Pictures/Wallpapers/"
done
mkdir -p "$HOME/.config/noctalia/palettes"
backup_and_copy "$REPO_DIR/config/noctalia/palettes" "$HOME/.config/noctalia/palettes"
# KYU-NOCTALIA-TEMPLATES: plantilla palette-raw.conf (la lee el sync de RGB; sin ella noctalia falla al aplicar plantillas)
mkdir -p "$HOME/.config/noctalia/templates"
backup_and_copy "$REPO_DIR/config/noctalia/templates" "$HOME/.config/noctalia/templates"
backup_and_copy "$REPO_DIR/config/noctalia/noctalia-full-config.toml" "$HOME/.config/noctalia/noctalia-full-config.toml"
sed -i "s|/home/kyu/|$HOME/|g" "$HOME/.config/noctalia/noctalia-full-config.toml"

# --- PATH de la sesión gráfica ---------------------------------------------
# systemd --user no incluye ~/.local/bin; sin esto, miri y cualquier binario
# propio son invisibles para el launcher.
# Overlay de hooks GPU/RGB: se carga al final (zz-) y solo pisa lo que declara,
# asi convive con una config completa propia en ~/.config/noctalia/.
backup_and_copy "$REPO_DIR/config/noctalia/zz-porphyx.toml" "$HOME/.config/noctalia/zz-porphyx.toml"
sed -i "s|\"HOME/|\"$HOME/|g" "$HOME/.config/noctalia/zz-porphyx.toml"
if grep -q '"HOME/' "$HOME/.config/noctalia/zz-porphyx.toml"; then
  echo "ERROR: unreplaced placeholders in zz-porphyx.toml" >&2
  exit 1
fi

# Barra, widgets, tema y fondo (Noctalia fusiona los *.toml de ~/.config/noctalia/; zz- se carga al final).
backup_and_copy "$REPO_DIR/config/noctalia/zz-settings.toml" "$HOME/.config/noctalia/zz-settings.toml"
sed -i "s|/home/kyu/|$HOME/|g" "$HOME/.config/noctalia/zz-settings.toml"

backup_and_copy "$REPO_DIR/config/environment.d/10-path.conf" "$HOME/.config/environment.d/10-path.conf"


# Pantalla de bloqueo compacta: el layout va por nombre de salida, se genera una entrada por monitor conectado.
python3 - "$REPO_DIR/config/noctalia/lockscreen-widgets.toml" "$HOME/.config/noctalia/zz-lockscreen.toml" <<'GENEOF' || { echo "ERROR: could not generate zz-lockscreen.toml" >&2; exit 1; }
import glob, os, re, sys, tomllib
tpl = open(sys.argv[1]).read()
outs = []
for d in sorted(glob.glob('/sys/class/drm/card*-*')):
    try:
        if open(d + '/status').read().strip() == 'connected':
            outs.append(d.split('/')[-1].split('-', 1)[1])
    except OSError:
        pass
outs = outs or ['eDP-1']
i = tpl.index('    [lockscreen_widgets.widget.')
head, body = tpl[:i], tpl[i:]
parts, ids = [], []
for n, o in enumerate(outs, 1):
    cid = 'lockscreen-widget-%016d' % n
    parts.append(body.replace('eDP-1', o).replace('lockscreen-widget-0000000000000001', cid))
    ids += ['lockscreen-login-box@' + o, cid]
head = re.sub(r'(?m)^widget_order = .*$', 'widget_order = [ ' + ', '.join('"%s"' % x for x in ids) + ' ]', head)
out = head + ''.join(parts)
tomllib.loads(out)
os.makedirs(os.path.dirname(sys.argv[2]), exist_ok=True)
open(sys.argv[2], 'w').write(out)
GENEOF

echo "== File manager (Luciole) + Papirus icons =="
LUC=dev.noctalia.luciole.desktop
if [ -f "/usr/share/applications/$LUC" ]; then
  if [ "$(xdg-mime query default inode/directory)" != "$LUC" ]; then
    xdg-mime default "$LUC" inode/directory
    echo "inode/directory now points to Luciole."
  else
    echo "inode/directory already set to Luciole, skipping."
  fi
else
  echo "WARNING: Luciole is not installed, inode/directory unchanged." >&2
fi
for pkg in papirus-icon-theme; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    sudo pacman -S --needed --noconfirm "$pkg"
  else
    echo "$pkg already installed, skipping pacman."
  fi
done


echo "== Zsh (packages + config + p10k) =="
if ! pacman -Qi zsh &>/dev/null; then
  sudo pacman -S --needed --noconfirm zsh
else
  echo "zsh already installed, skipping pacman."
fi
# KYU-ZSH-VENDOR
# Se despliega la copia vendorizada del repo
# (necesita oh-my-zsh-git y zsh-theme-powerlevel10k-git, del repo local porphyx).
if [ -f /usr/share/cachyos-zsh-config/cachyos-config.zsh ]; then
  echo "cachyos-config.zsh already present, skipping."
else
  sudo install -Dm644 "$REPO_DIR/config/zsh/cachyos-config.zsh" /usr/share/cachyos-zsh-config/cachyos-config.zsh
fi
command -v zoxide &>/dev/null || sudo pacman -S --needed --noconfirm zoxide
command -v eza &>/dev/null || sudo pacman -S --needed --noconfirm eza
backup_and_copy "$REPO_DIR/config/zsh/zshrc" "$HOME/.zshrc"
backup_and_copy "$REPO_DIR/config/zsh/p10k.zsh" "$HOME/.p10k.zsh"
if [ "$(basename "$SHELL")" != "zsh" ]; then
  sudo chsh -s "$(command -v zsh)" "$USER"
  echo "shell changed to zsh -- takes effect at next login"
else
  echo "zsh is already the default shell."
fi

echo "== Zsh completions for noctalia =="
# Se generan del esquema vivo e incluyen subcomandos de los plugins instalados.
# Regenerar tras instalar/quitar plugins con el mismo comando.
if command -v noctalia &>/dev/null; then
  mkdir -p "$HOME/.local/share/zsh/site-functions"
  if noctalia completions zsh > "$HOME/.local/share/zsh/site-functions/_noctalia" 2>/dev/null \
     && head -1 "$HOME/.local/share/zsh/site-functions/_noctalia" | grep -q "^#compdef noctalia"; then
    echo "completions installed."
  else
    rm -f "$HOME/.local/share/zsh/site-functions/_noctalia"
    echo "WARN: noctalia completions failed, skipping." >&2
  fi
else
  echo "WARN: noctalia not found, skipping completions." >&2
fi

echo "== Foot (package + config + Noctalia theme) =="
if ! pacman -Qi foot &>/dev/null; then
  sudo pacman -S --needed --noconfirm foot
else
  echo "foot already installed, skipping pacman."
fi
backup_and_copy "$REPO_DIR/config/foot" "$HOME/.config/foot"
# KYU-FOOT-SEED: tema inicial; noctalia lo regenera. Sin el, foot falla si noctalia aun no lo genero.
mkdir -p "$HOME/.config/foot/themes"
[ -f "$HOME/.config/foot/themes/noctalia" ] || cp "$REPO_DIR/assets/foot-theme-noctalia.seed" "$HOME/.config/foot/themes/noctalia"


echo "== Zen Browser =="
if ! pacman -Qi zen-browser-bin &>/dev/null; then
  echo "Zen Browser not selected, skipping."
else
  echo "zen-browser-bin already installed, skipping pacman."
fi

systemctl --user daemon-reload

need_paru() { command -v paru >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm paru; }
PORPHYX_SESSION="${PORPHYX_SESSION:-umbriel}"
if [ "$PORPHYX_SESSION" = umbriel ]; then
echo "== Umbriel (main compositor) =="
for pkg in umbriel-git xdg-desktop-portal-umbriel-git; do
  if pacman -Qi "$pkg" &>/dev/null; then
    echo "$pkg already installed, skipping."
  else
    need_paru; paru -S --needed --noconfirm --skipreview "$pkg"
  fi
done
backup_and_copy "$REPO_DIR/config/umbriel/config.toml" "$HOME/.config/umbriel/config.toml"
# KYU-UMBRIEL-INCLUDES
# Umbriel invalida la config si falta un include y hay politica [drm]: drm.toml queda vacio.
printf '# sin politica DRM propia\n' > "$HOME/.config/umbriel/drm.toml"
mkdir -p "$HOME/.config/umbriel/effects"
cp -a "$REPO_DIR/config/umbriel/effects/." "$HOME/.config/umbriel/effects/"
# outputs.toml y noctalia.toml van en [include.optional], pero sin ellos la validacion falla; Noctalia reescribe noctalia.toml.
for _f in outputs.toml noctalia.toml; do
  [ -e "$HOME/.config/umbriel/$_f" ] || printf '# placeholder creado por install.sh\n' > "$HOME/.config/umbriel/$_f"
done
# KYU-UMBRIEL-SCHEMA
# Umbriel nuevo: input.focus.follows_mouse ya no acepta booleanos ("off", "sloppy" o "always").
# El repo conserva true para el umbriel viejo; aqui se convierte la copia desplegada si hace falta.
umbriel_out=$(umbriel config validate 2>&1 || true)
if printf '%s\n' "$umbriel_out" | grep -q 'follows_mouse'; then
  sed -i -E 's/^([[:space:]]*follows_mouse[[:space:]]*=[[:space:]]*)true/\1"always"/; s/^([[:space:]]*follows_mouse[[:space:]]*=[[:space:]]*)false/\1"off"/' "$HOME/.config/umbriel/config.toml"
  echo "config.toml: follows_mouse converted to the new umbriel schema."
fi
umbriel config validate
fi

# KYU-PRINCIPAL-UMBRIEL
echo "== Umbriel as the main desktop =="
_otros=()
for _pkg in niri hyprland sway river labwc plasma-desktop plasma-workspace gnome-shell gnome-session xfce4-session cosmic-session cinnamon budgie-desktop mate-session-manager lxqt-session i3-wm bspwm awesome openbox qtile; do
  pacman -Qq "$_pkg" >/dev/null 2>&1 && _otros+=("$_pkg")
done
if [ "$PORPHYX_SESSION" = umbriel ] && [ "${#_otros[@]}" -gt 0 ]; then
  echo "Other desktops or compositors installed: ${_otros[*]}"
  if [ -r /dev/tty ]; then
    read -r -p "Remove them and keep Umbriel as the main desktop? [y/N] " _resp </dev/tty
  else
    _resp=n
  fi
  case "$_resp" in
    s|S|y|Y) sudo pacman -Rns "${_otros[@]}" </dev/tty ;;
    *) echo "Keeping them." ;;
  esac
else
  echo "No other desktops changed."
fi

# KYU-LABWC
if [ "$PORPHYX_SESSION" = labwc ]; then
  echo "== Labwc (config + Noctalia autostart) =="
  backup_and_copy "$REPO_DIR/config/labwc" "$HOME/.config/labwc"
  if [ -n "$CUR_THEME" ]; then
    printf 'XCURSOR_THEME=%s\nXCURSOR_SIZE=%s\n' "$CUR_THEME" "${CUR_SIZE:-24}" > "$HOME/.config/labwc/environment"
  fi
fi

# KYU-POWERKEY
echo "== Power button (lock + suspend) =="
sudo install -Dm644 "$REPO_DIR/logind/50-porphyx-powerkey.conf" /etc/systemd/logind.conf.d/50-porphyx-powerkey.conf
sudo systemctl kill -s HUP systemd-logind

# KYU-TERMINAL-APPS
echo "== Terminal apps (cava, cmatrix, lavat, tty-clock, playerctl) =="
for pkg in cava cmatrix playerctl; do
  pacman -Qi "$pkg" &>/dev/null || sudo pacman -S --needed --noconfirm "$pkg"
done
# KYU-CAVA-CONFIG: el template de noctalia exige que exista ~/.config/cava/config
mkdir -p "$HOME/.config/cava"
[ -f "$HOME/.config/cava/config" ] || printf '[general]\n' > "$HOME/.config/cava/config"
# method=pipewire de cava se congela con PipeWire 1.6.x; pulse (via pipewire-pulse) funciona
grep -q '^\[input\]' "$HOME/.config/cava/config" || printf '\n[input]\nmethod = pulse\nsource = auto\n' >> "$HOME/.config/cava/config"
# KYU-LAVAT
pacman -Qi lavat &>/dev/null || { need_paru; paru -S --needed --noconfirm --skipreview lavat; }
pacman -Qi tty-clock &>/dev/null || { need_paru; paru -S --needed --noconfirm --skipreview tty-clock || echo "WARNING: tty-clock not installed" >&2; }
for f in "$REPO_DIR"/config/applications/porphyx-*.desktop; do
  backup_and_copy "$f" "$HOME/.local/share/applications/$(basename "$f")"
done
# Zen: Papirus dibuja el logo naranja viejo; apuntar al PNG oficial del paquete
ZEN_SRC=/usr/share/applications/zen.desktop
ZEN_PNG=/usr/share/icons/hicolor/128x128/apps/zen-browser.png
if [ -f "$ZEN_SRC" ] && [ -f "$ZEN_PNG" ]; then
  mkdir -p "$HOME/.local/share/applications"
  sed "s|^Icon=zen-browser\$|Icon=$ZEN_PNG|" "$ZEN_SRC" > "$HOME/.local/share/applications/zen.desktop"
fi
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null

# FileManager1: Luciole sobre Nautilus. El .service del paquete tiene nombre incorrecto y el de Nautilus es del sistema;
# el de usuario tiene prioridad en el bus de sesion.
if [ -x /usr/bin/luciole ]; then
  mkdir -p "$HOME/.local/share/dbus-1/services"
  printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/usr/bin/luciole --file-manager-service\n' > "$HOME/.local/share/dbus-1/services/org.freedesktop.FileManager1.service"
fi

echo "== Fastfetch (system logo and config) =="
FF_SRC="$REPO_DIR/iso/overlay/airootfs/root/.config/fastfetch"
if [ -f "$FF_SRC/config.jsonc" ] && [ -f "$FF_SRC/logo.txt" ]; then
  sudo install -Dm644 "$FF_SRC/logo.txt" /etc/xdg/fastfetch/logo.txt
  sed "s|/root/.config/fastfetch/|/etc/xdg/fastfetch/|g" "$FF_SRC/config.jsonc" | sudo tee /etc/xdg/fastfetch/config.jsonc >/dev/null
fi

echo "== Scripts .local/bin =="
mkdir -p "$HOME/.local/bin"
for f in "$REPO_DIR"/bin/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README.md) continue ;; esac
  backup_and_copy "$f" "$HOME/.local/bin/$(basename "$f")"
  chmod +x "$HOME/.local/bin/$(basename "$f")"
done

echo "✓ done — log out and back in, then pick Umbriel for everything to take effect"
