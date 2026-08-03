#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# setup_bspwm_catppuccin_allinone.sh
# Instalador todo-en-uno para un entorno bspwm con estética Catppuccin Mocha
# sobre Arch Linux (instalación base).
#
# Qué hace:
# - Instala paquetes oficiales con pacman (lista estricta solicitada, más
#   git/base-devel necesarios para AUR helper).
# - Instala yay (helper AUR) si falta y luego instala paquetes AUR listados.
# - Crea ~/.config para bspwm, sxhkd, polybar, rofi, picom, dunst, kitty, etc.
# - Copia bspwmrc/sxhkdrc desde /usr/share/doc si existen (requisito del usuario).
# - Genera bspwmrc y sxhkdrc completos y funcionales (autostart: sxhkd, picom,
#   dunst, nm-applet, wallpaper_setup, polybar).
# - Crea polybar config + scripts (volumen, batería, red) y launcher.
# - Crea tema rofi Catppuccin y menú de energía (rofi).
# - Crea ~/.local/bin/wallpaper_setup que descarga wallpapers Catppuccin (misc)
#   y los aplica con feh.
# - Habilita NetworkManager, SDDM y servicios PipeWire (audio).
#
# Uso:
#   chmod +x setup_bspwm_catppuccin_allinone.sh
#   ./setup_bspwm_catppuccin_allinone.sh
#
# Ejecuta como usuario normal (no root). El script usará sudo para operaciones
# que requieren privilegios.
# -----------------------------------------------------------------------------

# -----------------------
# VARIABLES (ajustables)
# -----------------------
WALL_DIR="$HOME/Imagenes/wallpapers"
LOCAL_BIN="$HOME/.local/bin"
BSPWM_CONFIG_DIR="$HOME/.config/bspwm"
SXHKD_CONFIG_DIR="$HOME/.config/sxhkd"
POLYBAR_DIR="$HOME/.config/polybar"
ROFI_DIR="$HOME/.config/rofi"
PICOM_DIR="$HOME/.config/picom"
DUNST_DIR="$HOME/.config/dunst"
KITTY_DIR="$HOME/.config/kitty"
POLYBAR_SCRIPTS_DIR="$POLYBAR_DIR/scripts"

# Paleta Catppuccin Mocha (colores usados en archivos)
C_BG="#1E1E2E"
C_MANTLE="#181825"
C_CRUST="#11111B"
C_TEXT="#CAD3F5"
C_SUBTEXT1="#B8C0E0"
C_MAUVE="#CBA6F7"
C_RED="#F38BA8"
C_YELLOW="#F9E2AF"
C_GREEN="#A6E3A1"
C_BLUE="#89B4FA"

# -----------------------
# LISTAS DE PAQUETES
# -----------------------
# Paquetes estrictos a instalar desde repos oficiales según tu lista:
pacman_pkgs=(
  xorg
  xorg-xinit
  bspwm
  sxhkd
  picom
  dunst
  polybar
  rofi
  kitty
  thunar
  feh
  lxappearance
  networkmanager
  network-manager-applet
  pipewire
  pipewire-alsa
  pipewire-pulse
  pipewire-jack
  wireplumber
  noto-fonts
  noto-fonts-emoji
  ttf-font-awesome
  sddm
  # helper packages required to build AUR helpers (git, base-devel)
  git
  base-devel
  wget
  curl
)

# Paquetes AUR solicitados (se instalarán con yay).
# Incluimos también fuentes Nerd que normalmente están en AUR.
aur_pkgs=(
  catppuccin-gtk-theme-mocha
  tela-circle-icone-theme-Nord
  nitrogen-git
  brave-origin
  ttf-jetbrains-mono-nerd
  ttf-nerd-fonts-symbols
)

# -----------------------
# FUNCIONES AUXILIARES
# -----------------------
info() { printf "\n[INFO] %s\n" "$*"; }
warn() { printf "\n[WARN] %s\n" "$*"; }
err() {
  printf "\n[ERROR] %s\n" "$*"
  exit 1
}

