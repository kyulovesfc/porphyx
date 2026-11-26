# config/

Dotfiles que `install.sh` despliega. Cada carpeta es un módulo independiente.

| Carpeta | Contenido | Estado |
|---|---|---|
| `noctalia/` | `noctalia-full-config.toml` (la config completa), `zz-porphyx.toml` (overlay con hook de arranque y greeter, se carga al final), `palettes/`, `scripts/` | Vigente |
| `umbriel/` | `config.toml` de Umbriel (va a `~/.config/umbriel/`) y `effects/` (presets de animacion propios, como `workspace_wipe_rev`; van a `~/.config/umbriel/effects/`) | Vigente |
| `foot/` | `foot.ini` | Vigente |
| `zsh/` | `zshrc` y `p10k.zsh` | Vigente |
| `applications/` | Entradas de launcher: cava, cmatrix, lavat y tty-clock. Van a `~/.local/share/applications` | Vigente |
| `environment.d/` | `10-path.conf` | Vigente |

Noctalia carga todos los `*.toml` de `~/.config/noctalia/` en orden alfabético; por eso el overlay
se llama `zz-` y solo pisa lo que declara. Las reglas de placeholders de rutas están en
[../docs/instalacion-detalle.md](../docs/instalacion-detalle.md).
