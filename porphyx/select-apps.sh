# select-apps.sh - sourced by porphyx-setup.sh. Fills SEL with the optional packages to install.
# Data: categories.conf, one app per line: Category|package|Description|default (1 = preselected)
# Keys may carry a source prefix (aur: or flatpak:); the menu shows them without it.
select_apps() {
  local conf="$HERE/categories.conf" cat pkg desc def out item interactive=1
  local cols rows w h lh n tagmax descmax tag
  local -a cats=() list=()
  local -A items=() tagmap=()
  SEL=()
  if [ -n "${PORPHYX_APPS+x}" ]; then
    read -ra SEL <<< "$PORPHYX_APPS"
    echo "Apps selected (${#SEL[@]}): ${SEL[*]:-none}"
    return 0
  fi
  while IFS='|' read -r cat pkg desc def; do
    case "${cat:-}" in ''|'#'*) continue ;; esac
    case " ${cats[*]:-} " in *" $cat "*) ;; *) cats+=("$cat") ;; esac
    items[$cat]+="$pkg|$desc|$def"$'\n'
  done < "$conf"

  _cat_defaults() {
    while IFS='|' read -r pkg desc def; do
      if [ -n "$pkg" ] && [ "$def" = 1 ]; then SEL+=("$pkg"); fi
    done <<< "${items[$1]}"
    return 0
  }

  if [ "${PORPHYX_DEFAULTS:-0}" = 1 ]; then interactive=0; fi
  [ -t 0 ] || interactive=0
  if [ "$interactive" = 1 ]; then
    command -v whiptail >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm libnewt >/dev/null 2>&1 || true
    command -v whiptail >/dev/null 2>&1 || interactive=0
  fi
  if [ "$interactive" = 1 ]; then
    if out=$(whiptail --title "Porphyx setup" --menu "How do you want to choose your apps?" 14 70 2 \
        recommended "Recommended selection (fastest)" \
        custom "Choose apps by category" 3>&1 1>&2 2>&3); then
      [ "$out" = custom ] || interactive=0
    else
      interactive=0
    fi
  fi

  cols=$(tput cols 2>/dev/null || echo 100); rows=$(tput lines 2>/dev/null || echo 30)
  for cat in "${cats[@]}"; do
    if [ "$interactive" = 0 ]; then _cat_defaults "$cat"; continue; fi
    list=(); tagmap=(); n=0; tagmax=0; descmax=0
    while IFS='|' read -r pkg desc def; do
      [ -n "$pkg" ] || continue
      tag="${pkg#aur:}"; tag="${tag#flatpak:}"
      tagmap[$tag]="$pkg"; n=$((n + 1))
      [ "${#tag}" -gt "$tagmax" ] && tagmax=${#tag}
      [ "${#desc}" -gt "$descmax" ] && descmax=${#desc}
      if [ "$def" = 1 ]; then list+=("$tag" "$desc" ON); else list+=("$tag" "$desc" OFF); fi
    done <<< "${items[$cat]}"
    w=$((tagmax + descmax + 16)); [ "$w" -lt 60 ] && w=60; [ "$w" -gt $((cols - 4)) ] && w=$((cols - 4))
    lh=$n; [ "$lh" -gt 15 ] && lh=15
    h=$((lh + 8)); [ "$h" -gt $((rows - 2)) ] && h=$((rows - 2))
    if out=$(whiptail --separate-output --title "$cat" --checklist "Space selects, Enter confirms" "$h" "$w" "$lh" "${list[@]}" 3>&1 1>&2 2>&3); then
      while IFS= read -r item; do
        if [ -n "$item" ]; then SEL+=("${tagmap[$item]:-$item}"); fi
      done <<< "$out"
    else
      _cat_defaults "$cat"
    fi
  done
  echo "Apps selected (${#SEL[@]}): ${SEL[*]:-none}"
  return 0
}
