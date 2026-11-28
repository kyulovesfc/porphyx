#!/usr/bin/env bash
# install.sh — despliegue de dotfiles y entorno Noctalia/Umbriel de Porphyx (Arch).
# Uso: clonar el repo y correr ./install.sh desde su raíz.
set -Eeuo pipefail
trap 'echo "ERROR: línea $LINENO: $BASH_COMMAND" >&2' ERR
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

echo "== Tema de cursor =="
# El tema y el tamaño los define config/umbriel/config.toml ([input.cursor]).
# El cursor Skyrim se copia mas abajo (assets/cursors).

echo "== Config Noctalia =="
# La config es noctalia-full-config.toml mas el overlay zz-porphyx.toml (se despliegan abajo).
# Noctalia fusiona todos los *.toml de ~/.config/noctalia/: un config.toml suelto se mezclaria con la full-config.
if [ -f "$HOME/.config/noctalia/config.toml" ]; then
  echo "AVISO: ~/.config/noctalia/config.toml existe y Noctalia lo fusiona con noctalia-full-config.toml." >&2
  echo "       Si es un resto de una instalacion anterior, muevelo fuera de esa carpeta (p. ej. a config.toml.old)." >&2
fi

# KYU-PALETTE-INSTALL
# Paleta Kyu_Pallete y config completa de Noctalia (rutas /home/kyu resueltas a $HOME).
# Cursor Skyrim (assets/cursors) -> ~/.local/share/icons; no pisa una instalacion existente
mkdir -p "$HOME/.local/share/icons"
for d in "$REPO_DIR"/assets/cursors/*/; do
  [ -d "$d" ] || continue
  [ -e "$HOME/.local/share/icons/$(basename "$d")" ] || cp -r "$d" "$HOME/.local/share/icons/"
done
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
  echo "ERROR: placeholders sin sustituir en zz-porphyx.toml" >&2
  exit 1
fi

# Barra, widgets, tema y fondo (Noctalia fusiona los *.toml de ~/.config/noctalia/; zz- se carga al final).
backup_and_copy "$REPO_DIR/config/noctalia/zz-settings.toml" "$HOME/.config/noctalia/zz-settings.toml"
sed -i "s|/home/kyu/|$HOME/|g" "$HOME/.config/noctalia/zz-settings.toml"

backup_and_copy "$REPO_DIR/config/environment.d/10-path.conf" "$HOME/.config/environment.d/10-path.conf"


# Pantalla de bloqueo compacta: el layout va por nombre de salida, se genera una entrada por monitor conectado.
python3 - "$REPO_DIR/config/noctalia/lockscreen-widgets.toml" "$HOME/.config/noctalia/zz-lockscreen.toml" <<'GENEOF' || { echo "ERROR: no se pudo generar zz-lockscreen.toml" >&2; exit 1; }
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

echo "== Gestor de archivos (Luciole) + iconos Papirus =="
LUC=dev.noctalia.luciole.desktop
if [ -f "/usr/share/applications/$LUC" ]; then
  if [ "$(xdg-mime query default inode/directory)" != "$LUC" ]; then
    xdg-mime default "$LUC" inode/directory
    echo "inode/directory apunta a Luciole."
  else
    echo "inode/directory ya en Luciole, se omite."
  fi
else
  echo "AVISO: Luciole no esta instalado, no se cambia inode/directory." >&2
fi
for pkg in papirus-icon-theme; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    sudo pacman -S --needed --noconfirm "$pkg"
  else
    echo "$pkg ya instalado, se omite pacman."
  fi
done


echo "== Zsh (paquetes + config + p10k) =="
if ! pacman -Qi zsh &>/dev/null; then
  sudo pacman -S --needed --noconfirm zsh
else
  echo "zsh ya instalado, se omite pacman."
fi
# KYU-ZSH-VENDOR
# Se despliega la copia vendorizada del repo
# (necesita oh-my-zsh-git y zsh-theme-powerlevel10k-git, del repo local porphyx).
if [ -f /usr/share/cachyos-zsh-config/cachyos-config.zsh ]; then
  echo "cachyos-config.zsh ya presente, se omite."
else
  sudo install -Dm644 "$REPO_DIR/config/zsh/cachyos-config.zsh" /usr/share/cachyos-zsh-config/cachyos-config.zsh
fi
command -v zoxide &>/dev/null || sudo pacman -S --needed --noconfirm zoxide
command -v eza &>/dev/null || sudo pacman -S --needed --noconfirm eza
backup_and_copy "$REPO_DIR/config/zsh/zshrc" "$HOME/.zshrc"
backup_and_copy "$REPO_DIR/config/zsh/p10k.zsh" "$HOME/.p10k.zsh"
if [ "$(basename "$SHELL")" != "zsh" ]; then
  sudo chsh -s "$(command -v zsh)" "$USER"
  echo "shell cambiada a zsh -- toma efecto en el proximo login"
else
  echo "zsh ya es la shell por defecto."
fi

echo "== Completions de zsh para noctalia =="
# Se generan del esquema vivo e incluyen subcomandos de los plugins instalados.
# Regenerar tras instalar/quitar plugins con el mismo comando.
if command -v noctalia &>/dev/null; then
  mkdir -p "$HOME/.local/share/zsh/site-functions"
  if noctalia completions zsh > "$HOME/.local/share/zsh/site-functions/_noctalia" 2>/dev/null \
     && head -1 "$HOME/.local/share/zsh/site-functions/_noctalia" | grep -q "^#compdef noctalia"; then
    echo "completions instaladas."
  else
    rm -f "$HOME/.local/share/zsh/site-functions/_noctalia"
    echo "WARN: noctalia completions fallo, se omite." >&2
  fi
else
  echo "WARN: noctalia no encontrado, se omiten completions." >&2
fi

echo "== Foot (paquete + config + tema Noctalia) =="
if ! pacman -Qi foot &>/dev/null; then
  sudo pacman -S --needed --noconfirm foot
else
  echo "foot ya instalado, se omite pacman."
fi
backup_and_copy "$REPO_DIR/config/foot" "$HOME/.config/foot"
# KYU-FOOT-SEED: tema inicial; noctalia lo regenera. Sin el, foot falla si noctalia aun no lo genero.
mkdir -p "$HOME/.config/foot/themes"
[ -f "$HOME/.config/foot/themes/noctalia" ] || cp "$REPO_DIR/assets/foot-theme-noctalia.seed" "$HOME/.config/foot/themes/noctalia"


echo "== Zen Browser =="
if ! pacman -Qi zen-browser-bin &>/dev/null; then
  sudo pacman -S --needed --noconfirm zen-browser-bin
else
  echo "zen-browser-bin ya instalado, se omite pacman."
fi

systemctl --user daemon-reload

echo "== Umbriel (compositor principal) =="
need_paru() { command -v paru >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm paru; }
for pkg in umbriel-git xdg-desktop-portal-umbriel-git; do
  if pacman -Qi "$pkg" &>/dev/null; then
    echo "$pkg ya instalado, se omite."
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
  echo "config.toml: follows_mouse convertido al esquema nuevo de umbriel."
fi
umbriel config validate

# KYU-PRINCIPAL-UMBRIEL
echo "== Umbriel como entorno principal =="
_otros=()
for _pkg in niri hyprland sway river labwc plasma-desktop plasma-workspace gnome-shell gnome-session xfce4-session cosmic-session cinnamon budgie-desktop mate-session-manager lxqt-session i3-wm bspwm awesome openbox qtile; do
  pacman -Qq "$_pkg" >/dev/null 2>&1 && _otros+=("$_pkg")
done
if [ "${#_otros[@]}" -gt 0 ]; then
  echo "Otros entornos o compositores instalados: ${_otros[*]}"
  if [ -r /dev/tty ]; then
    read -r -p "Eliminarlos y dejar Umbriel como principal? [s/N] " _resp </dev/tty
  else
    _resp=n
  fi
  case "$_resp" in
    s|S|y|Y) sudo pacman -Rns "${_otros[@]}" </dev/tty ;;
    *) echo "Se conservan." ;;
  esac
else
  echo "No hay otros entornos instalados."
fi

# KYU-POWERKEY
echo "== Boton de apagado (bloquear + suspender) =="
sudo install -Dm644 "$REPO_DIR/logind/50-porphyx-powerkey.conf" /etc/systemd/logind.conf.d/50-porphyx-powerkey.conf
sudo systemctl kill -s HUP systemd-logind

# KYU-TERMINAL-APPS
echo "== Apps de terminal (cava, cmatrix, lavat, tty-clock, playerctl) =="
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
pacman -Qi tty-clock &>/dev/null || { need_paru; paru -S --needed --noconfirm --skipreview tty-clock || echo "AVISO: tty-clock no se instalo" >&2; }
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

echo "== Fastfetch (logo y config del sistema) =="
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

echo "✓ terminado — haz logout/login y elige Umbriel para que todo tome efecto"