# Comprueba sudo disponible
command -v sudo >/dev/null 2>&1 || err "Necesitas 'sudo' instalado y configurado para ejecutar este script."

info "Solicitando credenciales sudo (si no están cacheadas)..."
sudo -v

# -----------------------
# ACTUALIZAR E INSTALAR PACMAN
# -----------------------
info "Actualizando sistema y instalando paquetes oficiales con pacman..."
# Actualiza la base del sistema
sudo pacman -Syu --noconfirm

# Instala los paquetes listados. --needed evita reinstalar si ya están.
sudo pacman -S --noconfirm --needed "${pacman_pkgs[@]}"

# -----------------------
# INSTALAR YAY (AUR HELPER) SI FALTA
# -----------------------
if ! command -v yay >/dev/null 2>&1; then
  info "yay no detectado: procediendo a instalar yay desde AUR."
  tmpdir="$(mktemp -d)"
  # Clonamos y compilamos yay localmente (se requiere base-devel)
  (
    cd "$tmpdir"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    # makepkg -si instala el paquete en el sistema (pedirá sudo internamente)
    makepkg -si --noconfirm
  )
  rm -rf "$tmpdir"
  info "yay instalado."
else
  info "yay ya instalado en el sistema."
fi

# -----------------------
# INSTALAR PAQUETES AUR
# -----------------------
if [ "${#aur_pkgs[@]}" -gt 0 ]; then
  info "Instalando paquetes AUR con yay (esto puede tomar tiempo)..."
  # Usamos yay con --noconfirm y --needed, y capturamos el código de salida para avisos.
  set +e
  yay -S --noconfirm --needed "${aur_pkgs[@]}"
  yay_exit=$?
  set -e
  if [ $yay_exit -ne 0 ]; then
    warn "La instalación AUR devolvió código $yay_exit. Revisa la salida para paquetes que requieran intervención manual."
  fi
fi

# -----------------------
# CREAR ESTRUCTURA DE DIRECTORIOS
# -----------------------
info "Creando la estructura de configuración en ~/.config y directorios locales..."
mkdir -p \
  "$BSPWM_CONFIG_DIR" \
  "$SXHKD_CONFIG_DIR" \
  "$POLYBAR_DIR" \
  "$POLYBAR_SCRIPTS_DIR" \
  "$ROFI_DIR" \
  "$PICOM_DIR" \
  "$DUNST_DIR" \
  "$KITTY_DIR" \
  "$LOCAL_BIN" \
  "$WALL_DIR" \
  "$HOME/.config/feh"

# -----------------------
# COPIAR bspwmrc Y sxhkdrc DE /usr/share/doc (si existen)
# -----------------------
info "Intentando copiar bspwmrc y sxhkdrc de ejemplo desde /usr/share/doc o /usr/share/examples..."

copy_example_if_exists() {
  # copy_example_if_exists dest src1 src2 ...
  local dest="$1"
  shift
  for p in "$@"; do
    if [ -f "$p" ]; then
      cp -v "$p" "$dest"
      chmod +x "$dest" || true
      return 0
    fi
  done
  return 1
}

bspwm_candidates=(
  "/usr/share/doc/bspwm/examples/bspwmrc"
  "/usr/share/doc/bspwm/bspwmrc"
  "/usr/share/examples/bspwm/bspwmrc"
)
sxhkd_candidates=(
  "/usr/share/doc/sxhkd/examples/sxhkdrc"
  "/usr/share/doc/sxhkd/sxhkdrc"
  "/usr/share/examples/sxhkd/sxhkdrc"
)

if copy_example_if_exists "$BSPWM_CONFIG_DIR/bspwmrc" "${bspwm_candidates[@]}"; then
  info "bspwmrc de ejemplo copiado a $BSPWM_CONFIG_DIR/bspwmrc"
else
  warn "No se encontró bspwmrc de ejemplo; se generará uno completo y funcional más abajo."
