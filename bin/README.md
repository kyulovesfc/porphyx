# bin/

Scripts que `install.sh` copia a `~/.local/bin`.

| Script | Qué hace |
|---|---|
| `porphyx-plugins` | Habilita una sola vez los 13 plugins de Noctalia del setup (la lista esta en el propio script). Lo lanza el hook `started` del overlay; deja un marcador en `~/.local/state/porphyx/` y reintenta en el siguiente arranque si Noctalia aun no responde |
| `rotate-backups.sh` | Deja solo los N respaldos más recientes por archivo base. Uso: `rotate-backups.sh [N]` (por defecto 3) |
| `umbriel-keybinds` | Editor TUI de la sección `[keybinds]` de la config de Umbriel (`UMBRIEL_CONFIG` cambia el archivo) |
| `alienware/` | RGB para Alienware. Sin soporte, ver [../alienware-setup/README.md](../alienware-setup/README.md) |
