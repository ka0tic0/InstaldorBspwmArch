#!/usr/bin/env bash
set -euo pipefail
WALL_DIR="$HOME/Imagenes/wallpapers"
REPO="https://github.com/zhichaoh/catppuccin-wallpapers.git"

# Si el directorio está vacío o no existe, clonar y copiar la carpeta misc
if [ ! -d "$WALL_DIR" ] || [ -z "$(ls -A "$WALL_DIR" 2>/dev/null || true)" ]; then
  tmpd="$(mktemp -d)"
  git clone --depth 1 "$REPO" "$tmpd/catpw" 2>/dev/null || true
  if [ -d "$tmpd/catpw/misc" ]; then
    mkdir -p "$WALL_DIR"
    cp -r "$tmpd/catpw/misc/"* "$WALL_DIR/" 2>/dev/null || true
  else
    mkdir -p "$WALL_DIR"
    curl -fsSL -o "$WALL_DIR/catppuccin-fallback.png" "https://raw.githubusercontent.com/zhichaoh/catppuccin-wallpapers/main/misc/mocha.png" || true
  fi
  rm -rf "$tmpd"
fi

# Seleccionar imagen (argumento opcional)
if [ "${#}" -ge 1 ]; then
  IMG="$1"
  if [ ! -f "$IMG" ]; then
    echo "Imagen especificada no encontrada: $IMG" >&2
    exit 1
  fi
else
  IMG="$(find "$WALL_DIR" -type f | shuf -n1 || true)"
fi

# Aplicar con feh si disponible
if command -v feh >/dev/null 2>&1 && [ -n "$IMG" ]; then
  feh --bg-scale "$IMG"
  mkdir -p "$HOME/.config/feh"
  echo "$IMG" > "$HOME/.config/feh/last-wallpaper"
fi
