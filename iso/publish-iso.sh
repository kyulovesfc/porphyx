# Sube la ISO mas reciente de iso/out al release fijo "iso" (nombre estable + sha256).
set -eu
cd "$(dirname "$0")/.."
T0=$(gh auth token -u kyulovesfc 2>/dev/null || true); [ -z "$T0" ] || export GH_TOKEN="$T0"
REPO="kyulovesfc/porphyx"; N="porphyx-latest-x86_64.iso"
ISO=$(ls -t iso/out/porphyx-*.iso 2>/dev/null | head -1)
[ -n "$ISO" ] || { echo "no hay ISO en iso/out"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
echo "preparando $ISO"
cp "$ISO" "$T/$N"; ( cd "$T" && sha256sum "$N" > "$N.sha256" )
gh release view iso -R "$REPO" >/dev/null 2>&1 || gh release create iso -R "$REPO" --target main --latest=false \
  --title "porphyx ISO (latest)" --notes "ISO de instalacion. Descarga y verifica con get-iso.sh"
gh release upload iso -R "$REPO" --clobber "$T/$N" "$T/$N.sha256"
echo "publicada: https://github.com/$REPO/releases/download/iso/$N"