fi

if copy_example_if_exists "$SXHKD_CONFIG_DIR/sxhkdrc" "${sxhkd_candidates[@]}"; then
  info "sxhkdrc de ejemplo copiado a $SXHKD_CONFIG_DIR/sxhkdrc"
else
  warn "No se encontró sxhkdrc de ejemplo; se generará uno completo y funcional más abajo."
fi

# Hacer backups de originales si existían
[ -f "$BSPWM_CONFIG_DIR/bspwmrc" ] && cp -v "$BSPWM_CONFIG_DIR/bspwmrc" "$BSPWM_CONFIG_DIR/bspwmrc.orig" || true
[ -f "$SXHKD_CONFIG_DIR/sxhkdrc" ] && cp -v "$SXHKD_CONFIG_DIR/sxhkdrc" "$SXHKD_CONFIG_DIR/sxhkdrc.orig" || true

# -----------------------
# ESCRIBIR bspwmrc COMPLETO (sobrescribe/crea)
# -----------------------
info "Creando ~/.config/bspwm/bspwmrc completo (autostart incluido)..."
cat >"$BSPWM_CONFIG_DIR/bspwmrc" <<EOF
#!/usr/bin/env bash
# bspwmrc generado automáticamente por setup_bspwm_catppuccin_allinone.sh
# Autostart y configuración básica

export PATH="\$HOME/.local/bin:\$PATH"

# Monitores y escritorios
bspc monitor -d I II III IV V VI VII VIII IX X

# Estética y comportamiento
bspc config border_width 2
bspc config window_gap 8
bspc config focused_border_color "${C_MAUVE}"
bspc config normal_border_color "${C_CRUST}"
bspc config presel_feedback_color "${C_YELLOW}"
bspc config focus_follows_pointer true
bspc config split_ratio 0.52

# Reglas de ventanas (ejemplos)
bspc rule -a Gimp state=floating
bspc rule -a mpv state=floating
bspc rule -a Pavucontrol state=floating
bspc rule -a feh state=floating

# Mapear aplicaciones a escritorios (puedes ajustar)
bspc rule -a Brave-browser desktop='^9' follow=on
bspc rule -a firefox desktop='^9' follow=on
bspc rule -a kitty desktop='^1' follow=off

# Autostart (arrancar solo si no existen procesos)
pgrep -x sxhkd >/dev/null 2>&1 || (sxhkd &)
pgrep -x picom >/dev/null 2>&1 || (picom --experimental-backends --config "\$HOME/.config/picom/picom.conf" &)
pgrep -x dunst >/dev/null 2>&1 || (dunst &)
pgrep -x nm-applet >/dev/null 2>&1 || (nm-applet &)

# Iniciar polybar si está instalado
if [ -x "\$HOME/.config/polybar/launch.sh" ]; then
  "\$HOME/.config/polybar/launch.sh" &
fi

# Restaurar wallpaper (script local)
"\$HOME/.local/bin/wallpaper_setup" &

# Ajustes del ratón (opcional)
bspc config pointer_action1 move
bspc config pointer_action2 resize
EOF

# Asegurar permisos de ejecución
chmod +x "$BSPWM_CONFIG_DIR/bspwmrc"

# -----------------------
# ESCRIBIR sxhkdrc COMPLETO (sobrescribe/crea)
# -----------------------
info "Creando ~/.config/sxhkd/sxhkdrc completo (atajos útiles)..."
cat >"$SXHKD_CONFIG_DIR/sxhkdrc" <<'EOF'
# sxhkdrc generado por setup_bspwm_catppuccin_allinone.sh
super = Mod4

# Terminal
super + Return
    kitty

# Browser
super + b
    brave

# File manager
super + e
    thunar

# Rofi launcher
super + d
    rofi -show drun -theme ~/.config/rofi/catppuccin.rasi

# Power menu
super + alt + p
    ~/.local/bin/rofi_power_menu

# Window navigation
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Toggle floating
super + shift + space
    bspc node -t floating && bspc node -t tiled

