# select-desktop.sh - sourced by porphyx-setup.sh. One desktop is chosen; Umbriel + Noctalia is the default.
# Sets: DE_CHOICE (id), DE_PKGS (desktop + login manager packages), DE_DM_SERVICE (empty = noctalia-greeter).
# Non-interactive: PORPHYX_DESKTOP=gnome (or PORPHYX_DEFAULTS=1 for Umbriel).
select_desktop() {
  local conf="$HERE/desktops.conf" id name pkgs dm dms out interactive=1 choice=umbriel
  local -A N=() K=() M=() S=()
  local -a ids=() list=()
  DE_CHOICE=umbriel; DE_PKGS=(); DE_DM_SERVICE=""
  while IFS='|' read -r id name pkgs dm dms; do
    case "${id:-}" in ''|'#'*) continue ;; esac
    ids+=("$id"); N[$id]=$name; K[$id]=$pkgs; M[$id]=$dm; S[$id]=$dms
  done < "$conf"

  if [ -n "${PORPHYX_DESKTOP:-}" ]; then choice="$PORPHYX_DESKTOP"; interactive=0; fi
  if [ "${PORPHYX_DEFAULTS:-0}" = 1 ]; then interactive=0; fi
  [ -t 0 ] || interactive=0
  if [ "$interactive" = 1 ]; then
    command -v whiptail >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm libnewt >/dev/null 2>&1 || true
    command -v whiptail >/dev/null 2>&1 || interactive=0
  fi
  if [ "$interactive" = 1 ]; then
    for id in "${ids[@]}"; do
      if [ "$id" = umbriel ]; then list+=("$id" "${N[$id]}" ON); else list+=("$id" "${N[$id]}" OFF); fi
    done
    if out=$(whiptail --title "Desktop" --radiolist "Choose your desktop environment (Space selects, Enter confirms)" 16 76 6 "${list[@]}" 3>&1 1>&2 2>&3); then
      choice="$out"
    fi
  fi
  if [ -z "${N[$choice]:-}" ]; then echo "Unknown desktop '$choice', using umbriel" >&2; choice=umbriel; fi
  DE_CHOICE="$choice"
  DE_PKGS=(${K[$choice]:-} ${M[$choice]:-})
  DE_DM_SERVICE="${S[$choice]:-}"
  echo "Desktop: ${N[$choice]}"
  return 0
}
