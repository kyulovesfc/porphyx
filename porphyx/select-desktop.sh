# select-desktop.sh - sourced by porphyx-setup.sh. Several desktops can be marked; the number is the order:
# 1 = main session (login default), the rest are installed as extra sessions.
# Sets: DE_LIST (ordered ids), DE_CHOICE (main id), DE_PKGS, DE_DM_SERVICE (main desktop's login manager; empty = noctalia-greeter),
#       DE_NOCT_FIRST (first of umbriel/labwc, empty if none), DE_HAS_UMBRIEL (0/1).
# Non-interactive: PORPHYX_DESKTOP="labwc gnome" (or comma separated; first = main).
select_desktop() {
  local conf="$HERE/desktops.conf" id name pkgs dm dms out interactive=1 pos i n h last
  local -A N=() K=() M=() S=()
  local -a ids=() ord=() menu=() req=()
  DE_LIST=(); DE_CHOICE=umbriel; DE_PKGS=(); DE_DM_SERVICE=""; DE_NOCT_FIRST=""; DE_HAS_UMBRIEL=0
  while IFS='|' read -r id name pkgs dm dms; do
    case "${id:-}" in ''|'#'*) continue ;; esac
    ids+=("$id"); N[$id]=$name; K[$id]=$pkgs; M[$id]=$dm; S[$id]=$dms
  done < "$conf"

  ord=(umbriel)
  if [ -n "${PORPHYX_DESKTOP:-}" ]; then
    read -ra req <<< "${PORPHYX_DESKTOP//,/ }"
    ord=()
    for id in "${req[@]}"; do
      if [ "$id" = none ]; then continue; fi
      if [ -z "${N[$id]:-}" ]; then echo "Unknown desktop '$id', skipped" >&2; continue; fi
      case " ${ord[*]:-} " in *" $id "*) ;; *) ord+=("$id") ;; esac
    done
    interactive=0
  fi
  if [ "${PORPHYX_DEFAULTS:-0}" = 1 ]; then interactive=0; fi
  [ -t 0 ] || interactive=0
  if [ "$interactive" = 1 ]; then
    command -v whiptail >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm libnewt >/dev/null 2>&1 || true
    command -v whiptail >/dev/null 2>&1 || interactive=0
  fi

  last="${ids[0]}"
  while [ "$interactive" = 1 ]; do
    menu=()
    for id in "${ids[@]}"; do
      pos=" "
      for i in "${!ord[@]}"; do if [ "${ord[$i]}" = "$id" ]; then pos=$((i + 1)); fi; done
      menu+=("$id" "[$pos] ${N[$id]}")
    done
    menu+=("done" "Continue with this selection")
    n=$(( ${#menu[@]} / 2 )); h=$((n + 10))
    if ! out=$(whiptail --title "Desktop" --default-item "$last" --menu "Enter marks/unmarks a desktop. The number is the order: [1] is the main session (login default), the others are installed as extra sessions. Mark none to skip the desktop." "$h" 78 "$n" "${menu[@]}" 3>&1 1>&2 2>&3); then
      break
    fi
    last="$out"
    if [ "$out" = done ]; then break; fi
    if [[ " ${ord[*]:-} " == *" $out "* ]]; then
      local -a keep=()
      for id in "${ord[@]}"; do if [ "$id" != "$out" ]; then keep+=("$id"); fi; done
      ord=("${keep[@]}")
    else
      ord+=("$out")
    fi
  done

  if [ "${#ord[@]}" -eq 0 ]; then
    DE_CHOICE=""
    echo "No desktop? Alrighty..."
    return 0
  fi
  DE_LIST=("${ord[@]}"); DE_CHOICE="${ord[0]}"
  for id in "${ord[@]}"; do
    DE_PKGS+=(${K[$id]:-})
    case "$id" in umbriel|labwc) if [ -z "$DE_NOCT_FIRST" ]; then DE_NOCT_FIRST="$id"; fi ;; esac
    if [ "$id" = umbriel ]; then DE_HAS_UMBRIEL=1; fi
  done
  DE_PKGS+=(${M[$DE_CHOICE]:-})
  DE_DM_SERVICE="${S[$DE_CHOICE]:-}"
  if [ "${#ord[@]}" -gt 1 ]; then export PORPHYX_KEEP_DE=1; fi
  echo "Desktops: main=${N[$DE_CHOICE]}; extra=${ord[*]:1}"
  return 0
}
