#!/usr/bin/env bash
# porphyx-select.sh - runs inside porphyx-install before archinstall. Usage: porphyx-select.sh archinstall.json
# Asks for apps and desktops (same menus as porphyx setup), adds the core/extra packages to the archinstall config
# and saves the full selection for porphyx setup (/var/lib/porphyx/selection.env on the installed system).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${1:?usage: porphyx-select.sh archinstall.json}"
OUT="${PORPHYX_SELECT_OUT:-/tmp/porphyx-selection.env}"
export NEWT_COLORS='
  root=white,black window=white,black border=magenta,black title=magenta,black roottext=magenta,black shadow=black,black
  button=black,magenta actbutton=white,magenta compactbutton=white,black checkbox=white,black actcheckbox=black,magenta
  entry=white,black disentry=gray,black label=white,black listbox=white,black actlistbox=black,magenta
  sellistbox=magenta,black actsellistbox=black,magenta textbox=white,black acttextbox=black,magenta helpline=white,black
  emptyscale=black,black fullscale=magenta,magenta'
if [ "$(id -u)" -eq 0 ]; then pacman -Sy >/dev/null 2>&1 || echo "WARNING: could not sync the package databases" >&2; fi

. "$HERE/select-apps.sh"
. "$HERE/select-desktop.sh"
select_apps
select_desktop
desk=none
if [ "${#DE_LIST[@]}" -gt 0 ]; then desk="${DE_LIST[*]}"; fi
printf 'PORPHYX_APPS="%s"\nPORPHYX_DESKTOP="%s"\n' "${SEL[*]:-}" "$desk" > "$OUT"
chmod 644 "$OUT"

ADD=(); DEFER=()
for p in "${SEL[@]}" "${DE_PKGS[@]}"; do
  case "$p" in aur:*|flatpak:*) DEFER+=("$p"); continue ;; esac
  if pacman -Si "$p" >/dev/null 2>&1 || pacman -Sg "$p" >/dev/null 2>&1; then ADD+=("$p"); else DEFER+=("$p"); fi
done
python3 - "$CFG" "${ADD[@]}" <<'PYEOF'
import json, sys
cfg_path, add = sys.argv[1], sys.argv[2:]
cfg = json.load(open(cfg_path))
pk = list(cfg.get("packages", []))
for p in add:
    if p not in pk:
        pk.append(p)
cfg["packages"] = pk
json.dump(cfg, open(cfg_path, "w"), indent=2)
print("Installer packages added:", " ".join(add) or "none")
PYEOF
echo "Left for porphyx setup (multilib, AUR, Flatpak): ${DEFER[*]:-none}"
exit 0
