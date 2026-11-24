# Descarga la ISO de Porphyx desde GitHub y verifica el sha256.
# Uso:  curl -fsSL https://raw.githubusercontent.com/kyulovesfc/porphyx/main/get-iso.sh | bash
#       (carpeta distinta: ... | bash -s -- /ruta)   (grabar a USB: USB=/dev/sdX ... | bash)
set -eu
REPO="kyulovesfc/porphyx"; TAG="iso"; NAME="porphyx-latest-x86_64.iso"
DEST="${1:-$HOME/Downloads}"
BASE="https://github.com/$REPO/releases/download/$TAG"
mkdir -p "$DEST"; cd "$DEST"
echo "descargando $NAME (aprox 1.3G) en $DEST"
curl -fL -C - --retry 3 -o "$NAME" "$BASE/$NAME"
curl -fsSL -o "$NAME.sha256" "$BASE/$NAME.sha256"
sha256sum -c "$NAME.sha256"
echo "ISO lista: $DEST/$NAME"
if [ -n "${USB:-}" ]; then
  lsblk "$USB" 2>/dev/null || { echo "dispositivo $USB no existe"; exit 1; }
  printf 'Esto BORRA todo en %s. Escribe BORRAR para continuar: ' "$USB"
  read -r ok </dev/tty
  [ "$ok" = "BORRAR" ] || { echo "cancelado"; exit 0; }
  sudo dd if="$NAME" of="$USB" bs=4M status=progress conv=fsync
  sync; echo "USB lista"
fi