# Fullscreen
super + f
    bspc node -t fullscreen

# Kill window
super + shift + q
    bspc node -c

# Restart bspwm
super + shift + r
    bspc wm -r

# Logout (quit)
super + shift + e
    bspc quit

# Volume keys (XF86)
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brightness (requires brightnessctl or xbacklight)
XF86MonBrightnessUp
    if command -v brightnessctl >/dev/null 2>&1; then brightnessctl set +10%; elif command -v xbacklight >/dev/null 2>&1; then xbacklight -inc 10; fi

XF86MonBrightnessDown
    if command -v brightnessctl >/dev/null 2>&1; then brightnessctl set 10%-; elif command -v xbacklight >/dev/null 2>&1; then xbacklight -dec 10; fi

# Screenshot (scrot recommended)
Print
    scrot "\$HOME/Imágenes/screenshot_%Y-%m-%d_%H-%M-%S.png" && notify-send "Screenshot" "Guardada"
EOF

# -----------------------
# POLYBAR: config + launch + scripts
# -----------------------
info "Creando configuración de Polybar y scripts auxiliares..."
cat >"$POLYBAR_DIR/config" <<EOF
[colors]
bg = ${C_BG}
mantle = ${C_MANTLE}
crust = ${C_CRUST}
text = ${C_TEXT}
accent = ${C_MAUVE}

[bar/main]
width = 100%
height = 28
background = \${colors.bg}
foreground = \${colors.text}
font-0 = "JetBrainsMono Nerd Font:style=Regular:size=10"
modules-left = bspwm
modules-right = network volume memory cpu date tray

tray-position = right
tray-padding = 2

[module/bspwm]
type = internal/bspwm
label = %name%
index-sort = true

[module/network]
type = custom/script
exec = ${POLYBAR_SCRIPTS_DIR}/network.sh
interval = 5

[module/volume]
type = custom/script
exec = ${POLYBAR_SCRIPTS_DIR}/volume.sh
interval = 2
click-left = pactl set-sink-mute @DEFAULT_SINK@ toggle

[module/memory]
type = internal/memory
format = RAM %used%/%total% MB

[module/cpu]
type = internal/cpu
label = CPU %percentage:2%

[module/date]
type = internal/date
interval = 10
date = %Y-%m-%d %H:%M
EOF

cat >"$POLYBAR_DIR/launch.sh" <<'EOF'
#!/usr/bin/env bash
# Lanza polybar en todos los monitores conectados
killall -q polybar || true
sleep 0.2
if type "xrandr" >/dev/null 2>&1; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main >/dev/null 2>&1 &
  done
else
  polybar --reload main >/dev/null 2>&1 &
fi
EOF
chmod +x "$POLYBAR_DIR/launch.sh"

# Scripts: volume, battery, network
cat >"$POLYBAR_SCRIPTS_DIR/volume.sh" <<'EOF'
#!/usr/bin/env bash
SINK="@DEFAULT_SINK@"
if command -v pactl >/dev/null 2>&1; then
  vol_info=$(pactl get-sink-volume $SINK 2>/dev/null | head -n1)
  [ -z "$vol_info" ] && { echo "VOL: N/A"; exit 0; }
  vol=$(echo "$vol_info" | awk -F/ '{print $2}' | tr -d ' %')
  muted=$(pactl get-sink-mute $SINK 2>/dev/null | awk '{print $2}')
  if [ "$muted" = "yes" ]; then
    echo "VOL: muted"
  else
    echo "VOL: ${vol}%"
  fi
else
  echo "VOL: n/c"
fi
EOF

cat >"$POLYBAR_SCRIPTS_DIR/battery.sh" <<'EOF'
#!/usr/bin/env bash
bat_dir=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1 || true)
if [ -n "$bat_dir" ]; then
  status=$(cat "$bat_dir/status" 2>/dev/null || echo "Unknown")
  capacity=$(cat "$bat_dir/capacity" 2>/dev/null || echo "0")
  echo "BAT: ${capacity}% (${status})"
  exit 0
fi
if command -v upower >/dev/null 2>&1; then
  device=$(upower -e | grep battery | head -n1)
  if [ -n "$device" ]; then
    percent=$(upower -i "$device" | awk '/percentage/ {print $2}')
    state=$(upower -i "$device" | awk '/state/ {print $2}')
    echo "BAT: ${percent} (${state})"
    exit 0
  fi
fi
echo "BAT: N/A"
EOF

cat >"$POLYBAR_SCRIPTS_DIR/network.sh" <<'EOF'
#!/usr/bin/env bash
if command -v nmcli >/dev/null 2>&1; then
  con=$(nmcli -t -f NAME,DEVICE connection show --active | head -n1 | cut -d: -f1)
  state=$(nmcli -t -f STATE general | head -n1)
  if [ -n "$con" ]; then
    echo "NET: ${con}"
  else
    if [ "$state" = "connected" ]; then
      ip=$(hostname -I | awk '{print $1}')
      echo "NET: ${ip}"
    else
      echo "NET: offline"
    fi
  fi
else
  echo "NET: n/c"
fi
EOF

# Dar permisos a scripts de polybar
chmod +x "$POLYBAR_SCRIPTS_DIR/"*.sh

# -----------------------
# ROFI THEME Y POWER MENU
# -----------------------
info "Creando tema rofi y menú de energía..."
cat >"$ROFI_DIR/catppuccin.rasi" <<EOF
/* Tema Rofi Catppuccin Mocha */
* {
    background: ${C_BG};
    border: 1px solid ${C_CRUST};
    border-radius: 8px;
    text-color: ${C_TEXT};
}
window {
    padding: 10px;
    background: ${C_BG};
}
listview {
    lines: 10;
    fixed-height: 0;
}
element {
    padding: 6px 10px;
    background: ${C_MANTLE};
}
element selected {
    background: ${C_MAUVE};
    text-color: ${C_CRUST};
}
textbox {
    text-color: ${C_TEXT};
    font: "JetBrainsMono Nerd Font 11";
}
EOF

cat >"$LOCAL_BIN/rofi_power_menu" <<'EOF'
#!/usr/bin/env bash
OPTIONS=" Apagar\n Reiniciar\n Suspender\n Bloquear\n Cerrar sesión"
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -theme ~/.config/rofi/catppuccin.rasi -p "Power")
case "$CHOICE" in
  *Apagar) systemctl poweroff ;;
  *Reiniciar) systemctl reboot ;;
  *Suspender) systemctl suspend ;;
  *Bloquear)
    if command -v swaylock >/dev/null 2>&1; then
      swaylock
    elif command -v betterlockscreen >/dev/null 2>&1; then
      betterlockscreen -l
    elif command -v i3lock >/dev/null 2>&1; then
      i3lock
    else
      notify-send "Lock" "No locker installed"
    fi
    ;;
  *Cerrar*)
    bspc quit
    ;;
esac
EOF
chmod +x "$LOCAL_BIN/rofi_power_menu"

# -----------------------
# PICOM, DUNST, KITTY CONFIGS
# -----------------------
info "Creando picom, dunst y kitty configuration básica..."
cat >"$PICOM_DIR/picom.conf" <<EOF
# picom config (simple, blur, shadows)
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;
blur: {
  method = "gaussian";
  radius = 12;
  passes = 2;
}
opacity-rule = [
  "90:class_g = 'Polybar'"
];
EOF

cat >"$DUNST_DIR/dunstrc" <<EOF
[global]
    font = JetBrainsMono Nerd Font 10
    background = ${C_BG}
    foreground = ${C_TEXT}
    frame_color = ${C_CRUST}
    geometry = "300x5-10+40"

[urgency_low]
    background = ${C_MANTLE}
    foreground = ${C_TEXT}

[urgency_normal]
    background = ${C_MANTLE}
    foreground = ${C_TEXT}

[urgency_critical]
    background = ${C_RED}
    foreground = ${C_CRUST}
EOF

cat >"$KITTY_DIR/kitty.conf" <<EOF
# kitty basic config (font & colors)
font_family      JetBrainsMono Nerd Font
font_size        12.0
background       ${C_BG}
foreground       ${C_TEXT}
EOF

# -----------------------
# WALLPAPER_SETUP HELPER
# -----------------------
info "Creando helper wallpaper_setup que descarga los wallpapers Catppuccin (misc) y los aplica con feh..."
cat >"$LOCAL_BIN/wallpaper_setup" <<'EOF'
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
EOF
chmod +x "$LOCAL_BIN/wallpaper_setup"

# -----------------------
# HABILITAR SERVICIOS
# -----------------------
info "Habilitando servicios: NetworkManager y SDDM. Iniciando servicios PipeWire."
# Habilita y arranca NetworkManager inmediatamente
sudo systemctl enable --now NetworkManager.service

# Habilita e inicia SDDM (display manager) para login gráfico
sudo systemctl enable --now sddm.service

# Habilitar PipeWire a nivel de usuario (no fatal si falla)
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service || true
fi

# -----------------------
# INTENTO APLICAR TEMA GTK E ICONS (no fatal si falla)
# -----------------------
if command -v gsettings >/dev/null 2>&1; then
  info "Intentando aplicar tema GTK 'Catppuccin-Mocha' y icon theme 'Tela-circle-Nord' con gsettings (si están disponibles)..."
  set +e
  gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-Mocha" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-Nord" 2>/dev/null || true
  set -e
fi

# -----------------------
# PERMISOS FINALES Y MENSAJES
# -----------------------
info "Ajustando permisos de ejecución y mostrando pasos finales..."
# Ejecutables
chmod +x "$LOCAL_BIN/rofi_power_menu" || true
chmod +x "$LOCAL_BIN/wallpaper_setup" || true
chmod +x "$POLYBAR_DIR/launch.sh" || true
chmod +x "$POLYBAR_SCRIPTS_DIR/"*.sh || true
chmod +x "$BSPWM_CONFIG_DIR/bspwmrc" || true
chmod +x "$SXHKD_CONFIG_DIR/sxhkdrc" || true

info "Instalación y configuración finalizadas."

cat <<NOTE

Siguientes pasos recomendados:

1) Reinicia o cierra sesión para entrar con SDDM y seleccionar la sesión 'bspwm' (si SDDM detecta la sesión).
   - sudo reboot

2) Si entras en una sesión X (bspwm) y la barra no aparece, ejecuta manualmente:
   ~/.config/polybar/launch.sh

3) Para recargar tu configuración de atajos (sxhkd) sin reiniciar:
   pkill -USR1 -x sxhkd || true

4) Para probar el helper de wallpaper:
   ~/.local/bin/wallpaper_setup

5) Si alguna instalación AUR falló, reintenta manualmente con:
   yay -S <nombre-del-paquete>

Notas de seguridad y personalización:
- El script instala solo los paquetes que solicitaste y los AUR listados. Para funciones extra (p.ej. pavucontrol, scrot, brightnessctl) instala los paquetes que necesites.
- El nombre exacto de Brave puede variar (brave, brave-browser). Si Brave no arranca desde el atajo, ajusta ~/.config/sxhkd/sxhkdrc con el nombre correcto del ejecutable.
- Si prefieres otro display manager (LightDM), puedes deshabilitar sddm: sudo systemctl disable --now sddm && sudo pacman -S lightdm lightdm-gtk-greeter

Si quieres, puedo:
 - Añadir soporte para multi-monitor polybar (con scripts que detectan y colocan barras por monitor).
 - Ajustar reglas de bspwm para aplicaciones concretas que uses (p.ej. Slack, Discord).
 - Añadir ejemplo avanzado de temas para Polybar y Rofi con iconos y dotfiles sincronizables.

NOTE

# Fin del script
